import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/jd_model.dart';
import '../../../models/match_score_result.dart';
import '../../../models/placement_model.dart' show PlacementModel, PlacementStatus;
import '../../../services/ai/match_engine.dart';
import '../../auth/providers/auth_providers.dart';
import '../../student/providers/student_providers.dart' show activeJDsProvider;
import '../repository/recruiter_repository.dart';

final recruiterRepositoryProvider = Provider<RecruiterRepository>((ref) => RecruiterRepository());

/// FR-21 — optional filters for the candidate scan (Section 12.6).
class ScanFilters {
  final String? department;
  final String? batch;
  final double? minCgpa;
  /// FR-18 — "default: 5, maximum: 50" candidates to return.
  final int maxResults;

  const ScanFilters({this.department, this.batch, this.minCgpa, this.maxResults = 5});

  ScanFilters copyWith({String? department, String? batch, double? minCgpa, int? maxResults}) {
    return ScanFilters(
      department: department ?? this.department,
      batch: batch ?? this.batch,
      minCgpa: minCgpa ?? this.minCgpa,
      maxResults: maxResults ?? this.maxResults,
    );
  }
}

final scanFiltersProvider = StateProvider<ScanFilters>((ref) => const ScanFilters());

/// FR-15 — the job title (free text) typed into the Job Search screen
/// (S-19). `null` until the recruiter runs their first search this
/// session.
final scanJobTitleProvider = StateProvider<String?>((ref) => null);

/// FR-15/FR-16 — Section 12.6's "closest matching JD" step: find the
/// active JD whose title best matches [scanJobTitleProvider]'s free-text
/// query via simple case-insensitive substring matching.
///
/// 🔶 Section 12.6 says "string similarity" without specifying an
/// algorithm. A real fuzzy-match (edit distance / token overlap) would
/// handle typos and word-order better; this substring approach is
/// deliberately simple for Phase 5 and easy to swap out later without
/// touching any UI code, since everything else only depends on the
/// resulting JDModel.
final matchedJdProvider = Provider<JDModel?>((ref) {
  final query = ref.watch(scanJobTitleProvider);
  final jds = ref.watch(activeJDsProvider).valueOrNull ?? const [];
  if (query == null || query.trim().isEmpty || jds.isEmpty) return null;

  final normalizedQuery = query.trim().toLowerCase();

  // Exact (case-insensitive) title match wins outright.
  for (final jd in jds) {
    if (jd.title.toLowerCase() == normalizedQuery) return jd;
  }
  // Otherwise the first JD whose title contains the query, or vice versa.
  for (final jd in jds) {
    final title = jd.title.toLowerCase();
    if (title.contains(normalizedQuery) || normalizedQuery.contains(title)) return jd;
  }
  return null;
});

/// FR-16 — async result of running [MatchEngine.rankForRecruiterScan]
/// (Section 12.6) against every active student matching the current
/// [scanFiltersProvider], for [matchedJdProvider]. `null` until a search
/// has actually been run (distinguishes "haven't searched yet" from "0
/// results").
final scanResultsProvider = FutureProvider<List<StudentMatchSummary>?>((ref) async {
  final jd = ref.watch(matchedJdProvider);
  if (jd == null) return null;

  final filters = ref.watch(scanFiltersProvider);
  final repo = ref.watch(recruiterRepositoryProvider);

  final records = await repo.fetchActiveStudentsForScan(
    department: filters.department,
    batch: filters.batch,
    minCgpa: filters.minCgpa,
  );

  final profiles = records
      .map((r) => StudentProfile(
            uid: r.user.uid,
            fullName: r.user.fullName,
            cgpa: r.user.cgpa,
            courses: r.semesters.expand((s) => s.courses).where((c) => c.grade.isNotEmpty).toList(),
          ))
      .toList();

  final ranked = MatchEngine.rankForRecruiterScan(students: profiles, jd: jd);
  return ranked.take(filters.maxResults.clamp(1, 50)).toList(); // FR-18
});

/// S-22 Pipeline Board — live stream of this recruiter's placement
/// records.
final placementsProvider = StreamProvider<List<PlacementModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(recruiterRepositoryProvider).watchPlacements(uid);
});

/// S-18 Recruiter Dashboard — "Active job requests count card,
/// placements this month". Derived from [placementsProvider].
final placementsThisMonthProvider = Provider<int>((ref) {
  final placements = ref.watch(placementsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return placements.where((p) {
    final isPlaced = p.status == PlacementStatus.placed;
    final updated = p.updatedAt;
    return isPlaced && updated != null && updated.year == now.year && updated.month == now.month;
  }).length;
});
