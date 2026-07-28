import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/jd_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/admin_providers.dart';

/// S-28 — JD Library Screen (redesigned).
class JDLibraryScreen extends ConsumerWidget {
  const JDLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jdsAsync = ref.watch(allJDsProvider);

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
            actions: [
              IconButton(
                icon: const Icon(Icons.upload_file_outlined, color: Colors.white),
                tooltip: 'Batch CSV upload',
                onPressed: () => _showCsvComingSoon(context),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF004D40),
                      Color(0xFF00695C),
                      Color(0xFF00897B),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF00695C),
            title: const Text(
              'JD Library',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          jdsAsync.when(
            data: (jds) {
              if (jds.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.work_off_outlined, size: 40, color: Color(0xFF00897B)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No job descriptions yet.\nTap + to add the first one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final jd in jds) _JDCard(jd: jd),
                    const SizedBox(height: 70),
                  ]),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Could not load the JD library: $e'))),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00695C).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _openEditor(context, existing: null),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showCsvComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Batch CSV upload is planned for a later phase.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openEditor(BuildContext context, {required JDModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JDEditorSheet(existing: existing),
    );
  }
}

// ── JD card ────────────────────────────────────────────────────────────
class _JDCard extends ConsumerWidget {
  const _JDCard({required this.jd});

  final JDModel jd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _previewJd(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: jd.isActive
                              ? [const Color(0xFF00897B), const Color(0xFF00695C)]
                              : [Colors.grey[400]!, Colors.grey[500]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.work_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jd.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${jd.category} · ${jd.criticalPathCourses.length} weighted course(s)',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: jd.isActive,
                      activeColor: const Color(0xFF00897B),
                      onChanged: (value) => ref.read(adminRepositoryProvider).setJDActive(jd.jdId, value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _MiniActionButton(
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF6A1B9A),
                      tooltip: 'AI Weighting Config',
                      onTap: () => context.push('/admin/jds/${jd.jdId}/weights'),
                    ),
                    const SizedBox(width: 8),
                    _MiniActionButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF1565C0),
                      tooltip: 'Edit',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _JDEditorSheet(existing: jd),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _previewJd(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(jd.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(jd.category, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('Salary: ৳${jd.salaryMinBDT} – ৳${jd.salaryMaxBDT}/month'),
              const SizedBox(height: 8),
              const Text('Required skills:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(jd.requiredSkills.isEmpty ? 'None listed' : jd.requiredSkills.join(', ')),
              const SizedBox(height: 8),
              const Text('Critical-path courses:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(jd.criticalPathCourses.isEmpty ? 'None configured' : jd.criticalPathCourses.join(', ')),
              if (jd.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Source:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(jd.sourceUrl, style: const TextStyle(color: Color(0xFF1565C0))),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

// ── Mini action button ─────────────────────────────────────────────────
class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ── JD editor sheet ────────────────────────────────────────────────────
class _JDEditorSheet extends ConsumerStatefulWidget {
  const _JDEditorSheet({required this.existing});

  final JDModel? existing;

  @override
  ConsumerState<_JDEditorSheet> createState() => _JDEditorSheetState();
}

class _JDEditorSheetState extends ConsumerState<_JDEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _skills;
  late final TextEditingController _salaryMin;
  late final TextEditingController _salaryMax;
  late final TextEditingController _sourceUrl;
  late final TextEditingController _certifications;

  @override
  void initState() {
    super.initState();
    final jd = widget.existing;
    _title = TextEditingController(text: jd?.title ?? '');
    _category = TextEditingController(text: jd?.category ?? '');
    _skills = TextEditingController(text: jd?.requiredSkills.join(', ') ?? '');
    _salaryMin = TextEditingController(text: jd?.salaryMinBDT.toString() ?? '');
    _salaryMax = TextEditingController(text: jd?.salaryMaxBDT.toString() ?? '');
    _sourceUrl = TextEditingController(text: jd?.sourceUrl ?? '');
    _certifications = TextEditingController(text: jd?.certifications.join(', ') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _skills.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _sourceUrl.dispose();
    _certifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              isEditing ? 'Edit Job Description' : 'New Job Description',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 18),
            _Field(controller: _title, label: 'Job title'),
            const SizedBox(height: 12),
            _Field(controller: _category, label: 'Category'),
            const SizedBox(height: 12),
            _Field(controller: _skills, label: 'Required skills (comma-separated)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _salaryMin,
                    label: 'Min salary (BDT)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _salaryMax,
                    label: 'Max salary (BDT)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Field(controller: _sourceUrl, label: 'Source URL'),
            const SizedBox(height: 12),
            _Field(controller: _certifications, label: 'Certifications (comma-separated)'),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isEditing ? 'SAVE CHANGES' : 'CREATE JD',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final adminUid = ref.read(authStateChangesProvider).valueOrNull?.uid ?? '';
    final existing = widget.existing;

    final jd = JDModel(
      jdId: existing?.jdId ?? '',
      title: _title.text.trim(),
      category: _category.text.trim(),
      requiredSkills: _splitCsv(_skills.text),
      criticalPathCourses: existing?.criticalPathCourses ?? const [],
      courseWeights: existing?.courseWeights ?? const {},
      salaryMinBDT: int.tryParse(_salaryMin.text.trim()) ?? 0,
      salaryMaxBDT: int.tryParse(_salaryMax.text.trim()) ?? 0,
      sourceUrl: _sourceUrl.text.trim(),
      certifications: _splitCsv(_certifications.text),
      remediations: existing?.remediations ?? const {},
      isActive: existing?.isActive ?? true,
      addedBy: existing?.addedBy ?? adminUid,
      createdAt: existing?.createdAt,
    );

    final repo = ref.read(adminRepositoryProvider);
    if (existing == null) {
      await repo.createJD(jd, adminUid);
    } else {
      await repo.updateJD(jd);
    }

    if (mounted) Navigator.pop(context);
  }

  List<String> _splitCsv(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

// ── Reusable field ─────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}