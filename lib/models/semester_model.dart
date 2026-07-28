import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_grade_model.dart';

/// Firestore: users/{uid}/semesters/{semesterId} — Section 9.3.
/// One document per semester per student.
class SemesterModel {
  final int semesterNumber; // 1 to 8 (FR-06)
  final String semesterName; // e.g. "Spring 2023"
  final bool isComplete; // FR-13 — grades editable until final semester is complete
  final double semesterGPA; // FR-07
  final List<CourseGradeModel> courses;
  final DateTime? updatedAt;

  const SemesterModel({
    required this.semesterNumber,
    required this.semesterName,
    this.isComplete = false,
    this.semesterGPA = 0.0,
    this.courses = const [],
    this.updatedAt,
  });

  /// Used by the Grade Entry screen (S-09) to build an updated draft
  /// after adding/removing/editing a course or toggling "complete".
  SemesterModel copyWith({
    bool? isComplete,
    double? semesterGPA,
    List<CourseGradeModel>? courses,
  }) {
    return SemesterModel(
      semesterNumber: semesterNumber,
      semesterName: semesterName,
      isComplete: isComplete ?? this.isComplete,
      semesterGPA: semesterGPA ?? this.semesterGPA,
      courses: courses ?? this.courses,
      updatedAt: updatedAt,
    );
  }

  factory SemesterModel.fromMap(Map<String, dynamic> map) {
    return SemesterModel(
      semesterNumber: map['semesterNumber'] ?? 0,
      semesterName: map['semesterName'] ?? '',
      isComplete: map['isComplete'] ?? false,
      semesterGPA: (map['semesterGPA'] ?? 0.0).toDouble(),
      courses: ((map['courses'] as List?) ?? [])
          .map((c) => CourseGradeModel.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'semesterNumber': semesterNumber,
      'semesterName': semesterName,
      'isComplete': isComplete,
      'semesterGPA': semesterGPA,
      'courses': courses.map((c) => c.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// FR-07 — Semester GPA = sum(gradePoint * creditHours) / sum(creditHours),
  /// the standard 4.0-scale credit-weighted average.
  ///
  /// Courses with no grade entered yet (grade == '') are excluded from the
  /// denominator entirely — this keeps an "In Progress" semester (FR-31)
  /// from being dragged to 0.0 just because one course is still pending.
  ///
  /// Related to UT-01 (5 courses: A+, A, B+, B, C+). 🔶 With equal credit
  /// hours (e.g. 3 credits each) and the gradePoints table in
  /// app_constants.dart (A+=4.00, A=3.75, B+=3.50, B=3.25, C+=2.50), this
  /// formula gives GPA = 3.40 — not the 3.35 stated in Section 17.1. The
  /// 0.05 difference suggests either an unspecified non-equal credit-hour
  /// assumption in the spec, or a minor arithmetic discrepancy; see
  /// test/models/semester_model_test.dart and PHASE3_GUIDE.md for details.
  /// The formula itself (credit-weighted average) is correct per FR-07.
  static double calculateGPA(List<CourseGradeModel> courses) {
    final graded = courses.where((c) => c.grade.isNotEmpty).toList();
    if (graded.isEmpty) return 0.0;

    final totalPoints = graded.fold<double>(
        0, (sum, c) => sum + (c.gradePoint * c.creditHours));
    final totalCredits = graded.fold<int>(0, (sum, c) => sum + c.creditHours);

    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  /// FR-07 — CGPA across multiple semesters, same credit-weighted formula
  /// applied over every course from every semester. This is mathematically
  /// equivalent to a credit-weighted average of each semester's GPA.
  ///
  /// UT-02 (GPAs 3.80, 3.60, 3.20 over 18/18/15 credits): (3.80*18 +
  /// 3.60*18 + 3.20*15) / 51 = 181.2 / 51 ≈ 3.5529, which rounds to 3.55 —
  /// 🔶 the spec's stated "3.56" is off by ~0.003, likely a rounding
  /// artifact in the worked numbers. See test/models/semester_model_test.dart.
  static double calculateCGPA(List<SemesterModel> semesters) {
    final allCourses = semesters.expand((s) => s.courses).toList();
    return calculateGPA(allCourses);
  }
}
