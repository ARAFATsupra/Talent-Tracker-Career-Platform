import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../models/match_score_result.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/recruiter_providers.dart';

/// S-20 — Candidate Shortlist Screen.
/// "Ranked rows: position, student name, CGPA, match %, key skill chips,
/// pipeline flag, View Profile button."
///
/// FR-16 — AI-ranked shortlist (Section 12.6). FR-17 — name, student ID,
/// CGPA, match %, View Profile. FR-20 — recruiters can add a candidate to
/// the pipeline straight from here ("pipeline flag").
class CandidateShortlistScreen extends ConsumerWidget {
  const CandidateShortlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobTitle = ref.watch(scanJobTitleProvider) ?? '';
    final matchedJd = ref.watch(matchedJdProvider);
    final resultsAsync = ref.watch(scanResultsProvider);
    final placements = ref.watch(placementsProvider).valueOrNull ?? const [];
    final shortlistedUids = placements.map((p) => p.studentUid).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(jobTitle.isEmpty ? 'Candidate Shortlist' : jobTitle)),
      body: matchedJd == null
          ? _NoMatchingJdState(jobTitle: jobTitle)
          : resultsAsync.when(
              data: (results) {
                if (results == null || results.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No active students matched your filters. Try widening the '
                        'department/batch/CGPA filters on the Job Search screen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final summary = results[index];
                    return _CandidateRow(
                      position: index + 1,
                      summary: summary,
                      jobTitle: matchedJd.title,
                      isShortlisted: shortlistedUids.contains(summary.studentUid),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not run the scan: $e')),
            ),
    );
  }
}

class _NoMatchingJdState extends StatelessWidget {
  const _NoMatchingJdState({required this.jobTitle});

  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              jobTitle.isEmpty
                  ? 'Search for a job title from the Job Search screen first.'
                  : 'No active job description in the library matches "$jobTitle".\n'
                      'Ask an admin to add it to the JD Library (S-28).',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateRow extends ConsumerWidget {
  const _CandidateRow({
    required this.position,
    required this.summary,
    required this.jobTitle,
    required this.isShortlisted,
  });

  final int position;
  final StudentMatchSummary summary;
  final String jobTitle;
  final bool isShortlisted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = summary.matchPercentage >= 70
        ? AppColors.successGreen
        : summary.matchPercentage >= 40
            ? AppColors.warningAmber
            : AppColors.errorRed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          child: Text('$position', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
        ),
        title: Text(summary.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text('CGPA ${summary.cgpa.toStringAsFixed(2)}'),
            const SizedBox(width: 10),
            Text(
              '${summary.matchPercentage.toStringAsFixed(1)}% match',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isShortlisted)
              const Tooltip(
                message: 'Already in your pipeline',
                child: Icon(Icons.flag, color: AppColors.secondaryTeal, size: 20),
              ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'View Profile',
              onPressed: () => context.push('/recruiter/profile/${summary.studentUid}'),
            ),
            if (!isShortlisted)
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Add to pipeline (Shortlist)',
                onPressed: () => _shortlist(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shortlist(BuildContext context, WidgetRef ref) async {
    final recruiterUid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (recruiterUid == null) return;

    await ref.read(recruiterRepositoryProvider).shortlistStudent(
          recruiterUid: recruiterUid,
          studentUid: summary.studentUid,
          studentName: summary.studentName,
          jobTitle: jobTitle,
          matchPercentage: summary.matchPercentage,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${summary.studentName} added to your pipeline (FR-20).')),
      );
    }
  }
}
