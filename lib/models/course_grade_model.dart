import '../app/app_constants.dart';

/// One element of `SemesterModel.courses` — Section 9.3.
/// Represents a single course + grade entered by a student (FR-06).
class CourseGradeModel {
  final String courseCode;
  final String courseName;
  final int creditHours;
  final String grade; // one of validGrades, or '' if not yet taken/in progress
  final double gradePoint; // looked up from gradePoints; 0.0 if not taken
  final bool isCoreCourse;

  const CourseGradeModel({
    required this.courseCode,
    required this.courseName,
    required this.creditHours,
    required this.grade,
    required this.gradePoint,
    this.isCoreCourse = false,
  });

  /// Builds a course entry from a letter grade, looking up its grade point.
  /// Use this from the Grade Entry screen (S09) instead of constructing
  /// the model directly, so gradePoint always stays in sync with `grade`.
  factory CourseGradeModel.fromGrade({
    required String courseCode,
    required String courseName,
    required int creditHours,
    required String grade,
    bool isCoreCourse = false,
  }) {
    return CourseGradeModel(
      courseCode: courseCode,
      courseName: courseName,
      creditHours: creditHours,
      grade: grade,
      gradePoint: gradePoints[grade] ?? 0.0,
      isCoreCourse: isCoreCourse,
    );
  }

  /// A course not yet taken — counts as gradePoint 0 in the AI formula
  /// (Section 12.2: "Courses not yet taken by the student count as 0").
  factory CourseGradeModel.notTaken({
    required String courseCode,
    required String courseName,
    required int creditHours,
    bool isCoreCourse = false,
  }) {
    return CourseGradeModel(
      courseCode: courseCode,
      courseName: courseName,
      creditHours: creditHours,
      grade: '',
      gradePoint: 0.0,
      isCoreCourse: isCoreCourse,
    );
  }

  factory CourseGradeModel.fromMap(Map<String, dynamic> map) {
    return CourseGradeModel(
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      creditHours: map['creditHours'] ?? 0,
      grade: map['grade'] ?? '',
      gradePoint: (map['gradePoint'] ?? 0.0).toDouble(),
      isCoreCourse: map['isCoreCourse'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'creditHours': creditHours,
      'grade': grade,
      'gradePoint': gradePoint,
      'isCoreCourse': isCoreCourse,
    };
  }

  /// NFR-12 — basic validation before saving: non-empty fields, a valid
  /// grade from the dropdown, and positive credit hours. A blank `grade`
  /// is allowed (means "not taken yet" / in-progress, FR-31).
  bool get isValid =>
      courseCode.isNotEmpty &&
      courseName.isNotEmpty &&
      creditHours > 0 &&
      (grade.isEmpty || validGrades.contains(grade));

  /// Section 12.4 — flags an F grade (or grade below C) so the UI can show
  /// the red warning icon described in FR-35 / Section 15.
  bool get isFailingGrade => grade.isNotEmpty && gradePoint < 2.0;
}
