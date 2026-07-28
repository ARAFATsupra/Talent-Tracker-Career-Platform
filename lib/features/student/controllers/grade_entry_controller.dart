import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/course_grade_model.dart';
import '../../../models/semester_model.dart';
import '../providers/student_providers.dart';

/// FR-06 / FR-13 — Grade Entry screen (S-09) state for ONE semester.
///
/// Holds a working DRAFT of [SemesterModel] (courses + the "complete"
/// toggle) for a single semester tab. Edits are local until
/// [GradeEntryScreen] calls [GradeRepository.saveSemester] with
/// [GradeEntryController.state] — this matches FR-13 ("save and update
/// grade data at any time").
///
/// One instance per semester number (1..[totalSemesters]) via
/// [gradeEntryControllerProvider]'s `.family`.
class GradeEntryController extends StateNotifier<SemesterModel> {
  GradeEntryController(super.state);

  /// FR-06 — adds a blank course row for the student to fill in.
  void addCourse() {
    state = state.copyWith(courses: [
      ...state.courses,
      CourseGradeModel.notTaken(courseCode: '', courseName: '', creditHours: 3),
    ]);
  }

  void removeCourseAt(int index) {
    final updated = [...state.courses]..removeAt(index);
    state = state.copyWith(courses: updated);
  }

  /// Replaces the course at [index] — called whenever the student edits a
  /// course name/code/credits/grade field.
  void updateCourseAt(int index, CourseGradeModel course) {
    final updated = [...state.courses];
    updated[index] = course;
    state = state.copyWith(courses: updated);
  }

  /// FR-13 — "before the final semester is marked complete". Toggling
  /// this on for Semester [totalSemesters] locks the whole grade history
  /// (see [isGradeProfileLockedProvider]).
  void setComplete(bool value) {
    state = state.copyWith(isComplete: value);
  }

  /// FR-07 — live GPA preview as the student edits, before saving.
  double get liveGPA => SemesterModel.calculateGPA(state.courses);
}

/// One [GradeEntryController] per semester number (1..[totalSemesters]),
/// seeded from [semestersProvider]'s current value for that semester.
final gradeEntryControllerProvider =
    StateNotifierProvider.family<GradeEntryController, SemesterModel, int>((ref, semesterNumber) {
  final semesters = ref.watch(semestersProvider).valueOrNull;
  SemesterModel? initial;
  if (semesters != null) {
    for (final s in semesters) {
      if (s.semesterNumber == semesterNumber) {
        initial = s;
        break;
      }
    }
  }
  initial ??= SemesterModel(semesterNumber: semesterNumber, semesterName: 'Semester $semesterNumber');
  return GradeEntryController(initial);
});
