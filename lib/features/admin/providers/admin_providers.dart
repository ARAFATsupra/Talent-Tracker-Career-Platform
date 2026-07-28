import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_model.dart';
import '../../../models/jd_model.dart';
import '../../../models/placement_model.dart';
import '../../../models/system_log_model.dart';
import '../../../models/user_model.dart';
import '../repository/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());

/// S-26 User Management — live stream of every account.
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllUsers();
});

/// S-28 JD Library — live stream of every JD, active and archived.
final allJDsProvider = StreamProvider<List<JDModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllJDs();
});

/// S-25 Admin Dashboard — "Total user count" (FR-24), broken down by role.
final userCountsByRoleProvider = Provider<Map<UserRole, int>>((ref) {
  final users = ref.watch(allUsersProvider).valueOrNull ?? const [];
  final counts = <UserRole, int>{for (final r in UserRole.values) r: 0};
  for (final u in users) {
    counts[u.role] = (counts[u.role] ?? 0) + 1;
  }
  return counts;
});

/// S-25 — "top 5 roles" chart. 🔶 Section 12 doesn't define what "top
/// role" measures (most JDs in that category? most placements?) — this
/// uses the count of ACTIVE JDs per `category` as the closest available
/// signal, since `placements` doesn't carry a JD category and isn't
/// guaranteed to span every admin's JD library yet at this stage of the
/// app's life. Easy to swap for a placements-based count once enough
/// placement history exists to make that meaningful.
final topRolesByJdCategoryProvider = Provider<List<MapEntry<String, int>>>((ref) {
  final jds = ref.watch(allJDsProvider).valueOrNull ?? const [];
  final counts = <String, int>{};
  for (final jd in jds.where((j) => j.isActive)) {
    counts[jd.category] = (counts[jd.category] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).toList();
});

/// S-25 — admin-wide live stream of every recruiter's `placements`
/// records. `firestore.rules` already grants Admin a full-collection
/// read (Phase 5), so this is a direct query rather than the
/// placeholder Phase 5/6 originally left here pending a Cloud Function
/// rollup — a live client-side stream is simple and accurate enough at
/// the data volumes a university placement system has.
final allPlacementsProvider = StreamProvider<List<PlacementModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.placements)
      .snapshots()
      .map((snap) => snap.docs.map((d) => PlacementModel.fromMap(d.id, d.data())).toList());
});

/// S-25 — "placements this month" admin-wide (every recruiter's placed
/// candidates this calendar month).
final adminPlacementsThisMonthProvider = Provider<int>((ref) {
  final placements = ref.watch(allPlacementsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return placements.where((p) {
    final isPlaced = p.status == PlacementStatus.placed;
    final updated = p.updatedAt;
    return isPlaced && updated != null && updated.year == now.year && updated.month == now.month;
  }).length;
});

// ------------------------------------------------------------------
// S-27 Course Master
// ------------------------------------------------------------------

final allCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllCourses();
});

// ------------------------------------------------------------------
// S-31 System Error Log
// ------------------------------------------------------------------

final systemLogsProvider = StreamProvider<List<SystemLogModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchSystemLogs();
});

/// S-25's "error count badge" — unresolved ERROR-severity logs.
final unresolvedErrorCountProvider = Provider<int>((ref) {
  final logs = ref.watch(systemLogsProvider).valueOrNull ?? const [];
  return logs.where((l) => l.severity == LogSeverity.error && !l.resolved).length;
});

// ------------------------------------------------------------------
// S-34 Monthly Analytics
// ------------------------------------------------------------------

/// One data point for S-34's line/bar charts — a calendar month plus a
/// count (registrations or placements, depending on which provider
/// produced it).
class MonthlyCount {
  final DateTime month; // always the 1st of the month
  final int count;
  const MonthlyCount({required this.month, required this.count});
}

/// "Line chart for registrations per month" — derived from
/// `users.createdAt`, the last 12 months.
final monthlyRegistrationsProvider = Provider<List<MonthlyCount>>((ref) {
  final users = ref.watch(allUsersProvider).valueOrNull ?? const [];
  return _bucketByMonth(users.map((u) => u.createdAt).whereType<DateTime>().toList());
});

/// "Bar chart for placements per month" — derived from `placements`
/// records whose status is `placed`, bucketed by `updatedAt` (the most
/// recent status change — the moment they actually became "placed").
final monthlyPlacementsProvider = Provider<List<MonthlyCount>>((ref) {
  final placements = ref.watch(allPlacementsProvider).valueOrNull ?? const [];
  final placedDates = placements
      .where((p) => p.status == PlacementStatus.placed)
      .map((p) => p.updatedAt)
      .whereType<DateTime>()
      .toList();
  return _bucketByMonth(placedDates);
});

List<MonthlyCount> _bucketByMonth(List<DateTime> dates) {
  final now = DateTime.now();
  final months = List.generate(12, (i) => DateTime(now.year, now.month - (11 - i), 1));

  final counts = <String, int>{};
  for (final d in dates) {
    final key = '${d.year}-${d.month}';
    counts[key] = (counts[key] ?? 0) + 1;
  }

  return months
      .map((m) => MonthlyCount(month: m, count: counts['${m.year}-${m.month}'] ?? 0))
      .toList();
}
