// Section 17.1 — Unit Tests for the AI Engine Logic.
// Covers UT-03, UT-04, UT-05, UT-06, UT-07, UT-09.
// (UT-01/UT-02 -> test/models/semester_model_test.dart
//  UT-08        -> test/services/validation/grade_validation_test.dart
//  UT-10        -> test/services/auth/lockout_policy_test.dart)

import 'package:flutter_test/flutter_test.dart';
import 'package:talent_tracker_ai/models/course_grade_model.dart';
import 'package:talent_tracker_ai/models/jd_model.dart';
import 'package:talent_tracker_ai/models/match_result_model.dart';
import 'package:talent_tracker_ai/models/match_score_result.dart';
import 'package:talent_tracker_ai/services/ai/match_engine.dart';

import '../../fixtures/demo_data.dart';

void main() {
  group('UT-03 — Rahim Ahmed vs Business Analyst JD (Section 12.3)', () {
    test('match score is 58.8%', () {
      final result = MatchEngine.calculateMatchScore(
        studentCourses: rahimCoursesForBAWorkedExample(),
        jd: businessAnalystJD,
      );

      // 12.3: Total Score Earned 11.29 / Maximum Possible 19.20 = 58.8%
      expect(result.totalPossible, closeTo(19.20, 0.001));
      expect(result.totalEarned, closeTo(11.2875, 0.001));
      expect(result.matchPercentage, 58.8);
      expect(result.confidence, MatchConfidence.partial); // 4 of 6 critical courses taken
    });

    test('gap detection flags the two not-taken critical courses', () {
      final gaps = MatchEngine.detectGaps(
        studentCourses: rahimCoursesForBAWorkedExample(),
        jd: businessAnalystJD,
      );

      final notTakenCodes = gaps.where((g) => g.type == GapType.notTaken).map((g) => g.courseCode);
      expect(notTakenCodes, containsAll(['CSE-402', 'MGT-301']));
      expect(gaps.where((g) => g.type == GapType.lowGrade), isEmpty);
    });
  });

  group('UT-04 — student with zero grades', () {
    test('score is 0% and confidence is empty (job match blocked)', () {
      final result = MatchEngine.calculateMatchScore(
        studentCourses: const [], // no grades entered anywhere yet
        jd: businessAnalystJD,
      );

      expect(result.matchPercentage, 0.0);
      expect(result.totalEarned, 0.0);
      expect(result.confidence, MatchConfidence.empty);
    });
  });

  group('UT-05 — F grade in a critical course', () {
    test('score is reduced compared to the UT-03 baseline', () {
      // Same as Rahim's profile, but MGT-210 is now an F instead of an A.
      final courses = [
        CourseGradeModel.fromGrade(
          courseCode: 'MGT-210', courseName: 'Project Management', creditHours: 3, grade: 'F'),
        CourseGradeModel.fromGrade(
          courseCode: 'CSE-303', courseName: 'Database Management Systems', creditHours: 3, grade: 'A+'),
        CourseGradeModel.fromGrade(
          courseCode: 'ITM-501', courseName: 'Business Intelligence', creditHours: 3, grade: 'A'),
        CourseGradeModel.fromGrade(
          courseCode: 'ENG-101', courseName: 'English Communication', creditHours: 2, grade: 'B+'),
      ];

      final result = MatchEngine.calculateMatchScore(studentCourses: courses, jd: businessAnalystJD);

      // MGT-210 now contributes 0 (F = 0.00 grade point) instead of 3.5625.
      // (0 + 3.00 + 2.625 + 2.10) / 19.20 * 100 = 40.2%, down from 58.8%.
      expect(result.matchPercentage, 40.2);
      expect(result.matchPercentage, lessThan(58.8));
    });

    test('an F in a critical course triggers a low-grade gap with a retake recommendation', () {
      final courses = [
        CourseGradeModel.fromGrade(
          courseCode: 'MGT-210', courseName: 'Project Management', creditHours: 3, grade: 'F'),
      ];

      final gaps = MatchEngine.detectGaps(studentCourses: courses, jd: businessAnalystJD);

      final mgt210Gap = gaps.firstWhere((g) => g.courseCode == 'MGT-210');
      expect(mgt210Gap.type, GapType.lowGrade);
      expect(mgt210Gap.remediation.toLowerCase(), contains('retake'));
    });
  });

  group('UT-06 — tiebreaker: equal match score, higher CGPA wins', () {
    test('Student B (CGPA 3.8) ranks above Student A (CGPA 3.5) at the same 80% match', () {
      const studentA = StudentMatchSummary(
        studentUid: 'student_a', studentName: 'Student A', cgpa: 3.5, matchPercentage: 80.0);
      const studentB = StudentMatchSummary(
        studentUid: 'student_b', studentName: 'Student B', cgpa: 3.8, matchPercentage: 80.0);

      final ranked = MatchEngine.sortByMatchThenCGPA([studentA, studentB]);

      expect(ranked.first.studentUid, 'student_b');
      expect(ranked.last.studentUid, 'student_a');
    });
  });

  group('UT-07 — Gantt roadmap semester assignment (Section 12.5)', () {
    test('a student in Semester 4 with 3 gaps gets high->Sem5, medium->Sem6, low->Sem7', () {
      const highWeightGap = SkillGap(
        type: GapType.notTaken, courseCode: 'CSE-402', courseName: 'Systems Analysis & Design',
        weight: 0.90, remediation: 'Take CSE-402 next semester.');
      const mediumWeightGap = SkillGap(
        type: GapType.notTaken, courseCode: 'ITM-501', courseName: 'Business Intelligence',
        weight: 0.55, remediation: 'Take ITM-501.');
      const lowWeightGap = SkillGap(
        type: GapType.notTaken, courseCode: 'CSE-201', courseName: 'Object-Oriented Programming',
        weight: 0.10, remediation: 'Take CSE-201.');

      final roadmap = MatchEngine.generateRoadmap(
        gaps: [mediumWeightGap, lowWeightGap, highWeightGap], // deliberately unsorted input
        currentSemester: 4,
      );

      expect(roadmap, hasLength(3));
      expect(roadmap[0].semesterNumber, 5);
      expect(roadmap[0].gap.courseCode, 'CSE-402'); // highest weight -> nearest semester
      expect(roadmap[1].semesterNumber, 6);
      expect(roadmap[1].gap.courseCode, 'ITM-501');
      expect(roadmap[2].semesterNumber, 7);
      expect(roadmap[2].gap.courseCode, 'CSE-201'); // lowest weight -> latest semester
    });
  });

  group('UT-09 — weight 0.0 excludes a course entirely', () {
    test('a critical-path course with weight 0.0 does not affect the score', () {
      // jdWithExtra has one additional critical-path course (CSE-999) with
      // weight 0.0, on top of the standard 6 BA courses.
      final jdWithExtra = JDModel(
        jdId: businessAnalystJD.jdId,
        title: businessAnalystJD.title,
        category: businessAnalystJD.category,
        requiredSkills: businessAnalystJD.requiredSkills,
        criticalPathCourses: [...businessAnalystJD.criticalPathCourses, 'CSE-999'],
        courseWeights: {...businessAnalystJD.courseWeights, 'CSE-999': 0.0},
      );

      final courses = rahimCoursesForBAWorkedExample()
        ..add(CourseGradeModel.fromGrade(
          courseCode: 'CSE-999', courseName: 'Irrelevant Elective', creditHours: 3, grade: 'A+'));

      final withZeroWeight = MatchEngine.calculateMatchScore(studentCourses: courses, jd: jdWithExtra);
      final baseline = MatchEngine.calculateMatchScore(
        studentCourses: rahimCoursesForBAWorkedExample(), jd: businessAnalystJD);

      expect(withZeroWeight.matchPercentage, baseline.matchPercentage);
      expect(withZeroWeight.totalEarned, baseline.totalEarned);
      expect(withZeroWeight.totalPossible, baseline.totalPossible);
      expect(withZeroWeight.breakdown.any((c) => c.courseCode == 'CSE-999'), isFalse);

      // It's also not reported as a gap, since it's irrelevant to this JD.
      final gaps = MatchEngine.detectGaps(studentCourses: courses, jd: jdWithExtra);
      expect(gaps.any((g) => g.courseCode == 'CSE-999'), isFalse);
    });
  });

  group('Bonus — MatchResultModel.fromEvaluation bridges engine output to Firestore shape', () {
    test('UT-03 evaluation converts correctly', () {
      final evaluation = MatchEngine.evaluateJD(
        studentCourses: rahimCoursesForBAWorkedExample(),
        jd: businessAnalystJD,
      );

      final resultModel = MatchResultModel.fromEvaluation(evaluation);

      expect(resultModel.jdId, 'jd_BA_001');
      expect(resultModel.matchPercentage, 58.8);
      expect(resultModel.confidenceFlag, 'partial');
      expect(resultModel.missingCourses, containsAll(['CSE-402', 'MGT-301']));
    });
  });
}
