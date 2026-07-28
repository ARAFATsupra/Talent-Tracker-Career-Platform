/// Result/value types for [MatchEngine] (lib/services/ai/match_engine.dart).
/// Kept separate from the Firestore-backed models (MatchResultModel etc.)
/// since these are richer, engine-internal shapes used to BUILD the
/// Firestore documents (Phase 5) and to drive the Student Portal UI
/// (Phase 4) — Skill Gap Roadmap (S13), AI Job Match (S11).

import 'course_grade_model.dart';

/// Section 12.4 — the three kinds of gap a student can have against a JD.
enum GapType {
  /// Critical-path course not taken yet (grade = '').
  notTaken,

  /// Critical-path course taken, but grade point < 2.0 (below a C).
  lowGrade,

  /// A required skill (Section 9.4 `requiredSkills`) that doesn't map to
  /// any course the student has passed.
  missingSkill,
}

/// One gap identified by [MatchEngine.detectGaps] — Section 12.4.
class SkillGap {
  final GapType type;
  final String? courseCode;
  final String? courseName;
  final String? skillName;

  /// The course's weight for this JD (Section 12.2). Used by
  /// [MatchEngine.generateRoadmap] to prioritise which gap gets the
  /// nearest semester (Section 12.5). Always 0 for [GapType.missingSkill]
  /// since those aren't tied to a single weighted course.
  final double weight;

  /// Human-readable suggestion — a free certification or a DIU elective
  /// (Section 12.4), pulled from [JDModel.remediations] when available.
  final String remediation;

  const SkillGap({
    required this.type,
    this.courseCode,
    this.courseName,
    this.skillName,
    this.weight = 0,
    required this.remediation,
  });

  /// A short label for chips/lists in the UI, e.g. "CSE-402" or "SQL".
  String get label => courseCode ?? skillName ?? courseName ?? 'Unknown';

  /// A stable, deterministic key identifying this gap WITHIN one JD's
  /// evaluation — `type:courseCode` or `type:skillName`. [SkillGap]
  /// itself has no database ID (it's a derived value, recomputed fresh
  /// every time [MatchEngine.detectGaps] runs), but the Progress Tracker
  /// (S-17, FR-38) needs something stable to persist "this gap is marked
  /// done" against. Combined with a `jdId`, this is unique enough for
  /// that purpose — see lib/features/student/repository/progress_repository.dart.
  String get gapKey => '${type.name}:${courseCode ?? skillName ?? courseName ?? 'unknown'}';
}

/// One row of the per-course score breakdown — useful for debugging and
/// for showing "why" a score is what it is on the Job Role Detail screen
/// (S12).
class CourseContribution {
  final String courseCode;
  final String courseName;
  final double gradePoint; // 0.0 if not taken
  final double weight;
  final double contribution; // gradePoint * weight

  const CourseContribution({
    required this.courseCode,
    required this.courseName,
    required this.gradePoint,
    required this.weight,
    required this.contribution,
  });
}

/// FR-31 / FR-32 — how much of the score should be trusted, surfaced to
/// the UI so it can show "complete your profile" prompts.
enum MatchConfidence {
  /// Student has entered NO grades anywhere yet. Score is 0% and
  /// shouldn't be shown as a real result (UT-04 — "job match blocked").
  empty,

  /// Student has some grades, but hasn't taken every critical-path course
  /// for this JD yet.
  partial,

  /// Every (weight > 0) critical-path course for this JD has a grade.
  full,
}

/// Output of [MatchEngine.calculateMatchScore] — Section 12.2.
class MatchScoreResult {
  final String jdId;
  final String jobTitle;

  /// 0-100, rounded to 1 decimal place.
  final double matchPercentage;

  final double totalEarned;
  final double totalPossible;
  final MatchConfidence confidence;
  final List<CourseContribution> breakdown;

  const MatchScoreResult({
    required this.jdId,
    required this.jobTitle,
    required this.matchPercentage,
    required this.totalEarned,
    required this.totalPossible,
    required this.confidence,
    required this.breakdown,
  });
}

/// Output of [MatchEngine.evaluateJD] — score + gaps combined, ready for
/// the AI Job Match (S11) and Job Role Detail (S12) screens.
class JDEvaluation {
  final MatchScoreResult score;
  final List<SkillGap> gaps;

  const JDEvaluation({required this.score, required this.gaps});
}

/// One entry of the Gantt roadmap — Section 12.5 / S13.
class RoadmapEntry {
  final int semesterNumber;
  final SkillGap gap;

  const RoadmapEntry({required this.semesterNumber, required this.gap});
}

/// One row of a recruiter scan result — Section 12.6 / S20.
class StudentMatchSummary {
  final String studentUid;
  final String studentName;
  final double cgpa;
  final double matchPercentage;

  const StudentMatchSummary({
    required this.studentUid,
    required this.studentName,
    required this.cgpa,
    required this.matchPercentage,
  });
}

/// Input to [MatchEngine.rankForRecruiterScan] — one student's profile.
class StudentProfile {
  final String uid;
  final String fullName;
  final double cgpa;
  final List<CourseGradeModel> courses;

  const StudentProfile({
    required this.uid,
    required this.fullName,
    required this.cgpa,
    required this.courses,
  });
}
