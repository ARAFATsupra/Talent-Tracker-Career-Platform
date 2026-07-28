/**
 * Section 14.1 — onStudentShortlisted
 * Trigger: Firestore write on placements.
 * Purpose: Notifies recruiter when a shortlisted student updates their
 * grade profile.
 *
 * 🔶 The function NAME ("onStudentShortlisted") and its TRIGGER
 * ("Firestore write on placements") describe two different moments —
 * being shortlisted vs. later updating grades. This implementation
 * covers both, since FR-41 ("notify the officer if a shortlisted
 * student updates their grade profile") is the actual requirement the
 * payload example in 14.2 matches:
 *
 *   { "notification": { "title": "Candidate Profile Updated",
 *     "body": "Rahim Ahmed has updated their grade profile." },
 *     "data": { "type": "profile_update", "studentUid": "xK2pLm...",
 *     "targetScreen": "studentProfileView" } }
 *
 * Two triggers are exported from this file:
 *  - onPlacementCreated: fires once per NEW placements doc (i.e. the
 *    "shortlisted" moment) — currently a no-op beyond logging, since the
 *    Flutter app already shows immediate UI feedback when a recruiter
 *    shortlists someone (Phase 5's snackbar) and there's no second party
 *    to notify at creation time.
 *  - onStudentGradesChangedNotifyRecruiters: fires on grade writes
 *    (semesters/{uid}) and finds every placements doc where this
 *    student is shortlisted, sending the FR-41 notification above to
 *    each recruiter who has them in their pipeline.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {Placement, UserDoc} from "../types";
import {logSystemError} from "./onStudentGradeUpdated";

const db = admin.firestore();

export const onPlacementCreated = functions.firestore
  .document("placements/{placementId}")
  .onCreate(async (snap, context) => {
    functions.logger.info("New placement created", {
      placementId: context.params.placementId,
      studentUid: (snap.data() as Placement).studentUid,
    });
  });

export const onStudentGradesChangedNotifyRecruiters = functions.firestore
  .document("users/{uid}/semesters/{semesterId}")
  .onUpdate(async (_change, context) => {
    const {uid} = context.params;

    try {
      const placementsSnap = await db.collection("placements").where("studentUid", "==", uid).get();
      if (placementsSnap.empty) return; // not shortlisted anywhere — FR-41 doesn't apply

      const userSnap = await db.collection("users").doc(uid).get();
      const user = userSnap.data() as UserDoc | undefined;
      const studentName = user?.fullName ?? "A student";

      const notifyOps = placementsSnap.docs.map((doc) => {
        const placement = doc.data() as Placement;
        return db
          .collection("notifications")
          .doc(placement.recruiterUid)
          .collection("items")
          .add({
            title: "Candidate Profile Updated",
            body: `${studentName} has updated their grade profile.`,
            type: "profile_update",
            studentUid: uid,
            targetScreen: "studentProfileView",
            read: false,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      });

      await Promise.all(notifyOps);
    } catch (error) {
      functions.logger.error("onStudentGradesChangedNotifyRecruiters failed", {uid, error});
      await logSystemError(
        "onStudentGradesChangedNotifyRecruiters",
        `Failed for student ${uid}: ${error}`
      );
    }
  });
