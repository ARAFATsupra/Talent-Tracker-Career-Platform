// Section 17.1 — UT-08: Grade validation rejects invalid inputs (grade
// 'Z' or blank field) -> validation error shown, data not saved.

import 'package:flutter_test/flutter_test.dart';
import 'package:talent_tracker_ai/services/validation/grade_validation.dart';

void main() {
  group('UT-08 — GradeValidation.isValidSubmission', () {
    test('accepts every grade in validGrades', () {
      // Spot-check a representative sample rather than every single value.
      expect(GradeValidation.isValidSubmission('A+'), isTrue);
      expect(GradeValidation.isValidSubmission('A'), isTrue);
      expect(GradeValidation.isValidSubmission('B+'), isTrue);
      expect(GradeValidation.isValidSubmission('F'), isTrue);
    });

    test('rejects an invalid grade letter ("Z")', () {
      expect(GradeValidation.isValidSubmission('Z'), isFalse);
    });

    test('rejects a blank field', () {
      expect(GradeValidation.isValidSubmission(''), isFalse);
    });
  });

  group('UT-08 — GradeValidation.validate (form validator)', () {
    test('null (nothing selected) returns an error message', () {
      expect(GradeValidation.validate(null), isNotNull);
    });

    test('blank string returns an error message', () {
      expect(GradeValidation.validate(''), isNotNull);
    });

    test('"Z" returns an error message', () {
      expect(GradeValidation.validate('Z'), isNotNull);
    });

    test('a valid grade returns null (no error)', () {
      expect(GradeValidation.validate('A+'), isNull);
      expect(GradeValidation.validate('D'), isNull);
    });
  });
}
