import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_grade_model.dart';
import '../repository/recruiter_repository.dart';
import '../providers/recruiter_providers.dart';

/// S-21 — Student Profile View (Recruiter).
/// "Student photo, major skills bar chart, semester grades summary, match
/// score ring, Contact button."
///
/// FR-17 — full profile, without showing sensitive private data. See the
/// 🔶 note on [RecruiterRepository.fetchStudentForProfileView] for which
/// fields that currently means.
class StudentProfileViewScreen extends ConsumerWidget {
  const StudentProfileViewScreen({super.key, required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordFuture = ref.watch(recruiterRepositoryProvider).fetchStudentForProfileView(studentUid);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile')),
      body: FutureBuilder<StudentScanRecord?>(
        future: recordFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final record = snapshot.data;
          if (record == null) {
            return const Center(child: Text('This student profile is no longer available.'));
          }

          final allCourses =
              record.semesters.expand((s) => s.courses).where((c) => c.grade.isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    backgroundImage:
                        record.user.profilePhotoUrl != null ? NetworkImage(record.user.profilePhotoUrl!) : null,
                    child: record.user.profilePhotoUrl == null
                        ? Text(
                            record.user.fullName.isNotEmpty ? record.user.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 24, color: AppColors.primaryBlue),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.user.fullName, style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          [record.user.department, record.user.batch].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CgpaRing(cgpa: record.user.cgpa),
              const SizedBox(height: 16),
              Text('Skills Demonstrated', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _SkillsBarChart(courses: allCourses),
              const SizedBox(height: 16),
              Text('Semester Grades Summary', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final semester in record.semesters.where((s) => s.courses.isNotEmpty))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(semester.semesterName),
                    subtitle: Text('${semester.courses.length} course(s)'),
                    trailing: Text(
                      'GPA ${semester.semesterGPA.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryTeal),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _showContactInfo(context, record.user.email),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('CONTACT'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showContactInfo(BuildContext context, String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Contact: $email')),
    );
  }
}

class _CgpaRing extends StatelessWidget {
  const _CgpaRing({required this.cgpa});

  final double cgpa;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (cgpa / 4.0).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    backgroundColor: AppColors.backgroundLight,
                    color: AppColors.secondaryTeal,
                  ),
                  Text(cgpa.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Cumulative GPA', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

/// "Major skills bar chart" — simplified as the top 5 highest-graded
/// courses, shown as horizontal bars sized by grade point. 🔶 The spec
/// doesn't define a skill-extraction step (Section 12.4's
/// skill-to-course mapping is a heuristic, same caveat as the AI engine
/// — see PHASE3_GUIDE.md item 5), so this shows COURSES, the concrete
/// data the engine actually has, rather than invented "skill" labels.
class _SkillsBarChart extends StatelessWidget {
  const _SkillsBarChart({required this.courses});

  final List<CourseGradeModel> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Text('No graded courses yet.', style: TextStyle(color: AppColors.textSecondary));
    }

    final top = [...courses]..sort((a, b) => b.gradePoint.compareTo(a.gradePoint));
    final topFive = top.take(5).toList();

    return Column(
      children: topFive
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(c.courseCode, style: const TextStyle(fontSize: 12))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (c.gradePoint / 4.0).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: AppColors.backgroundLight,
                          color: c.isFailingGrade ? AppColors.errorRed : AppColors.secondaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 32, child: Text(c.grade, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
