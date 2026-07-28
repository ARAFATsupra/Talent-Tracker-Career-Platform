import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/semester_model.dart';

/// Data access for `users/{uid}/semesters` (Section 9.3) and the `cgpa`
/// field on `users/{uid}` (Section 9.2).
///
/// Implements:
///  - FR-06 — enter course name/code/credits/grade per semester
///  - FR-07 — auto-calculate semester GPA and overall CGPA
///  - FR-13 — save/update grades at any time before the final semester
///    is marked complete
class GradeRepository {
  GradeRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _semestersRef(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid).collection(FirestoreCollections.semesters);

  /// Firestore document ID for a given semester number (1..8) — a fixed,
  /// predictable ID lets the UI always show 8 tabs (S-09) even before
  /// any data has been saved for that semester.
  static String docIdFor(int semesterNumber) => 'sem_$semesterNumber';

  /// Live stream of all semesters the student has saved so far, ordered
  /// by semester number. Semesters with no saved document are NOT
  /// included — the UI (Grade Entry, S-09) fills in the gaps with empty
  /// [SemesterModel]s for semesters 1..[totalSemesters].
  Stream<List<SemesterModel>> watchSemesters(String uid) {
    return _semestersRef(uid).orderBy('semesterNumber').snapshots().map(
          (snap) => snap.docs.map((d) => SemesterModel.fromMap(d.data())).toList(),
        );
  }

  /// FR-07 — recalculates this semester's GPA before saving (so
  /// `semesterGPA` in Firestore always matches `courses`), then writes
  /// `users/{uid}/semesters/sem_{N}`.
  Future<void> saveSemester(String uid, SemesterModel semester) async {
    final withGpa = SemesterModel(
      semesterNumber: semester.semesterNumber,
      semesterName: semester.semesterName,
      isComplete: semester.isComplete,
      semesterGPA: SemesterModel.calculateGPA(semester.courses),
      courses: semester.courses,
    );

    await _semestersRef(uid).doc(docIdFor(semester.semesterNumber)).set(withGpa.toMap());
    await _recalculateCGPA(uid);
  }

  /// FR-07 — "Calculated CGPA — updated automatically every time grades
  /// change" (Section 9.2). Reads every saved semester back, recomputes
  /// the CGPA across all of them, and writes it to `users/{uid}.cgpa`.
  Future<void> _recalculateCGPA(String uid) async {
    final snap = await _semestersRef(uid).get();
    final semesters = snap.docs.map((d) => SemesterModel.fromMap(d.data())).toList();
    final cgpa = SemesterModel.calculateCGPA(semesters);

    await _firestore.collection(FirestoreCollections.users).doc(uid).update({'cgpa': cgpa});
  }
}
