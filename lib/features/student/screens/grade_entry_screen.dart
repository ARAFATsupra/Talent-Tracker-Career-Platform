import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_grade_model.dart';
import '../../../models/semester_model.dart';
import '../../../services/validation/grade_validation.dart';
import '../../auth/providers/auth_providers.dart';
import '../controllers/grade_entry_controller.dart';
import '../providers/student_providers.dart';

/// S-09 — Grade Entry Screen (redesigned).
class GradeEntryScreen extends StatefulWidget {
  const GradeEntryScreen({super.key});

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: totalSemesters, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
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
              'Grade Entry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            leading: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: const Color(0xFF1565C0),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: List.generate(
                    totalSemesters,
                    (i) => Tab(text: 'Sem ${i + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: List.generate(
            totalSemesters,
            (i) => _SemesterTab(semesterNumber: i + 1),
          ),
        ),
      ),
    );
  }
}

class _SemesterTab extends ConsumerWidget {
  const _SemesterTab({required this.semesterNumber});

  final int semesterNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(isGradeProfileLockedProvider);
    final semester = ref.watch(gradeEntryControllerProvider(semesterNumber));
    final controller =
        ref.read(gradeEntryControllerProvider(semesterNumber).notifier);

    return Column(
      children: [
        // Locked banner
        if (isLocked)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningAmber.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    color: AppColors.warningAmber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Semester 8 is marked complete — grade history is read-only.',
                    style: TextStyle(
                      color: AppColors.warningAmber.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Course list
        Expanded(
          child: semester.courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 36,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No courses yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Add Course" below to get started\nfor Semester $semesterNumber.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: semester.courses.length,
                  itemBuilder: (context, index) {
                    return _CourseRow(
                      key: ValueKey('sem${semesterNumber}_course$index'),
                      course: semester.courses[index],
                      isLocked: isLocked,
                      index: index,
                      onChanged: (updated) =>
                          controller.updateCourseAt(index, updated),
                      onRemove: () => controller.removeCourseAt(index),
                    );
                  },
                ),
        ),

        // Bottom bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GPA + Mark complete row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'GPA: ${controller.liveGPA.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (semesterNumber == totalSemesters) ...[
                    Text(
                      'Mark complete',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                    Switch(
                      value: semester.isComplete,
                      activeColor: const Color(0xFF1565C0),
                      onChanged: isLocked
                          ? null
                          : (value) => controller.setComplete(value),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  // Add course button
                  if (!isLocked) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.addCourse,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Course'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Save button
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isLocked
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF1565C0),
                                  Color(0xFF0288D1),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        color: isLocked ? Colors.grey[300] : null,
                      ),
                      child: ElevatedButton(
                        onPressed: isLocked
                            ? null
                            : () => _saveSemester(context, ref, semester),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'SAVE',
                          style: TextStyle(
                            color: isLocked
                                ? Colors.grey[600]
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveSemester(
      BuildContext context, WidgetRef ref, SemesterModel semester) async {
    for (final course in semester.courses) {
      final gradeError = GradeValidation.validate(course.grade);
      if (gradeError != null ||
          course.courseCode.trim().isEmpty ||
          course.courseName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please fill in every course (name, code, and a valid grade) '
              'before saving Semester $semesterNumber.',
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;

    await ref.read(gradeRepositoryProvider).saveSemester(uid, semester);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semester $semesterNumber saved ✓'),
          backgroundColor: const Color(0xFF00695C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.isLocked,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final CourseGradeModel course;
  final bool isLocked;
  final int index;
  final ValueChanged<CourseGradeModel> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with course number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1565C0).withOpacity(0.08),
                  const Color(0xFF0288D1).withOpacity(0.04),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Course',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const Spacer(),
                if (!isLocked)
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: AppColors.errorRed,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Fields
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _Field(
                        label: 'Course Name',
                        initialValue: course.courseName,
                        enabled: !isLocked,
                        onChanged: (v) => onChanged(_copy(courseName: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        label: 'Code',
                        initialValue: course.courseCode,
                        enabled: !isLocked,
                        onChanged: (v) => onChanged(_copy(courseCode: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: _DropdownField<int>(
                        label: 'Credits',
                        value: course.creditHours > 0 ? course.creditHours : 3,
                        items: ({
                          1,
                          2,
                          3,
                          4,
                          if (course.creditHours > 0) course.creditHours
                        }.toList()
                              ..sort())
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('$c'),
                                ))
                            .toList(),
                        enabled: !isLocked,
                        onChanged: (v) {
                          if (v != null) onChanged(_copy(creditHours: v));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DropdownField<String>(
                        label: 'Grade',
                        value: course.grade.isEmpty ? null : course.grade,
                        hint: 'Select',
                        items: validGrades
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ))
                            .toList(),
                        enabled: !isLocked,
                        onChanged: (v) {
                          if (v != null) onChanged(_copy(grade: v));
                        },
                      ),
                    ),
                  ],
                ),
                if (course.grade.isNotEmpty && course.isFailingGrade) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.errorRed),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Below a C — this will show as a skill gap',
                            style: TextStyle(
                                color: AppColors.errorRed, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  CourseGradeModel _copy({
    String? courseName,
    String? courseCode,
    int? creditHours,
    String? grade,
  }) {
    final newGrade = grade ?? course.grade;
    return CourseGradeModel.fromGrade(
      courseCode: courseCode ?? course.courseCode,
      courseName: courseName ?? course.courseName,
      creditHours: creditHours ?? course.creditHours,
      grade: newGrade,
      isCoreCourse: course.isCoreCourse,
    );
  }
}

// ── Reusable text field ───────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          borderSide:
              const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[100]!),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Reusable dropdown field ───────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final bool enabled;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      hint: hint != null ? Text(hint!, style: const TextStyle(fontSize: 13)) : null,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          borderSide:
              const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[100]!),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}