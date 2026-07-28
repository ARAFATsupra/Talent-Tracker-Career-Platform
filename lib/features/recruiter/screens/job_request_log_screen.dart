import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_constants.dart';
import '../../../models/placement_model.dart';
import '../providers/recruiter_providers.dart';

/// S-24 — Job Request Log Screen.
/// "History of every past candidate search done by this officer. Table:
/// date, job title searched, number of candidates returned, export icon
/// per row, filter by date range."
///
/// 🔶 The data this screen wants ("a search was run for X, Y candidates
/// came back") isn't stored anywhere — `placements` (Section 9.1) only
/// records students who were actually SHORTLISTED, not the full result
/// set of every scan (Phase 5's `scanResultsProvider` is ephemeral,
/// recomputed client-side and never persisted). Rather than add a new
/// `searchLog` collection the spec doesn't define, this screen groups
/// existing `placements` rows by (job title, search date) — each group
/// IS a real search that happened, and "number of candidates returned"
/// is honestly relabelled "shortlisted from this search" rather than
/// the full scan size, which this data model genuinely doesn't have.
/// A true search-history collection recording every scan (not just
/// successful shortlists) is a reasonable follow-up if exact "candidates
/// returned" counts matter for reporting.
class JobRequestLogScreen extends ConsumerStatefulWidget {
  const JobRequestLogScreen({super.key});

  @override
  ConsumerState<JobRequestLogScreen> createState() => _JobRequestLogScreenState();
}

class _JobRequestLogScreenState extends ConsumerState<JobRequestLogScreen> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final placementsAsync = ref.watch(placementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Request Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Filter by date range',
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: placementsAsync.when(
        data: (placements) {
          final groups = _groupBySearch(placements);
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No searches in your history yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _SearchLogRow(group: groups[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load your search history: $e')),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  List<_SearchGroup> _groupBySearch(List<PlacementModel> placements) {
    final filtered = _dateRange == null
        ? placements
        : placements.where((p) {
            final date = p.searchedAt;
            if (date == null) return false;
            return !date.isBefore(_dateRange!.start) &&
                !date.isAfter(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();

    final byKey = <String, _SearchGroup>{};
    for (final p in filtered) {
      final date = p.searchedAt ?? DateTime.now();
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final key = '${p.jobTitle}|$dayKey';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = _SearchGroup(jobTitle: p.jobTitle, date: date, candidateCount: 1);
      } else {
        byKey[key] = existing.copyWith(candidateCount: existing.candidateCount + 1);
      }
    }

    final groups = byKey.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }
}

class _SearchGroup {
  final String jobTitle;
  final DateTime date;
  final int candidateCount;

  const _SearchGroup({required this.jobTitle, required this.date, required this.candidateCount});

  _SearchGroup copyWith({int? candidateCount}) =>
      _SearchGroup(jobTitle: jobTitle, date: date, candidateCount: candidateCount ?? this.candidateCount);
}

class _SearchLogRow extends StatelessWidget {
  const _SearchLogRow({required this.group});

  final _SearchGroup group;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(group.jobTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(DateFormat('MMM d, yyyy').format(group.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${group.candidateCount}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryTeal),
              ),
              const Text('shortlisted', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            tooltip: 'Export this search (see Export Report, S-23)',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Use the Export Report screen to export a shortlist.')),
            ),
          ),
        ],
      ),
    );
  }
}
