import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/recruiter_providers.dart';
import '../../student/providers/student_providers.dart';

/// S-19 — Job Search Screen (redesigned).
class JobSearchScreen extends ConsumerStatefulWidget {
  const JobSearchScreen({super.key});

  @override
  ConsumerState<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends ConsumerState<JobSearchScreen> {
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _batchController = TextEditingController();
  final _minCgpaController = TextEditingController();
  int _maxResults = 5;

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _batchController.dispose();
    _minCgpaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJDsAsync = ref.watch(activeJDsProvider);

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
                      Color(0xFF4A148C),
                      Color(0xFF6A1B9A),
                      Color(0xFF8E24AA),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF6A1B9A),
            title: const Text(
              'Job Search',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Job title',
                      labelStyle: TextStyle(color: Colors.grey[500]),
                      hintText: 'e.g. Junior Business Analyst',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6A1B9A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 10),

                // Autocomplete suggestions
                activeJDsAsync.when(
                  data: (jds) {
                    final query = _titleController.text.trim().toLowerCase();
                    final suggestions = query.isEmpty
                        ? const <String>[]
                        : jds
                            .map((j) => j.title)
                            .where((t) => t.toLowerCase().contains(query))
                            .take(4)
                            .toList();
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .map((title) => GestureDetector(
                                onTap: () => setState(() => _titleController.text = title),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6A1B9A).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6A1B9A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // Filters card
                Container(
                  padding: const EdgeInsets.all(18),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A1B9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF6A1B9A)),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _FilterField(
                        controller: _departmentController,
                        label: 'Department',
                        icon: Icons.business_outlined,
                      ),
                      const SizedBox(height: 12),
                      _FilterField(
                        controller: _batchController,
                        label: 'Batch / Graduation year',
                        icon: Icons.calendar_today_outlined,
                      ),
                      const SizedBox(height: 12),
                      _FilterField(
                        controller: _minCgpaController,
                        label: 'Minimum CGPA',
                        icon: Icons.grade_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 16, color: Color(0xFF6A1B9A)),
                          const SizedBox(width: 8),
                          Text(
                            'Candidates to return',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A1B9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_maxResults',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF6A1B9A),
                          inactiveTrackColor: const Color(0xFF6A1B9A).withOpacity(0.15),
                          thumbColor: const Color(0xFF6A1B9A),
                          overlayColor: const Color(0xFF6A1B9A).withOpacity(0.15),
                        ),
                        child: Slider(
                          value: _maxResults.toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '$_maxResults',
                          onChanged: (value) => setState(() => _maxResults = value.round()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Find candidates button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _titleController.text.trim().isEmpty
                          ? [Colors.grey[400]!, Colors.grey[400]!]
                          : const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _titleController.text.trim().isEmpty
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF6A1B9A).withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _titleController.text.trim().isEmpty ? null : _findCandidates,
                      borderRadius: BorderRadius.circular(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'FIND CANDIDATES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _findCandidates() {
    final minCgpaText = _minCgpaController.text.trim();
    final minCgpa = minCgpaText.isEmpty ? null : double.tryParse(minCgpaText);

    ref.read(scanFiltersProvider.notifier).state = ScanFilters(
      department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
      batch: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
      minCgpa: minCgpa,
      maxResults: _maxResults,
    );
    ref.read(scanJobTitleProvider.notifier).state = _titleController.text.trim();

    context.push('/recruiter/shortlist');
  }
}

// ── Reusable filter field ──────────────────────────────────────────────
class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
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
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
        isDense: true,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}