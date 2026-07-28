/**
 * Section 14.1 — onStudentGradeUpdated
 * Trigger: Firestore write on semesters/{uid} (sub-collection of users/{uid}).
 * Purpose: Recomputes match scores whenever a student saves grade data;
 * writes result to matchResults collection.
 *
 * Section 9.5: matchResults/{uid} is Cloud-Functions-write-only. This is
 * the function that satisfies that requirement — the Flutter app itself
 * never writes to matchResults; Phase 4/5 compute scores on-device for
 * IMMEDIATE UI feedback, and this function writes the same numbers to
 * Firestore for anything that needs a stored/queryable copy (the
 * Recruiter's "score only" read permission in the access matrix, FR-41's
 * shortlist-update notification, etc.).
 *
 * FR-08: "exactly three job role recommendations" — this writes the
 * top 3 by match percentage to matchResults/{uid}'s topMatches field, and
 * ALSO computes one matchResults-style entry per active JD evaluated,
 * kept in a parallel matchResults/{uid}/allMatches/{jdId} sub-collection
 * so S-12 (Job Role Detail) and S-14 (Desired Role Selector) can show a
 * cached score for ANY role, not just the top 3 — without recomputing.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {evaluateJD} from "../matchEngine";
import {CourseGrade, JobDescription, MatchResult, Semester} from "../types";

const db = admin.firestore();

export const onStudentGradeUpdated = functions.firestore
  .document("users/{uid}/semesters/{semesterId}")
  .onWrite(async (_change, context) => {
    const {uid} = context.params;

    try {
      await recomputeMatchesForStudent(uid);
    } catch (error) {
      functions.logger.error("onStudentGradeUpdated failed", {uid, error});
      await logSystemError("onStudentGradeUpdated", `Failed for student ${uid}: ${error}`);
    }
  });

/**
 * Shared by onStudentGradeUpdated and onJDArchived/onNewJDAdded (any
 * trigger that needs to refresh one student's full set of match
 * results). Reads every semester + every active JD, scores them all,
 * and writes:
 *   - matchResults/{uid}/allMatches/{jdId} — one doc per active JD
 *   - matchResults/{uid} (root doc)        — FR-08's top-3 summary
 */
export async function recomputeMatchesForStudent(uid: string): Promise<void> {
  const semestersSnap = await db.collection("users").doc(uid).collection("semesters").get();
  const allCourses: CourseGrade[] = [];
  semestersSnap.forEach((doc) => {
    const semester = doc.data() as Semester;
    for (const c of semester.courses ?? []) {
      if (c.grade) allCourses.push(c);
    }
  });

  const jdsSnap = await db.collection("jobDescriptions").where("isActive", "==", true).get();

  const evaluations = jdsSnap.docs.map((doc) => {
    const jd = doc.data() as JobDescription;
    const evaluation = evaluateJD(allCourses, jd);
    return {jdId: doc.id, jd, evaluation};
  });

  evaluations.sort((a, b) => b.evaluation.score.matchPercentage - a.evaluation.score.matchPercentage);

  const batch = db.batch();
  const allMatchesRef = db.collection("matchResults").doc(uid).collection("allMatches");

  for (const {jdId, jd, evaluation} of evaluations) {
    const result: MatchResult = {
      jdId,
      jobTitle: jd.title,
      matchPercentage: evaluation.score.matchPercentage,
      missingCourses: evaluation.gaps
        .filter((g) => g.type !== "missingSkill" && g.courseCode)
        .map((g) => g.courseCode as string),
      missingSkills: evaluation.gaps
        .filter((g) => g.type === "missingSkill" && g.skillName)
        .map((g) => g.skillName as string),
      confidenceFlag: evaluation.score.confidence,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    batch.set(allMatchesRef.doc(jdId), result, {merge: true});
  }

  // FR-08 — exactly three top-level recommendations, on the root doc.
  const topThree = evaluations.slice(0, 3).map(({jdId, jd, evaluation}) => ({
    jdId,
    jobTitle: jd.title,
    matchPercentage: evaluation.score.matchPercentage,
    confidenceFlag: evaluation.score.confidence,
  }));

  batch.set(
    db.collection("matchResults").doc(uid),
    {
      topMatches: topThree,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );

  await batch.commit();
}

/** Shared error-logging helper — sendAdminErrorAlert (Section 14.1) listens on this collection. */
export async function logSystemError(source: string, message: string): Promise<void> {
  await db.collection("systemLogs").add({
    severity: "ERROR",
    message,
    source,
    resolved: false,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
