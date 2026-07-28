import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_grade_model.dart';
import '../../../models/semester_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// S-10 — Grade Summary Screen (redesigned).
class GradeSummaryScreen extends ConsumerWidget {
  const GradeSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);
    final cgpa = ref.watch(currentUserModelProvider).valueOrNull?.cgpa ?? 0.0;

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
              'Grade Summary',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          semestersAsync.when(
            data: (semesters) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CgpaCard(cgpa: cgpa),
                  const SizedBox(height: 20),
                  const Text(
                    'Semesters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final semester in semesters)
                    _SemesterCard(semester: semester),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Could not load grades: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CGPA hero card ─────────────────────────────────────────────────────
class _CgpaCard extends StatelessWidget {
  const _CgpaCard({required this.cgpa});

  final double cgpa;

  @override
  Widget build(BuildContext context) {
    final percent = (cgpa / 4.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Cumulative GPA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cgpa.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '/ 4.00',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(percent * 100).toStringAsFixed(0)}% of maximum GPA',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Semester card ──────────────────────────────────────────────────────
class _SemesterCard extends StatelessWidget {
  const _SemesterCard({required this.semester});

  final SemesterModel semester;

  @override
  Widget build(BuildContext context) {
    final hasCourses = semester.courses.isNotEmpty;

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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasCourses
                    ? [const Color(0xFF1565C0), const Color(0xFF0288D1)]
                    : [Colors.grey[300]!, Colors.grey[400]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${semester.semesterNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            semester.semesterName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Text(
            hasCourses
                ? 'GPA ${semester.semesterGPA.toStringAsFixed(2)} · ${semester.courses.length} course${semester.courses.length == 1 ? '' : 's'}'
                : 'No grades entered yet',
            style: TextStyle(
              fontSize: 12,
              color: hasCourses ? const Color(0xFF00897B) : Colors.grey[500],
              fontWeight: hasCourses ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: GestureDetector(
            onTap: () => context.push('/student/grades'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          children: [
            if (!hasCourses)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Tap the edit icon to enter grades for this semester.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: semester.courses
                      .map((c) => _GradeChip(course: c))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Grade chip ──────────────────────────────────────────────────────────
class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.course});

  final CourseGradeModel course;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(course);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${course.courseCode} · ${course.grade.isEmpty ? "N/A" : course.grade}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(CourseGradeModel c) {
    if (c.grade.isEmpty) return AppColors.textSecondary;
    if (c.isFailingGrade) return const Color(0xFFD32F2F);
    if (c.gradePoint >= 3.5) return const Color(0xFF00897B);
    return const Color(0xFFEF6C00);
  }
}