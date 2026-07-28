// Shared fixtures for the AI engine unit tests (Section 17.1).
//
// The Business Analyst JD below mirrors the worked example in Section
// 12.3 EXACTLY: 6 critical-path courses with weights summing to 4.80, so
// the maximum possible score is 4.0 * 4.80 = 19.20 — matching 12.3's
// table. This makes UT-03 reproduce the documented 58.8% result.
//
// Section 10.13's "AI Weight Configuration Sample" lists 8 weighted
// courses for this role (it also includes STA-301 and CSE-201). Those two
// extra weights are kept in `courseWeights` below for completeness, but
// are deliberately NOT included in `criticalPathCourses` — per 12.2,
// "Only criticalPathCourses listed in the JD are included in the
// calculation", so they don't affect the score.
//
// 🔶 Flag for the team: Section 10.2's printed grade table for Rahim
// Ahmed does NOT list MGT-210, yet Section 12.3's worked example scores
// him as having taken MGT-210 with grade A (contribution 3.56). The
// fixture below follows the WORKED EXAMPLE (12.3) — since UT-03 explicitly
// asks to reproduce its 58.8% result — but the two sections should be
// reconciled in the final seed data (e.g. add MGT-210/A to Rahim's
// Section 10.2 profile, or recompute 12.3 without it).

import 'package:talent_tracker_ai/models/course_grade_model.dart';
import 'package:talent_tracker_ai/models/jd_model.dart';

final businessAnalystJD = JDModel(
  jdId: 'jd_BA_001',
  title: 'Junior Business Analyst',
  category: 'Business and Management',
  requiredSkills: const ['SQL', 'Excel', 'Requirements Gathering'],
  criticalPathCourses: const [
    'MGT-210', // Project Management
    'CSE-402', // Systems Analysis & Design
    'MGT-301', // Business Process Management
    'CSE-303', // Database Management Systems
    'ITM-501', // Business Intelligence
    'ENG-101', // English Communication
  ],
  courseWeights: const {
    'MGT-210': 0.95,
    'CSE-402': 0.90,
    'MGT-301': 0.90,
    'CSE-303': 0.75,
    'ITM-501': 0.70,
    'ENG-101': 0.60,
    'STA-301': 0.55, // not in criticalPathCourses — ignored by the formula
    'CSE-201': 0.10, // not in criticalPathCourses — ignored by the formula
  },
  certifications: const ['Google Data Analytics', 'IBM Business Analyst'],
);

/// Rahim Ahmed's courses AS USED IN SECTION 12.3's worked example
/// (MatchScore = 58.8% — UT-03). CSE-402 and MGT-301 are deliberately
/// omitted -> "not taken yet" (gap flagged), exactly as in 12.3's table.
List<CourseGradeModel> rahimCoursesForBAWorkedExample() => [
      CourseGradeModel.fromGrade(
        courseCode: 'MGT-210',
        courseName: 'Project Management',
        creditHours: 3,
        grade: 'A',
      ),
      CourseGradeModel.fromGrade(
        courseCode: 'CSE-303',
        courseName: 'Database Management Systems',
        creditHours: 3,
        grade: 'A+',
      ),
      CourseGradeModel.fromGrade(
        courseCode: 'ITM-501',
        courseName: 'Business Intelligence',
        creditHours: 3,
        grade: 'A',
      ),
      CourseGradeModel.fromGrade(
        courseCode: 'ENG-101',
        courseName: 'English Communication',
        creditHours: 2,
        grade: 'B+',
      ),
    ];
