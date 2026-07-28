import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_grade_model.dart';
import '../../../models/jd_model.dart';
import '../../../models/match_score_result.dart';
import '../../../models/semester_model.dart';
import '../../../services/ai/match_engine.dart';
import '../../auth/providers/auth_providers.dart';
import '../repository/grade_repository.dart';
import '../repository/jd_repository.dart';
import '../repository/progress_repository.dart';

final gradeRepositoryProvider = Provider<GradeRepository>((ref) => GradeRepository());
final jdRepositoryProvider = Provider<JDRepository>((ref) => JDRepository());
final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository());

List<SemesterModel> _emptySemesters() => List.generate(
      totalSemesters,
      (i) => SemesterModel(semesterNumber: i + 1, semesterName: 'Semester ${i + 1}'),
    );

/// FR-06/FR-07 — live stream of the signed-in student's semesters, padded
/// out to exactly [totalSemesters] entries (1..8) so the Grade Entry
/// screen (S-09) always has a tab for every semester, even ones with no
/// saved data yet.
final semestersProvider = StreamProvider<List<SemesterModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(_emptySemesters());

  return ref.watch(gradeRepositoryProvider).watchSemesters(user.uid).map((saved) {
    final byNumber = {for (final s in saved) s.semesterNumber: s};
    return List.generate(totalSemesters, (i) {
      final number = i + 1;
      return byNumber[number] ?? SemesterModel(semesterNumber: number, semesterName: 'Semester $number');
    });
  });
});

/// Every course with a grade entered, across all semesters — the input to
/// [MatchEngine] (Section 12.2).
final allGradedCoursesProvider = Provider<List<CourseGradeModel>>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? const [];
  return semesters.expand((s) => s.courses).where((c) => c.grade.isNotEmpty).toList();
});

/// "Current" semester = the lowest semester number NOT yet marked
/// complete (the one the student should be entering grades for). If all
/// [totalSemesters] are complete, returns [totalSemesters] — there are no
/// remaining semesters to place roadmap items in (Section 12.5).
final currentSemesterProvider = Provider<int>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? const [];
  for (final s in semesters) {
    if (!s.isComplete) return s.semesterNumber;
  }
  return totalSemesters;
});

/// FR-13 — once Semester [totalSemesters] is marked complete, the whole
/// grade history becomes read-only on the Grade Entry screen.
final isGradeProfileLockedProvider = Provider<bool>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? const [];
  final finalSemester = semesters.where((s) => s.semesterNumber == totalSemesters);
  return finalSemester.isNotEmpty && finalSemester.first.isComplete;
});

/// Section 9.5 — "All authenticated users" can read `jobDescriptions`.
final activeJDsProvider = StreamProvider<List<JDModel>>((ref) {
  return ref.watch(jdRepositoryProvider).watchActiveJDs();
});

/// FR-08/FR-10 — every active JD evaluated against the student's grades
/// (Section 12.2 score + Section 12.4 gaps), sorted by match % descending.
final allEvaluationsProvider = Provider<List<JDEvaluation>>((ref) {
  final courses = ref.watch(allGradedCoursesProvider);
  final jds = ref.watch(activeJDsProvider).valueOrNull ?? const [];

  final evaluations = jds.map((jd) => MatchEngine.evaluateJD(studentCourses: courses, jd: jd)).toList();
  evaluations.sort((a, b) => b.score.matchPercentage.compareTo(a.score.matchPercentage));
  return evaluations;
});

/// FR-08 — "exactly three job role recommendations" for the AI Job Match
/// screen (S-11) and Dashboard (S-08).
final top3EvaluationsProvider = Provider<List<JDEvaluation>>((ref) {
  return ref.watch(allEvaluationsProvider).take(3).toList();
});

/// FR-12 — set by the Desired Role Selector (S-14) to drive the Skill Gap
/// Roadmap (S-13) for a manually-picked role, overriding the AI's top
/// recommendation. `null` = "use the top AI match" (the default).
final selectedJdIdProvider = StateProvider<String?>((ref) => null);

/// The evaluation the Skill Gap Roadmap (S-13) should build a roadmap
/// from: the manually-selected role if one was picked (FR-12), otherwise
/// the top AI match (FR-08). Null only if there are no active JDs at all.
final roadmapJdEvaluationProvider = Provider<JDEvaluation?>((ref) {
  final selectedId = ref.watch(selectedJdIdProvider);
  final all = ref.watch(allEvaluationsProvider);
  if (all.isEmpty) return null;

  if (selectedId != null) {
    for (final evaluation in all) {
      if (evaluation.score.jdId == selectedId) return evaluation;
    }
  }
  return all.first; // top AI match
});

/// FR-11 — the Gantt roadmap (Section 12.5) for [roadmapJdEvaluationProvider].
final roadmapEntriesProvider = Provider<List<RoadmapEntry>>((ref) {
  final evaluation = ref.watch(roadmapJdEvaluationProvider);
  if (evaluation == null) return const [];

  final currentSemester = ref.watch(currentSemesterProvider);
  return MatchEngine.generateRoadmap(gaps: evaluation.gaps, currentSemester: currentSemester);
});

/// S-17 Progress Tracker (FR-38) — every gap key the student has marked
/// done so far, via [ProgressRepository].
final completedGapKeysProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(const {});
  return ref.watch(progressRepositoryProvider).watchCompletedGapKeys(user.uid);
});

/// S-17 — the roadmap-target JD's gaps, paired with whether each has
/// been marked done. Used for the checklist + "completion % bar".
///
/// 🔶 "Watch match score rise after each completion" (FR-38) is
/// interpreted here as a PROJECTED score: Section 12.2's formula treats
/// a not-taken critical course as gradePoint 0, so there's no real grade
/// to recompute from until the student actually takes and passes that
/// course. Marking a gap "done" instead shows what the score WOULD
/// become if that course were completed at a B+ (3.50) — a reasonable
/// "you're on track" estimate — clearly labelled as projected, not
/// recalculated from a real grade, so it can't be confused with the
/// authoritative on-device score shown elsewhere (S-11/S-12).
final projectedScoreAfterCompletionProvider = Provider<double?>((ref) {
  final evaluation = ref.watch(roadmapJdEvaluationProvider);
  final completedKeys = ref.watch(completedGapKeysProvider).valueOrNull ?? const {};
  if (evaluation == null || completedKeys.isEmpty) return evaluation?.score.matchPercentage;

  const assumedCompletionGradePoint = 3.5; // a projected B+, see doc comment above

  double earned = evaluation.score.totalEarned;
  final possible = evaluation.score.totalPossible;
  if (possible <= 0) return evaluation.score.matchPercentage;

  for (final gap in evaluation.gaps) {
    if (gap.type == GapType.missingSkill) continue; // not weighted, doesn't move the score
    if (!completedKeys.contains(gap.gapKey)) continue;
    earned += assumedCompletionGradePoint * gap.weight;
  }

  final projected = (earned / possible) * 100;
  return double.parse(projected.clamp(0, 100).toStringAsFixed(1));
});
