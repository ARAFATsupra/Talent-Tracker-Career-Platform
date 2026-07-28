import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/match_score_result.dart';
import '../providers/student_providers.dart';

/// S-13 — Skill Gap Roadmap Screen (redesigned).
class SkillGapRoadmapScreen extends ConsumerWidget {
  const SkillGapRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(roadmapJdEvaluationProvider);
    final roadmap = ref.watch(roadmapEntriesProvider);
    final currentSemester = ref.watch(currentSemesterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // ── Gradient header ────────────────────────────────────────
          Container(
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
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Skill Gap Roadmap',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _HeaderIcon(
                          icon: Icons.checklist_rounded,
                          tooltip: 'Progress Tracker',
                          onTap: () => context.push('/student/progress'),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIcon(
                          icon: Icons.picture_as_pdf_rounded,
                          tooltip: 'Export as PDF',
                          onTap: () => context.push('/student/roadmap/export'),
                        ),
                      ],
                    ),
                    if (evaluation != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Roadmap for',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              evaluation.score.jobTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${evaluation.gaps.length} skill gap${evaluation.gaps.length == 1 ? '' : 's'} to close',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: evaluation == null
                ? const _EmptyState(
                    message:
                        'No job roles are available yet — an admin needs to add '
                        'some to the JD library first.',
                  )
                : (roadmap.isEmpty
                    ? _EmptyState(
                        message: evaluation.gaps.isEmpty
                            ? '🎉 No skill gaps for "${evaluation.score.jobTitle}" — '
                                'you\'ve already taken every critical-path course!'
                            : 'You\'re already in or past the final semester, so '
                                'there\'s no room left to schedule remaining gaps.',
                        actionLabel: 'Pick a different role',
                        onAction: () => context.push('/student/roles'),
                      )
                    : _GanttChart(roadmap: roadmap, currentSemester: currentSemester)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student/roles'),
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.swap_horiz, color: Colors.white),
        label: const Text('Change role', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ── Header icon button ─────────────────────────────────────────────────
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Gantt chart ────────────────────────────────────────────────────────
class _GanttChart extends StatelessWidget {
  const _GanttChart({required this.roadmap, required this.currentSemester});

  final List<RoadmapEntry> roadmap;
  final int currentSemester;

  @override
  Widget build(BuildContext context) {
    final bySemester = <int, List<RoadmapEntry>>{};
    for (final entry in roadmap) {
      bySemester.putIfAbsent(entry.semesterNumber, () => []).add(entry);
    }
    final semesterNumbers = bySemester.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final semNum in semesterNumbers)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _SemesterColumn(
                semesterNumber: semNum,
                entries: bySemester[semNum]!,
                isNearest: semNum == semesterNumbers.first,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Semester column ────────────────────────────────────────────────────
class _SemesterColumn extends StatelessWidget {
  const _SemesterColumn({
    required this.semesterNumber,
    required this.entries,
    required this.isNearest,
  });

  final int semesterNumber;
  final List<RoadmapEntry> entries;
  final bool isNearest;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isNearest
                  ? const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                    )
                  : null,
              color: isNearest ? null : Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
              boxShadow: isNearest
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              'Semester $semesterNumber',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isNearest ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in entries) ...[
            _GapBlock(entry: entry),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ── Gap block card ─────────────────────────────────────────────────────
class _GapBlock extends StatelessWidget {
  const _GapBlock({required this.entry});

  final RoadmapEntry entry;

  @override
  Widget build(BuildContext context) {
    final gap = entry.gap;
    final priorityColor = _priorityColor(gap.weight);
    final priorityLabel = _priorityLabel(gap.weight);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: priorityColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored top strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconFor(gap.type), size: 16, color: priorityColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gap.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  gap.remediation,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(GapType type) {
    switch (type) {
      case GapType.notTaken:
        return Icons.school_outlined;
      case GapType.lowGrade:
        return Icons.replay_outlined;
      case GapType.missingSkill:
        return Icons.workspace_premium_outlined;
    }
  }

  Color _priorityColor(double weight) {
    if (weight >= 0.70) return const Color(0xFFD32F2F);
    if (weight >= 0.40) return const Color(0xFFEF6C00);
    return const Color(0xFF00897B);
  }

  String _priorityLabel(double weight) {
    if (weight >= 0.70) return 'HIGH PRIORITY';
    if (weight >= 0.40) return 'MEDIUM PRIORITY';
    return 'LOW PRIORITY';
  }
}

// ── Empty state ────────────────────────────────────────────────────────
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
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_outlined, size: 44, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}