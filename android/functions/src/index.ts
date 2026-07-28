/**
 * Cloud Functions entry point — Section 14.1.
 *
 * All 7 functions from the spec's table are implemented and exported
 * here:
 *   onStudentGradeUpdated, onNewJDAdded, onStudentShortlisted (split into
 *   onPlacementCreated + onStudentGradesChangedNotifyRecruiters),
 *   scheduledDataBackup, sendAdminErrorAlert, computeRecruiterScan,
 *   onJDArchived.
 *
 * Deploy with: npm run deploy (from this functions/ directory), or
 * `firebase deploy --only functions` from the project root once this
 * package has been built (`npm run build`).
 */

import * as admin from "firebase-admin";

admin.initializeApp();

export {onStudentGradeUpdated} from "./triggers/onStudentGradeUpdated";
export {onNewJDAdded} from "./triggers/onNewJDAdded";
export {onPlacementCreated, onStudentGradesChangedNotifyRecruiters} from "./triggers/onStudentShortlisted";
export {scheduledDataBackup} from "./triggers/scheduledDataBackup";
export {sendAdminErrorAlert} from "./triggers/sendAdminErrorAlert";
export {computeRecruiterScan} from "./triggers/computeRecruiterScan";
export {onJDArchived} from "./triggers/onJDArchived";
