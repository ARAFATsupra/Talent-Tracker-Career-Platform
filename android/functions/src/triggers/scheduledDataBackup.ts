/**
 * Section 14.1 — scheduledDataBackup
 * Trigger: Pub/Sub CRON every Sunday at 2AM.
 * Purpose: Exports all active student profiles and match results to
 * Firebase Storage as JSON backup.
 *
 * Supports FR-27 ("Admin must be able to archive old placement cycles
 * and export all data as a backup file") as the automated, scheduled
 * half of that requirement; S-32 (Data Export & Archive) is the
 * on-demand, admin-triggered version of the same idea.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {logSystemError} from "./onStudentGradeUpdated";

const db = admin.firestore();

export const scheduledDataBackup = functions.pubsub
  .schedule("0 2 * * 0") // every Sunday at 2:00 AM
  .timeZone("Asia/Dhaka")
  .onRun(async () => {
    try {
      const studentsSnap = await db
        .collection("users")
        .where("role", "==", "student")
        .where("isActive", "==", true)
        .get();

      const backup: Record<string, unknown>[] = [];

      for (const userDoc of studentsSnap.docs) {
        const uid = userDoc.id;
        const semestersSnap = await db.collection("users").doc(uid).collection("semesters").get();
        const matchResultSnap = await db.collection("matchResults").doc(uid).get();

        backup.push({
          uid,
          profile: userDoc.data(),
          semesters: semestersSnap.docs.map((d) => d.data()),
          matchResults: matchResultSnap.exists ? matchResultSnap.data() : null,
        });
      }

      const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
      const fileName = `backups/student-data-${timestamp}.json`;
      const bucket = admin.storage().bucket();
      const file = bucket.file(fileName);

      await file.save(
        JSON.stringify({generatedAt: timestamp, studentCount: backup.length, students: backup}, null, 2),
        {contentType: "application/json"}
      );

      functions.logger.info("scheduledDataBackup completed", {fileName, studentCount: backup.length});
    } catch (error) {
      functions.logger.error("scheduledDataBackup failed", {error});
      await logSystemError("scheduledDataBackup", `Weekly backup failed: ${error}`);
    }
  });
