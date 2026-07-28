import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../models/placement_model.dart';
import '../providers/recruiter_providers.dart';

/// S-22 — Pipeline Board Screen.
/// "Kanban columns: Shortlisted, Contacted, Interview Scheduled, Placed,
/// Rejected — drag student cards between columns."
///
/// FR-20 — move a candidate between stages. FR-40 — private notes per
/// candidate card.
///
/// 🔶 True drag-and-drop (`Draggable`/`DragTarget`) is straightforward to
/// layer on top of this once you've test-driven the simpler
/// tap-to-move interaction below — kept this way for Phase 5 so the
/// Kanban board works equally well on narrow phone screens (where
/// horizontal drag-and-drop across 5 columns is awkward) and is fully
/// usable via the accessibility-friendly "Move to" menu (Section 7.4 —
/// every interactive control needs a semantic label, which a drag
/// gesture alone wouldn't have).
class PipelineBoardScreen extends ConsumerWidget {
  const PipelineBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placementsAsync = ref.watch(placementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pipeline Board')),
      body: placementsAsync.when(
        data: (placements) {
          if (placements.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No candidates in your pipeline yet. Shortlist someone from a '
                  'Candidate Shortlist (S-20) search to get started.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final byStatus = <PlacementStatus, List<PlacementModel>>{
            for (final status in PlacementStatus.values) status: [],
          };
          for (final p in placements) {
            byStatus[p.status]!.add(p);
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in PlacementStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _KanbanColumn(status: status, placements: byStatus[status]!),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the pipeline: $e')),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.status, required this.placements});

  final PlacementStatus status;
  final List<PlacementModel> placements;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _columnColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${status.label} (${placements.length})',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: _columnColor(status)),
            ),
          ),
          const SizedBox(height: 8),
          for (final placement in placements) ...[
            _PipelineCard(placement: placement),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Color _columnColor(PlacementStatus status) {
    switch (status) {
      case PlacementStatus.shortlisted:
        return AppColors.primaryBlue;
      case PlacementStatus.contacted:
        return AppColors.secondaryTeal;
      case PlacementStatus.interviewScheduled:
        return AppColors.warningAmber;
      case PlacementStatus.placed:
        return AppColors.successGreen;
      case PlacementStatus.rejected:
        return AppColors.errorRed;
    }
  }
}

class _PipelineCard extends ConsumerWidget {
  const _PipelineCard({required this.placement});

  final PlacementModel placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/recruiter/profile/${placement.studentUid}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(placement.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(placement.jobTitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${placement.matchPercentage.toStringAsFixed(1)}% match',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryTeal, fontWeight: FontWeight.w600),
              ),
              if (placement.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  placement.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note, size: 18),
                    tooltip: 'Edit notes (FR-40)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editNotes(context, ref),
                  ),
                  PopupMenuButton<PlacementStatus>(
                    tooltip: 'Move to…',
                    icon: const Icon(Icons.move_down, size: 18),
                    onSelected: (status) =>
                        ref.read(recruiterRepositoryProvider).updateStatus(placement.id, status),
                    itemBuilder: (context) => PlacementStatus.values
                        .where((s) => s != placement.status)
                        .map((s) => PopupMenuItem(value: s, child: Text('Move to ${s.label}')))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: placement.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes — ${placement.studentName}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Private notes, visible only to you (FR-40)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      await ref.read(recruiterRepositoryProvider).updateNotes(placement.id, result);
    }
  }
}
