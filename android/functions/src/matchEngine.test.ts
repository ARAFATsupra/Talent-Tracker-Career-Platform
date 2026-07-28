/**
 * Verifies this TypeScript port reproduces the same numbers as the Dart
 * MatchEngine (test/services/ai/match_engine_test.dart) — specifically
 * UT-03 (Section 12.3's worked example, 58.8%). If these two test suites
 * ever disagree, the Cloud Function's matchResults and the on-device
 * Student Portal score would show different percentages for the same
 * student — that's the bug this test exists to catch.
 */

import {calculateMatchScore, detectGaps} from "./matchEngine";
import {CourseGrade, JobDescription} from "./types";

const businessAnalystJD: JobDescription = {
  title: "Junior Business Analyst",
  category: "Business and Management",
  requiredSkills: ["SQL", "Excel", "Requirements Gathering"],
  criticalPathCourses: ["MGT-210", "CSE-402", "MGT-301", "CSE-303", "ITM-501", "ENG-101"],
  courseWeights: {
    "MGT-210": 0.95,
    "CSE-402": 0.9,
    "MGT-301": 0.9,
    "CSE-303": 0.75,
    "ITM-501": 0.7,
    "ENG-101": 0.6,
    "STA-301": 0.55,
    "CSE-201": 0.1,
  },
  salaryRangeBDT: {min: 25000, max: 55000},
  sourceUrl: "",
  certifications: ["Google Data Analytics", "IBM Business Analyst"],
  isActive: true,
  addedBy: "admin_uid_001",
};

function course(
  courseCode: string,
  courseName: string,
  creditHours: number,
  grade: string,
  gradePoint: number
): CourseGrade {
  return {courseCode, courseName, creditHours, grade, gradePoint, isCoreCourse: false};
}

// Same fixture as test/fixtures/demo_data.dart's rahimCoursesForBAWorkedExample().
const rahimCourses: CourseGrade[] = [
  course("MGT-210", "Project Management", 3, "A", 3.75),
  course("CSE-303", "Database Management Systems", 3, "A+", 4.0),
  course("ITM-501", "Business Intelligence", 3, "A", 3.75),
  course("ENG-101", "English Communication", 2, "B+", 3.5),
];

describe("UT-03 — Rahim Ahmed vs Business Analyst JD (Section 12.3)", () => {
  it("matches the Dart engine's 58.8% result", () => {
    const result = calculateMatchScore(rahimCourses, businessAnalystJD);

    expect(result.totalPossible).toBeCloseTo(19.2, 3);
    expect(result.totalEarned).toBeCloseTo(11.2875, 3);
    expect(result.matchPercentage).toBe(58.8);
    expect(result.confidence).toBe("partial");
  });

  it("flags the two not-taken critical courses as gaps", () => {
    const gaps = detectGaps(rahimCourses, businessAnalystJD);
    const notTakenCodes = gaps.filter((g) => g.type === "notTaken").map((g) => g.courseCode);
    expect(notTakenCodes).toEqual(expect.arrayContaining(["CSE-402", "MGT-301"]));
  });
});

describe("UT-04 — student with zero grades", () => {
  it("returns 0% with confidence 'empty'", () => {
    const result = calculateMatchScore([], businessAnalystJD);
    expect(result.matchPercentage).toBe(0);
    expect(result.confidence).toBe("empty");
  });
});

describe("UT-09 — weight 0.0 excludes a course entirely", () => {
  it("a zero-weight critical-path course does not affect the score", () => {
    const jdWithExtra: JobDescription = {
      ...businessAnalystJD,
      criticalPathCourses: [...businessAnalystJD.criticalPathCourses, "CSE-999"],
      courseWeights: {...businessAnalystJD.courseWeights, "CSE-999": 0},
    };
    const courses = [...rahimCourses, course("CSE-999", "Irrelevant Elective", 3, "A+", 4.0)];

    const withZeroWeight = calculateMatchScore(courses, jdWithExtra);
    const baseline = calculateMatchScore(rahimCourses, businessAnalystJD);

    expect(withZeroWeight.matchPercentage).toBe(baseline.matchPercentage);
    expect(withZeroWeight.breakdown.some((c) => c.courseCode === "CSE-999")).toBe(false);
  });
});
