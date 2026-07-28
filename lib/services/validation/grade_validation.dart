import '../../app/app_constants.dart';

/// FR-06 / UT-08 — validation for the Grade Entry form (S09).
///
/// 🔶 This is intentionally STRICTER than [CourseGradeModel.isValid]:
/// that model allows a blank `grade` to represent "not taken yet" when
/// LOADING/STORING a course record (FR-31). But a SUBMITTED grade entry
/// on the form must be a real selection from the dropdown — a blank
/// field or an invalid value like 'Z' must be rejected with a validation
/// error and NOT saved to Firestore (UT-08).
class GradeValidation {
  const GradeValidation._();

  /// True if [grade] is one of the values in [validGrades] (Section 7.3:
  /// A+, A, A-, B+, B, B-, C+, C, D, F). Blank and unknown values (e.g.
  /// 'Z') return false.
  static bool isValidSubmission(String grade) {
    return validGrades.contains(grade);
  }

  /// Returns a user-facing error message for an invalid [grade], or null
  /// if it's valid. Use as a `TextFormField`/`DropdownButtonFormField`
  /// `validator`.
  static String? validate(String? grade) {
    if (grade == null || grade.isEmpty) {
      return 'Please select a grade.';
    }
    if (!validGrades.contains(grade)) {
      return 'Please select a valid grade from the list.';
    }
    return null;
  }
}
