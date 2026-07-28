import '../../app/app_constants.dart';
import '../../models/course_grade_model.dart';
import '../../models/jd_model.dart';
import '../../models/match_score_result.dart';

/// Implements Section 12 — AI Matching Algorithm.
///
/// This is the "transparent, explainable, rule-based" engine described in
/// 12.1: a weighted alignment between a student's grade points and a JD's
/// `criticalPathCourses` / `courseWeights`. No ML, no black box — every
/// number here can be traced back to a course and a weight.
///
/// All methods are pure (no Firebase, no I/O) so they can be unit tested
/// directly — see Section 17.1, UT-03 through UT-09.
class MatchEngine {
  const MatchEngine._(); // static-only class

  /// Section 12.2 — MatchScore Formula:
  ///
  ///   MatchScore = [ Σ(gradePoint(course) × weight(course, jd)) /
  ///                   Σ(4.0 × weight(course, jd)) ] × 100
  ///
  /// - Only [JDModel.criticalPathCourses] are considered.
  /// - A course with weight ≤ 0 is excluded entirely from both the
  ///   numerator and denominator (UT-09) — not just "contributes zero".
  /// - A critical-path course the student hasn't taken (or has no grade
  ///   for) contributes gradePoint = 0 (12.2: "Courses not yet taken by
  ///   the student count as 0 — reducing score and flagging a skill gap").
  static MatchScoreResult calculateMatchScore({
    required List<CourseGradeModel> studentCourses,
    required JDModel jd,
  }) {
    final byCode = <String, CourseGradeModel>{
      for (final c in studentCourses) c.courseCode: c,
    };

    double totalEarned = 0;
    double totalPossible = 0;
    final breakdown = <CourseContribution>[];

    var relevantCourseCount = 0; // critical-path courses with weight > 0
    var takenCourseCount = 0; // ...of which the student has a grade for

    for (final code in jd.criticalPathCourses) {
      final weight = jd.courseWeights[code] ?? 0.0;
      if (weight <= 0) continue; // UT-09 — zero/negative weight excluded entirely

      relevantCourseCount++;

      final studentCourse = byCode[code];
      final hasGrade = studentCourse != null && studentCourse.grade.isNotEmpty;
      final gradePoint = hasGrade ? studentCourse!.gradePoint : 0.0;
      if (hasGrade) takenCourseCount++;

      final contribution = gradePoint * weight;
      totalEarned += contribution;
      totalPossible += 4.0 * weight;

      breakdown.add(CourseContribution(
        courseCode: code,
        courseName: studentCourse?.courseName ?? code,
        gradePoint: gradePoint,
        weight: weight,
        contribution: contribution,
      ));
    }

    final percentage = totalPossible > 0 ? (totalEarned / totalPossible) * 100 : 0.0;

    // FR-31/FR-32 — confidence flag for the UI.
    final MatchConfidence confidence;
    if (studentCourses.isEmpty) {
      // UT-04 — student hasn't entered ANY grades yet anywhere.
      confidence = MatchConfidence.empty;
    } else if (relevantCourseCount == 0 || takenCourseCount == relevantCourseCount) {
      confidence = MatchConfidence.full;
    } else {
      confidence = MatchConfidence.partial;
    }

    return MatchScoreResult(
      jdId: jd.jdId,
      jobTitle: jd.title,
      matchPercentage: _roundTo1Decimal(percentage),
      totalEarned: totalEarned,
      totalPossible: totalPossible,
      confidence: confidence,
      breakdown: breakdown,
    );
  }

  /// Section 12.4 — Skill Gap Detection. A gap exists when:
  ///  1. A critical-path course (weight > 0) hasn't been taken (UT-05/UT-07).
  ///  2. A critical-path course was taken but gradePoint < 2.0 (below a C).
  ///  3. A required skill doesn't map to any course the student has passed.
  static List<SkillGap> detectGaps({
    required List<CourseGradeModel> studentCourses,
    required JDModel jd,
  }) {
    final byCode = <String, CourseGradeModel>{
      for (final c in studentCourses) c.courseCode: c,
    };
    final gaps = <SkillGap>[];

    for (final code in jd.criticalPathCourses) {
      final weight = jd.courseWeights[code] ?? 0.0;
      if (weight <= 0) continue; // UT-09 — irrelevant to this JD, not a gap

      final studentCourse = byCode[code];

      if (studentCourse == null || studentCourse.grade.isEmpty) {
        // Condition 1 — not taken yet.
        gaps.add(SkillGap(
          type: GapType.notTaken,
          courseCode: code,
          courseName: studentCourse?.courseName ?? code,
          weight: weight,
          remediation: _remediationFor(jd, code,
              fallback: 'Complete $code (or an equivalent free certification) to close this gap.'),
        ));
      } else if (studentCourse.gradePoint < minPassingGradePointForGap) {
        // Condition 2 — grade below C (UT-05).
        gaps.add(SkillGap(
          type: GapType.lowGrade,
          courseCode: code,
          courseName: studentCourse.courseName,
          weight: weight,
          remediation: _remediationFor(jd, code,
              fallback: 'Retake $code to strengthen this area — current grade: ${studentCourse.grade}.'),
        ));
      }
    }

    // Condition 3 — required skill not covered by any passed course.
    //
    // 🔶 Heuristic: a skill is "covered" if its name appears (case
    // insensitive) inside the name of a course the student passed
    // (gradePoint >= 2.0). Section 12.4 doesn't specify how skills map to
    // courses — Phase 5's AI Weighting Config (S29) is the right place for
    // an admin to define this mapping explicitly. This keeps Phase 3
    // functional in the meantime.
    final passedCourseNames = studentCourses
        .where((c) => c.grade.isNotEmpty && c.gradePoint >= minPassingGradePointForGap)
        .map((c) => c.courseName.toLowerCase())
        .toList();

    for (final skill in jd.requiredSkills) {
      final covered = passedCourseNames.any((name) => name.contains(skill.toLowerCase()));
      if (!covered) {
        gaps.add(SkillGap(
          type: GapType.missingSkill,
          skillName: skill,
          weight: 0,
          remediation: _remediationFor(jd, skill,
              fallback: 'Build the "$skill" skill — see recommended certifications for this role.'),
        ));
      }
    }

    return gaps;
  }

  /// Convenience: score + gaps in one call, for the AI Job Match (S11) and
  /// Job Role Detail (S12) screens.
  static JDEvaluation evaluateJD({
    required List<CourseGradeModel> studentCourses,
    required JDModel jd,
  }) {
    return JDEvaluation(
      score: calculateMatchScore(studentCourses: studentCourses, jd: jd),
      gaps: detectGaps(studentCourses: studentCourses, jd: jd),
    );
  }

  /// Section 12.5 — Gantt Roadmap Generation.
  ///
  /// Distributes [gaps] across the student's remaining semesters
  /// (`currentSemester + 1` .. [totalSemesters]): the highest-weight gap
  /// goes to the nearest upcoming semester, lower-weight gaps to later
  /// semesters (UT-07). [GapType.missingSkill] gaps have weight 0 and so
  /// naturally sort last. If there are more gaps than remaining semesters,
  /// the overflow is placed in the final semester.
  ///
  /// Returns an empty list if there's nothing left to schedule (no gaps,
  /// or the student is already in/past the final semester).
  static List<RoadmapEntry> generateRoadmap({
    required List<SkillGap> gaps,
    required int currentSemester,
  }) {
    if (gaps.isEmpty) return const [];

    final remainingSemesters = totalSemesters - currentSemester;
    if (remainingSemesters <= 0) return const [];

    // Highest weight first -> nearest semester first.
    final sorted = [...gaps]..sort((a, b) => b.weight.compareTo(a.weight));

    return List.generate(sorted.length, (i) {
      final offset = i < remainingSemesters ? i : remainingSemesters - 1;
      return RoadmapEntry(
        semesterNumber: currentSemester + 1 + offset,
        gap: sorted[i],
      );
    });
  }

  /// Section 12.6 — Recruiter Scan Logic.
  ///
  /// Scores every student in [students] against [jd], EXCLUDING any
  /// critical-path course whose weight is below
  /// [recruiterScanWeightThreshold] (0.20) — "a student with low marks in
  /// unrelated subjects is never penalised". Results are ranked via
  /// [sortByMatchThenCGPA].
  static List<StudentMatchSummary> rankForRecruiterScan({
    required List<StudentProfile> students,
    required JDModel jd,
  }) {
    final scanJd = _filterForRecruiterScan(jd);

    final summaries = students.map((s) {
      final result = calculateMatchScore(studentCourses: s.courses, jd: scanJd);
      return StudentMatchSummary(
        studentUid: s.uid,
        studentName: s.fullName,
        cgpa: s.cgpa,
        matchPercentage: result.matchPercentage,
      );
    }).toList();

    return sortByMatchThenCGPA(summaries);
  }

  /// Sorts already-computed summaries by match percentage descending, then
  /// CGPA descending as a tiebreaker (UT-06: "Student A 80% CGPA 3.5 vs
  /// Student B 80% CGPA 3.8 -> Student B ranks first").
  ///
  /// Exposed separately from [rankForRecruiterScan] so the tiebreaker
  /// logic can be unit tested directly with hand-constructed summaries,
  /// without needing grade combinations that happen to produce an exact
  /// percentage.
  static List<StudentMatchSummary> sortByMatchThenCGPA(List<StudentMatchSummary> summaries) {
    final sorted = [...summaries];
    sorted.sort((a, b) {
      final byScore = b.matchPercentage.compareTo(a.matchPercentage);
      if (byScore != 0) return byScore;
      return b.cgpa.compareTo(a.cgpa); // UT-06 tiebreaker — higher CGPA wins
    });
    return sorted;
  }

  /// Section 12.6 — drop courses with weight < [recruiterScanWeightThreshold]
  /// from both `criticalPathCourses` and `courseWeights` before scoring.
  static JDModel _filterForRecruiterScan(JDModel jd) {
    final keptCodes = jd.criticalPathCourses
        .where((code) => (jd.courseWeights[code] ?? 0.0) >= recruiterScanWeightThreshold)
        .toList();
    final keptWeights = Map<String, double>.fromEntries(
      jd.courseWeights.entries.where((e) => e.value >= recruiterScanWeightThreshold),
    );

    return JDModel(
      jdId: jd.jdId,
      title: jd.title,
      category: jd.category,
      requiredSkills: jd.requiredSkills,
      criticalPathCourses: keptCodes,
      courseWeights: keptWeights,
      salaryMinBDT: jd.salaryMinBDT,
      salaryMaxBDT: jd.salaryMaxBDT,
      sourceUrl: jd.sourceUrl,
      certifications: jd.certifications,
      remediations: jd.remediations,
      isActive: jd.isActive,
      addedBy: jd.addedBy,
      createdAt: jd.createdAt,
    );
  }

  static String _remediationFor(JDModel jd, String key, {required String fallback}) {
    final specific = jd.remediations[key];
    if (specific != null && specific.isNotEmpty) return specific;
    if (jd.certifications.isNotEmpty) {
      return '$fallback Suggested: ${jd.certifications.first}.';
    }
    return fallback;
  }

  static double _roundTo1Decimal(double value) => (value * 10).round() / 10;
}
