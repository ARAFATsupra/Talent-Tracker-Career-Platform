import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/match_score_result.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// S-17 — Progress Tracker Screen (redesigned).
class ProgressTrackerScreen extends ConsumerWidget {
  const ProgressTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(roadmapJdEvaluationProvider);
    final completedKeys = ref.watch(completedGapKeysProvider).valueOrNull ?? const {};
    final projectedScore = ref.watch(projectedScoreAfterCompletionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            leading: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF1565C0),
                      Color(0xFF0288D1),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF1565C0),
            title: const Text(
              'Progress Tracker',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          evaluation == null
              ? const SliverFillRemaining(
                  child: _EmptyState(
                    message: 'No job roles available yet to track progress against.',
                  ),
                )
              : evaluation.gaps.isEmpty
                  ? SliverFillRemaining(
                      child: _EmptyState(
                        message:
                            '🎉 No open skill gaps for "${evaluation.score.jobTitle}" — nothing left to track!',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _ProgressHeader(
                            jobTitle: evaluation.score.jobTitle,
                            totalGaps: evaluation.gaps.length,
                            completedCount: evaluation.gaps
                                .where((g) => completedKeys.contains(g.gapKey))
                                .length,
                            currentScore: evaluation.score.matchPercentage,
                            projectedScore: projectedScore,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Skill Gaps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final gap in evaluation.gaps)
                            _GapChecklistTile(
                              gap: gap,
                              done: completedKeys.contains(gap.gapKey),
                            ),
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
        ],
      ),
    );
  }
}

// ── Progress header card ──────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.jobTitle,
    required this.totalGaps,
    required this.completedCount,
    required this.currentScore,
    required this.projectedScore,
  });

  final String jobTitle;
  final int totalGaps;
  final int completedCount;
  final double currentScore;
  final double? projectedScore;

  @override
  Widget build(BuildContext context) {
    final completionFraction = totalGaps == 0 ? 0.0 : completedCount / totalGaps;
    final showsProjection = projectedScore != null && projectedScore! > currentScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jobTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount of $totalGaps gap${totalGaps == 1 ? '' : 's'} marked done',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completionFraction,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(completionFraction * 100).toStringAsFixed(0)}% complete',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ScorePill(
                label: 'Current Match',
                value: currentScore,
                icon: Icons.gps_fixed_rounded,
              ),
              if (showsProjection) ...[
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 10),
                _ScorePill(
                  label: 'Projected',
                  value: projectedScore!,
                  icon: Icons.trending_up_rounded,
                  isProjected: true,
                ),
              ],
            ],
          ),
          if (showsProjection) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Projected score assumes a B+ in each completed course — it updates '
                    'once you actually enter that grade.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.65),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Score pill ─────────────────────────────────────────────────────────
class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
    required this.icon,
    this.isProjected = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool isProjected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isProjected ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(12),
        border: isProjected ? Border.all(color: Colors.white.withOpacity(0.4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gap checklist tile ────────────────────────────────────────────────
class _GapChecklistTile extends ConsumerWidget {
  const _GapChecklistTile({required this.gap, required this.done});

  final SkillGap gap;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? const Color(0xFF00897B).withOpacity(0.3) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggle(ref, !done),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom checkbox
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    gradient: done
                        ? const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF00695C)],
                          )
                        : null,
                    color: done ? null : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: done ? Colors.transparent : Colors.grey[350]!,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gap.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey[400] : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gap.remediation,
                        style: TextStyle(
                          fontSize: 12,
                          color: done ? Colors.grey[400] : Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, bool done) async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(progressRepositoryProvider).setGapDone(uid, gap.gapKey, done);
  }
}

// ── Empty state ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rounded, size: 44, color: Color(0xFF6A1B9A)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}