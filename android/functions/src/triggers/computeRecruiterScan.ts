/**
 * Section 14.1 — computeRecruiterScan
 * Trigger: HTTPS callable function.
 * Purpose: Handles heavy computation of scanning all students for a
 * recruiter job search — runs server-side to avoid overloading the
 * mobile device.
 *
 * This mirrors lib/features/recruiter/repository/recruiter_repository.dart's
 * fetchActiveStudentsForScan() + MatchEngine.rankForRecruiterScan()
 * (Section 12.6), which Phase 5 runs ON-DEVICE. That's fine at the demo
 * data's scale (10 students), but doesn't hold up once a real student
 * body — thousands of profiles, each with up to 8 semesters of courses —
 * has to be downloaded and scored on a recruiter's phone for every
 * search. This callable does the same scan server-side instead.
 *
 * The Flutter side can switch to this by calling
 * FirebaseFunctions.instance.httpsCallable('computeRecruiterScan') with
 * the same filters as ScanFilters (recruiter_providers.dart) instead of
 * RecruiterRepository.fetchActiveStudentsForScan() — left as a 🔶
 * follow-up wiring step rather than changed silently in this phase,
 * since switching the data path is exactly the kind of change worth a
 * deliberate review rather than a drive-by edit alongside everything
 * else in this phase.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {calculateMatchScore, filterForRecruiterScan} from "../matchEngine";
import {CourseGrade, JobDescription, Semester, UserDoc} from "../types";

const db = admin.firestore();

interface ScanRequest {
  jobTitle: string;
  department?: string;
  batch?: string;
  minCgpa?: number;
  maxResults?: number; // FR-18 — default 5, max 50
}

interface ScanResultRow {
  studentUid: string;
  studentName: string;
  cgpa: number;
  matchPercentage: number;
}

export const computeRecruiterScan = functions.https.onCall(
  async (data: ScanRequest, context): Promise<{jdId: string | null; results: ScanResultRow[]}> => {
    // FR-15 to FR-21 are recruiter-only actions — verify the caller's role.
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const callerRole = (callerSnap.data() as UserDoc | undefined)?.role;
    if (callerRole !== "recruiter" && callerRole !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only recruiters and admins can run a candidate scan."
      );
    }

    const jobTitle = (data.jobTitle ?? "").trim();
    if (!jobTitle) {
      throw new functions.https.HttpsError("invalid-argument", "jobTitle is required.");
    }

    // Section 12.6 — "find the closest matching JD" (same simple
    // substring approach as matchedJdProvider on the Flutter side, for
    // consistency between the on-device and server-side paths).
    const jdsSnap = await db.collection("jobDescriptions").where("isActive", "==", true).get();
    const normalizedQuery = jobTitle.toLowerCase();
    let matchedJdDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    for (const doc of jdsSnap.docs) {
      if (((doc.data() as JobDescription).title ?? "").toLowerCase() === normalizedQuery) {
        matchedJdDoc = doc;
        break;
      }
    }
    if (!matchedJdDoc) {
      for (const doc of jdsSnap.docs) {
        const title = ((doc.data() as JobDescription).title ?? "").toLowerCase();
        if (title.includes(normalizedQuery) || normalizedQuery.includes(title)) {
          matchedJdDoc = doc;
          break;
        }
      }
    }
    if (!matchedJdDoc) {
      return {jdId: null, results: []};
    }

    const jd = filterForRecruiterScan(matchedJdDoc.data() as JobDescription);

    let usersQuery: FirebaseFirestore.Query = db
      .collection("users")
      .where("role", "==", "student")
      .where("isActive", "==", true);
    if (data.department) usersQuery = usersQuery.where("department", "==", data.department);
    if (data.batch) usersQuery = usersQuery.where("batch", "==", data.batch);

    const usersSnap = await usersQuery.get();

    const rows: ScanResultRow[] = [];
    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data() as UserDoc;
      if (data.minCgpa !== undefined && user.cgpa < data.minCgpa) continue;

      const semestersSnap = await db.collection("users").doc(userDoc.id).collection("semesters").get();
      const courses: CourseGrade[] = [];
      semestersSnap.forEach((d) => {
        const semester = d.data() as Semester;
        for (const c of semester.courses ?? []) {
          if (c.grade) courses.push(c);
        }
      });

      const result = calculateMatchScore(courses, jd);
      rows.push({
        studentUid: userDoc.id,
        studentName: user.fullName,
        cgpa: user.cgpa,
        matchPercentage: result.matchPercentage,
      });
    }

    // UT-06 — match % desc, then CGPA desc as the tiebreaker.
    rows.sort((a, b) => b.matchPercentage - a.matchPercentage || b.cgpa - a.cgpa);

    const maxResults = Math.min(Math.max(data.maxResults ?? 5, 1), 50); // FR-18
    return {jdId: matchedJdDoc.id, results: rows.slice(0, maxResults)};
  }
);
