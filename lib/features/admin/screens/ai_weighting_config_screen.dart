import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/jd_model.dart';
import '../providers/admin_providers.dart';

/// S-29 — AI Weighting Config Screen.
/// "Matrix table: courses as rows, roles as columns, numeric weight input
/// (0.0 to 1.0) per cell, Save and Reset buttons."
///
/// FR-25 — "configure the AI weighting model through a UI form, without
/// writing any code."
///
/// 🔶 Section 5.4 describes a full matrix (every course × every role in
/// one screen). This phase implements the same DATA model — Section
/// 12.2's `criticalPathCourses` + `courseWeights` per JD — but scoped to
/// ONE role at a time (reached from its row on the JD Library, S-28),
/// since that's both simpler to review and matches how Section 12.3's
/// worked example and Section 10.13's sample config are presented (one
/// role's weight table). A true cross-role matrix view is a thin layer
/// on top of this same Firestore shape if you want it later — every JD
/// already stores its own independent `courseWeights` map.
class AiWeightingConfigScreen extends ConsumerStatefulWidget {
  const AiWeightingConfigScreen({super.key, required this.jdId});

  final String jdId;

  @override
  ConsumerState<AiWeightingConfigScreen> createState() => _AiWeightingConfigScreenState();
}

class _AiWeightingConfigScreenState extends ConsumerState<AiWeightingConfigScreen> {
  // courseCode -> editable weight text. Loaded once the JD streams in,
  // then edited locally until Save (FR-25's form, not a live-write-per-
  // keystroke control).
  final Map<String, TextEditingController> _controllers = {};
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jdsAsync = ref.watch(allJDsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Weighting Config')),
      body: jdsAsync.when(
        data: (jds) {
          final matches = jds.where((j) => j.jdId == widget.jdId);
          if (matches.isEmpty) {
            return const Center(child: Text('This JD is no longer available.'));
          }
          final jd = matches.first;
          _seedControllers(jd);

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.primaryBlue.withOpacity(0.06),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jd.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    const Text(
                      'Weight = how important this course is for this role, 0.0–1.0 '
                      '(Section 12.2). Courses with weight 0 are fully excluded from '
                      'scoring (UT-09).',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final code in _controllers.keys.toList()..sort())
                      _WeightRow(
                        courseCode: code,
                        controller: _controllers[code]!,
                        onRemove: () => setState(() => _controllers.remove(code)),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _addCourseDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add course to this role'),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _controllers.clear();
                            _seeded = false;
                            _seedControllers(jd);
                          }),
                          child: const Text('RESET'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _save(jd),
                          child: const Text('SAVE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load this role: $e')),
      ),
    );
  }

  void _seedControllers(JDModel jd) {
    if (_seeded) return;
    _seeded = true;
    // Seed from criticalPathCourses (Section 12.2's actual scoring set);
    // any extra entries in courseWeights with no row here yet are also
    // included, matching Section 10.13's sample which lists a couple of
    // weighted courses outside the scored critical path.
    final codes = {...jd.criticalPathCourses, ...jd.courseWeights.keys};
    for (final code in codes) {
      _controllers[code] = TextEditingController(text: (jd.courseWeights[code] ?? 0.0).toStringAsFixed(2));
    }
  }

  Future<void> _addCourseDialog(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add course'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Course code, e.g. CSE-303'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && !_controllers.containsKey(code)) {
      setState(() => _controllers[code] = TextEditingController(text: '0.50'));
    }
  }

  Future<void> _save(JDModel jd) async {
    final weights = <String, double>{};
    for (final entry in _controllers.entries) {
      final parsed = double.tryParse(entry.value.text.trim());
      if (parsed != null) {
        weights[entry.key] = parsed.clamp(0.0, 1.0);
      }
    }
    // criticalPathCourses = every row with weight > 0 — Section 12.2 only
    // scores courses in this list, so a 0-weight row is saved in the
    // matrix (for visibility/audit) but left out of the scored set,
    // matching how a 0-weight critical-path course is treated anyway
    // (UT-09: excluded from scoring either way).
    final criticalPath = weights.entries.where((e) => e.value > 0).map((e) => e.key).toList();

    await ref.read(adminRepositoryProvider).updateCourseWeights(
          jd.jdId,
          criticalPathCourses: criticalPath,
          courseWeights: weights,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weights saved — takes effect immediately for every student (FR-25).')),
      );
    }
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.courseCode, required this.controller, required this.onRemove});

  final String courseCode;
  final TextEditingController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(courseCode, style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.errorRed),
            tooltip: 'Remove from this role',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
