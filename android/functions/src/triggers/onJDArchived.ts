/**
 * Section 14.1 — onJDArchived
 * Trigger: Firestore update on jobDescriptions (isActive = false).
 * Purpose: Recomputes match scores for affected students and sends
 * notifications about the change.
 *
 * "Affected students" = any student who currently has this JD in their
 * matchResults/{uid}.allMatches sub-collection (i.e. they have at least
 * one graded course relevant to it) — recompute clears/updates their
 * cached results either way, and a notification only goes out if this
 * JD was specifically one of their FR-08 top-3 recommendations, since
 * losing a top match is the case worth interrupting someone for.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {recomputeMatchesForStudent, logSystemError} from "./onStudentGradeUpdated";
import {JobDescription} from "../types";

const db = admin.firestore();

export const onJDArchived = functions.firestore
  .document("jobDescriptions/{jdId}")
  .onUpdate(async (change, context) => {
    const {jdId} = context.params;
    const before = change.before.data() as JobDescription;
    const after = change.after.data() as JobDescription;

    // Only act on the active -> inactive transition (the "archived" event).
    if (!(before.isActive && !after.isActive)) return;

    try {
      // Find every student for whom this JD has a cached match result.
      const affectedSnap = await db.collectionGroup("allMatches").where("jdId", "==", jdId).get();

      const affectedUids = new Set<string>();
      affectedSnap.forEach((doc) => {
        // doc path: matchResults/{uid}/allMatches/{jdId}
        const uid = doc.ref.parent.parent?.id;
        if (uid) affectedUids.add(uid);
      });

      for (const uid of affectedUids) {
        const matchResultSnap = await db.collection("matchResults").doc(uid).get();
        const wasTopMatch: boolean = (matchResultSnap.data()?.topMatches ?? []).some(
          (m: {jdId: string}) => m.jdId === jdId
        );

        await recomputeMatchesForStudent(uid);

        if (wasTopMatch) {
          await db.collection("notifications").doc(uid).collection("items").add({
            title: "A Job Role Was Archived",
            body: `${after.title} is no longer accepting matches — your recommendations have been updated.`,
            type: "jd_archived",
            jdId,
            targetScreen: "aiJobMatch",
            read: false,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (error) {
      functions.logger.error("onJDArchived failed", {jdId, error});
      await logSystemError("onJDArchived", `Failed for JD ${jdId}: ${error}`);
    }
  });
