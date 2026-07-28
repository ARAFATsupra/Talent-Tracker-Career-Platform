/**
 * Mirrors lib/app/app_constants.dart — Section 7.1/7.3, FR-36, Section
 * 12.2/12.4/12.6. Kept as a hand-synced TypeScript copy rather than a
 * generated one (no cross-language codegen step in this project); if you
 * change a grade point or threshold in the Flutter app, make the same
 * change here, or the Cloud Function's `matchResults` will silently
 * disagree with the on-device score shown in the Student Portal.
 *
 * 🔶 Same A-/B- placeholder caveat as the Dart side (see
 * app_constants.dart's doc comment): neither value appears anywhere in
 * the 38-page spec; these are the team's TODO-flagged interpolation.
 */

export const VALID_GRADES = [
  "A+", "A", "A-", "B+", "B", "B-", "C+", "C", "D", "F",
] as const;

export type Grade = typeof VALID_GRADES[number];

export const GRADE_POINTS: Record<string, number> = {
  "A+": 4.0,
  "A": 3.75,
  "A-": 3.625, // 🔶 placeholder — confirm with faculty advisor
  "B+": 3.5,
  "B": 3.25,
  "B-": 2.875, // 🔶 placeholder — confirm with faculty advisor
  "C+": 2.5,
  "C": 2.25,
  "D": 1.0,
  "F": 0.0,
};

/** FR-36 */
export const MAX_FAILED_LOGIN_ATTEMPTS = 5;
export const ACCOUNT_LOCK_DURATION_MINUTES = 30;

/** FR-06 / FR-09 */
export const TOTAL_SEMESTERS = 8;

/** Section 12.4 — critical-path grade point below this counts as a gap. */
export const MIN_PASSING_GRADE_POINT_FOR_GAP = 2.0;

/** Section 12.6 — courses below this weight are excluded from recruiter scans. */
export const RECRUITER_SCAN_WEIGHT_THRESHOLD = 0.2;
