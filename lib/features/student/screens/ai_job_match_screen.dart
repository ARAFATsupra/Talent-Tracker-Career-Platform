import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../models/match_score_result.dart';
import '../providers/student_providers.dart';

/// S-11 — AI Job Match Screen.
/// "Donut chart per role showing match %, role title card, matched vs
/// missing skill badges, tap to expand full JD."
///
/// FR-08 — exactly 3 recommendations. FR-09 — title, skills, salary range,
/// JD source link (shown on S-12). FR-10 — missing skills per role.
class AiJobMatchScreen extends ConsumerWidget {
  const AiJobMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(allGradedCoursesProvider);
    final activeJDsAsync = ref.watch(activeJDsProvider);
    final top3 = ref.watch(top3EvaluationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Job Match')),
      body: activeJDsAsync.when(
        data: (jds) {
          if (jds.isEmpty) {
            return const _EmptyState(
              message: 'No job roles are in the library yet — check back once the admin '
                  'has added some (Section 9.4).',
            );
          }

          // UT-04 — student has no grades anywhere: block the match
          // results and prompt them to fill in the Grade Entry screen.
          if (courses.isEmpty) {
            return _EmptyState(
              message: 'Enter your semester grades first — the AI engine needs at least '
                  'one course to calculate job matches.',
              actionLabel: 'Go to Grade Entry',
              onAction: () => context.push('/student/grades'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your top ${top3.length} matched role${top3.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Based on the AI Matching Engine (Section 12.2) using all the grades '
                "you've entered so far.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              for (final evaluation in top3) _MatchCard(evaluation: evaluation),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/student/roles'),
                icon: const Icon(Icons.search),
                label: const Text('Browse all roles (Desired Role Selector)'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load job roles: $e')),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.evaluation});

  final JDEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final score = evaluation.score;
    final missingSkills = evaluation.gaps
        .where((g) => g.type == GapType.missingSkill)
        .map((g) => g.skillName ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
    // Skills considered "matched" are required skills not flagged as gaps.
    // (jd.requiredSkills isn't directly on JDEvaluation, so this card just
    // shows missing skills + a confidence note; S-12 shows the full
    // matched/gap checklist against jd.requiredSkills.)

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/student/matches/${score.jdId}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DonutScore(percentage: score.matchPercentage),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(score.jobTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    if (score.confidence == MatchConfidence.partial)
                      const _ConfidenceBadge(
                        icon: Icons.info_outline,
                        color: AppColors.warningAmber,
                        label: 'Partial — some critical courses not taken yet',
                      ),
                    if (missingSkills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Skill gaps', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: missingSkills
                            .map((skill) => Chip(
                                  label: Text(skill, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppColors.errorRed.withOpacity(0.1),
                                  labelStyle: const TextStyle(color: AppColors.errorRed),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donut-style match percentage indicator.
class _DonutScore extends StatelessWidget {
  const _DonutScore({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 70
        ? AppColors.successGreen
        : percentage >= 40
            ? AppColors.warningAmber
            : AppColors.errorRed;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: AppColors.backgroundLight,
              color: color,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 12))),
      ],
    );
  }
}

/// Section 7.3 — "All empty states show an illustration... a short
/// message and a Retry button." (using an icon in place of an
/// illustration asset, and an optional custom action instead of Retry.)
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
