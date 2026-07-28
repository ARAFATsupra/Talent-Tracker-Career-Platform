/**
 * Section 14.1 — onNewJDAdded
 * Trigger: Firestore write on jobDescriptions.
 * Purpose: Triggers notifications to students whose top role is affected
 * by the new JD.
 *
 * Section 14.2's "New JD Alert" payload example is reproduced exactly
 * here:
 *   { "notification": { "title": "New Job Match Found!",
 *     "body": "A new Data Analyst role has been added matching your
 *     profile." }, "data": { "type": "new_jd", "jdId": "jd_DA_001",
 *     "targetScreen": "jobRoleDetail" } }
 *
 * "Whose top role is affected" is interpreted as: every ACTIVE student
 * whose recomputed score against this new JD now beats their current
 * top match (matchResults/{uid}.topMatches[0]). This avoids notifying
 * the entire student body for every JD an admin adds — only the
 * students for whom this is genuinely relevant news.
 *
 * 🔶 This function only fires on CREATE (a brand-new document), not on
 * every update — Section 14.1 says "onNewJDAdded", and "Firestore write"
 * is ambiguous between create/update; onJDArchived already covers the
 * isActive-false update case, so this one is scoped to creation to avoid
 * double-firing notifications for the same JD as it's edited later.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {calculateMatchScore} from "../matchEngine";
import {CourseGrade, JobDescription, Semester, UserDoc} from "../types";
import {logSystemError} from "./onStudentGradeUpdated";

const db = admin.firestore();

export const onNewJDAdded = functions.firestore
  .document("jobDescriptions/{jdId}")
  .onCreate(async (snap, context) => {
    const {jdId} = context.params;
    const jd = snap.data() as JobDescription;

    if (!jd.isActive) return; // archived-on-creation — nothing to notify about yet

    try {
      const studentsSnap = await db
        .collection("users")
        .where("role", "==", "student")
        .where("isActive", "==", true)
        .get();

      const notifications: Promise<unknown>[] = [];

      for (const studentDoc of studentsSnap.docs) {
        const uid = studentDoc.id;
        const user = studentDoc.data() as UserDoc;
        void user; // currently unused beyond existence-check; kept for future personalisation

        const semestersSnap = await db.collection("users").doc(uid).collection("semesters").get();
        const courses: CourseGrade[] = [];
        semestersSnap.forEach((d) => {
          const semester = d.data() as Semester;
          for (const c of semester.courses ?? []) {
            if (c.grade) courses.push(c);
          }
        });
        if (courses.length === 0) continue; // UT-04 — no grades, nothing to match yet

        const newScore = calculateMatchScore(courses, jd).matchPercentage;

        const matchResultSnap = await db.collection("matchResults").doc(uid).get();
        const currentTopScore: number = matchResultSnap.data()?.topMatches?.[0]?.matchPercentage ?? 0;

        if (newScore > currentTopScore) {
          notifications.push(
            db
              .collection("notifications")
              .doc(uid)
              .collection("items")
              .add({
                title: "New Job Match Found!",
                body: `A new ${jd.title} role has been added matching your profile.`,
                type: "new_jd",
                jdId,
                targetScreen: "jobRoleDetail",
                read: false,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
              })
          );
        }
      }

      await Promise.all(notifications);
    } catch (error) {
      functions.logger.error("onNewJDAdded failed", {jdId, error});
      await logSystemError("onNewJDAdded", `Failed for JD ${jdId}: ${error}`);
    }
  });
