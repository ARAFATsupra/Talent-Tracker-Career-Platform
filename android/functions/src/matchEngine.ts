/**
 * Server-side port of lib/services/ai/match_engine.dart — Section 12,
 * AI Matching Algorithm. Kept logically identical to the Dart version
 * (same formula, same gap conditions, same rounding) so a score computed
 * here and a score computed on-device in the Student Portal never
 * disagree. See PHASE3_GUIDE.md for the worked-example verification
 * (UT-03, 58.8%) this logic is built against — the same fixture is
 * re-used in this package's Jest test (src/matchEngine.test.ts).
 *
 * If you change the scoring formula or gap rules in match_engine.dart,
 * mirror the change here — there is no shared/generated source between
 * the two languages in this project.
 */

import {MIN_PASSING_GRADE_POINT_FOR_GAP, RECRUITER_SCAN_WEIGHT_THRESHOLD} from "./constants";
import {CourseGrade, JobDescription} from "./types";

export type GapType = "notTaken" | "lowGrade" | "missingSkill";

export interface SkillGap {
  type: GapType;
  courseCode?: string;
  courseName?: string;
  skillName?: string;
  weight: number;
  remediation: string;
}

export interface CourseContribution {
  courseCode: string;
  courseName: string;
  gradePoint: number;
  weight: number;
  contribution: number;
}

export type MatchConfidence = "empty" | "partial" | "full";

export interface MatchScoreResult {
  matchPercentage: number;
  totalEarned: number;
  totalPossible: number;
  confidence: MatchConfidence;
  breakdown: CourseContribution[];
}

export interface JDEvaluation {
  score: MatchScoreResult;
  gaps: SkillGap[];
}

/** Section 12.2 — MatchScore Formula. Mirrors MatchEngine.calculateMatchScore. */
export function calculateMatchScore(
  studentCourses: CourseGrade[],
  jd: JobDescription
): MatchScoreResult {
  const byCode = new Map<string, CourseGrade>();
  for (const c of studentCourses) byCode.set(c.courseCode, c);

  let totalEarned = 0;
  let totalPossible = 0;
  const breakdown: CourseContribution[] = [];

  let relevantCourseCount = 0;
  let takenCourseCount = 0;

  for (const code of jd.criticalPathCourses) {
    const weight = jd.courseWeights[code] ?? 0;
    if (weight <= 0) continue; // UT-09

    relevantCourseCount++;

    const studentCourse = byCode.get(code);
    const hasGrade = !!studentCourse && studentCourse.grade.length > 0;
    const gradePoint = hasGrade ? studentCourse!.gradePoint : 0;
    if (hasGrade) takenCourseCount++;

    const contribution = gradePoint * weight;
    totalEarned += contribution;
    totalPossible += 4.0 * weight;

    breakdown.push({
      courseCode: code,
      courseName: studentCourse?.courseName ?? code,
      gradePoint,
      weight,
      contribution,
    });
  }

  const percentage = totalPossible > 0 ? (totalEarned / totalPossible) * 100 : 0;

  let confidence: MatchConfidence;
  if (studentCourses.length === 0) {
    confidence = "empty"; // UT-04
  } else if (relevantCourseCount === 0 || takenCourseCount === relevantCourseCount) {
    confidence = "full";
  } else {
    confidence = "partial";
  }

  return {
    matchPercentage: roundTo1Decimal(percentage),
    totalEarned,
    totalPossible,
    confidence,
    breakdown,
  };
}

/** Section 12.4 — Skill Gap Detection. Mirrors MatchEngine.detectGaps. */
export function detectGaps(studentCourses: CourseGrade[], jd: JobDescription): SkillGap[] {
  const byCode = new Map<string, CourseGrade>();
  for (const c of studentCourses) byCode.set(c.courseCode, c);

  const gaps: SkillGap[] = [];

  for (const code of jd.criticalPathCourses) {
    const weight = jd.courseWeights[code] ?? 0;
    if (weight <= 0) continue;

    const studentCourse = byCode.get(code);

    if (!studentCourse || studentCourse.grade.length === 0) {
      gaps.push({
        type: "notTaken",
        courseCode: code,
        courseName: studentCourse?.courseName ?? code,
        weight,
        remediation: remediationFor(
          jd,
          code,
          `Complete ${code} (or an equivalent free certification) to close this gap.`
        ),
      });
    } else if (studentCourse.gradePoint < MIN_PASSING_GRADE_POINT_FOR_GAP) {
      gaps.push({
        type: "lowGrade",
        courseCode: code,
        courseName: studentCourse.courseName,
        weight,
        remediation: remediationFor(
          jd,
          code,
          `Retake ${code} to strengthen this area — current grade: ${studentCourse.grade}.`
        ),
      });
    }
  }

  const passedCourseNames = studentCourses
    .filter((c) => c.grade.length > 0 && c.gradePoint >= MIN_PASSING_GRADE_POINT_FOR_GAP)
    .map((c) => c.courseName.toLowerCase());

  for (const skill of jd.requiredSkills) {
    const covered = passedCourseNames.some((name) => name.includes(skill.toLowerCase()));
    if (!covered) {
      gaps.push({
        type: "missingSkill",
        skillName: skill,
        weight: 0,
        remediation: remediationFor(
          jd,
          skill,
          `Build the "${skill}" skill — see recommended certifications for this role.`
        ),
      });
    }
  }

  return gaps;
}

/** Mirrors MatchEngine.evaluateJD — score + gaps in one call. */
export function evaluateJD(studentCourses: CourseGrade[], jd: JobDescription): JDEvaluation {
  return {
    score: calculateMatchScore(studentCourses, jd),
    gaps: detectGaps(studentCourses, jd),
  };
}

/**
 * Section 12.6 — drop courses below the recruiter-scan weight threshold.
 * Mirrors MatchEngine._filterForRecruiterScan.
 */
export function filterForRecruiterScan(jd: JobDescription): JobDescription {
  const keptCodes = jd.criticalPathCourses.filter(
    (code) => (jd.courseWeights[code] ?? 0) >= RECRUITER_SCAN_WEIGHT_THRESHOLD
  );
  const keptWeights: Record<string, number> = {};
  for (const [code, weight] of Object.entries(jd.courseWeights)) {
    if (weight >= RECRUITER_SCAN_WEIGHT_THRESHOLD) keptWeights[code] = weight;
  }
  return {
    ...jd,
    criticalPathCourses: keptCodes,
    courseWeights: keptWeights,
  };
}

function remediationFor(jd: JobDescription, key: string, fallback: string): string {
  const specific = jd.remediations?.[key];
  if (specific) return specific;
  if (jd.certifications.length > 0) return `${fallback} Suggested: ${jd.certifications[0]}.`;
  return fallback;
}

function roundTo1Decimal(value: number): number {
  return Math.round(value * 10) / 10;
}
