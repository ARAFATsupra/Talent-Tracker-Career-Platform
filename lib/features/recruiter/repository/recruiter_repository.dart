import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/placement_model.dart';
import '../../../models/semester_model.dart';
import '../../../models/user_model.dart';

/// One student's full profile + grades, as needed by [MatchEngine] for the
/// recruiter scan (Section 12.6) — bundles [UserModel] (for name/CGPA) with
/// every graded course across their semesters.
class StudentScanRecord {
  final UserModel user;
  final List<SemesterModel> semesters;

  const StudentScanRecord({required this.user, required this.semesters});
}

/// Data access for the Recruiter Portal (Section 5.3):
///  - FR-15/FR-16/FR-21 — scanning active students (filtered by
///    department/batch/CGPA) for the AI candidate match (S-19/S-20).
///  - FR-17 — reading a single student's profile, with private fields
///    excluded (S-21, "without showing sensitive private data").
///  - FR-20/FR-40 — the `placements` pipeline (S-22).
class RecruiterRepository {
  RecruiterRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get _placementsRef =>
      _firestore.collection(FirestoreCollections.placements);

  /// FR-15/FR-16/FR-21 — fetches every ACTIVE student (`role == 'student'`,
  /// `isActive == true`), optionally filtered by department/batch/min CGPA
  /// (FR-21), each bundled with their full semester history so
  /// [MatchEngine.rankForRecruiterScan] (Section 12.6) can score them.
  ///
  /// 🔶 IDX-01 (`role ASC, isActive ASC, cgpa DESC`) covers the base query.
  /// `department`/`batch` are applied as additional equality filters,
  /// which Firestore can usually satisfy without a new composite index
  /// when combined with an equality-only prefix; if Firestore's console
  /// prompts for one when you actually run this, follow the link it
  /// gives you — that's the intended workflow for composite indexes.
  Future<List<StudentScanRecord>> fetchActiveStudentsForScan({
    String? department,
    String? batch,
    double? minCgpa,
  }) async {
    Query<Map<String, dynamic>> query = _usersRef
        .where('role', isEqualTo: 'student')
        .where('isActive', isEqualTo: true);

    if (department != null && department.isNotEmpty) {
      query = query.where('department', isEqualTo: department);
    }
    if (batch != null && batch.isNotEmpty) {
      query = query.where('batch', isEqualTo: batch);
    }

    final snap = await query.get();
    final users = snap.docs
        .map((d) => UserModel.fromMap(d.id, d.data()))
        .where((u) => minCgpa == null || u.cgpa >= minCgpa)
        .toList();

    // Fetch each student's semesters in parallel.
    final records = await Future.wait(users.map((user) async {
      final semSnap = await _usersRef.doc(user.uid).collection(FirestoreCollections.semesters).get();
      final semesters = semSnap.docs.map((d) => SemesterModel.fromMap(d.data())).toList();
      return StudentScanRecord(user: user, semesters: semesters);
    }));

    return records;
  }

  /// S-21 — Student Profile View (Recruiter). Per FR-17/Section 5.3:
  /// "without showing sensitive private data" — this reuses [UserModel]
  /// since it has no field more sensitive than `cgpa`/`email`/`studentId`
  /// already shown elsewhere in the spec's recruiter screens (S-20 shows
  /// student ID + CGPA in the shortlist itself). 🔶 If "sensitive" later
  /// comes to mean hiding email/studentId specifically, add a
  /// `toPublicMap()` on UserModel that omits them — kept simple for now
  /// since Section 9.4/9.5 doesn't define exactly which fields qualify.
  Future<StudentScanRecord?> fetchStudentForProfileView(String uid) async {
    final userSnap = await _usersRef.doc(uid).get();
    if (!userSnap.exists || userSnap.data() == null) return null;
    final user = UserModel.fromMap(uid, userSnap.data()!);

    final semSnap = await _usersRef.doc(uid).collection(FirestoreCollections.semesters).get();
    final semesters = semSnap.docs.map((d) => SemesterModel.fromMap(d.data())).toList();

    return StudentScanRecord(user: user, semesters: semesters);
  }

  // ------------------------------------------------------------------
  // Placements (S-22 Pipeline Board, FR-20/FR-40)
  // ------------------------------------------------------------------

  /// Live stream of every placement record THIS recruiter created,
  /// newest search first — IDX-02 (`recruiterUid ASC, status ASC,
  /// searchedAt DESC`) covers this when a `status` filter is added; the
  /// unfiltered "all my placements" query below only needs
  /// `recruiterUid ASC, searchedAt DESC`, a subset Firestore can usually
  /// serve from the same composite index.
  Stream<List<PlacementModel>> watchPlacements(String recruiterUid) {
    return _placementsRef
        .where('recruiterUid', isEqualTo: recruiterUid)
        .orderBy('searchedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PlacementModel.fromMap(d.id, d.data())).toList());
  }

  /// FR-15/FR-20 — adds a student to the pipeline as "Shortlisted" right
  /// after a scan (S-19 → S-20 → "Shortlist" action), recording the
  /// match % at the time of the search. If this student is already in
  /// THIS recruiter's pipeline for the same job title, does nothing
  /// (avoids duplicate Kanban cards from re-running the same search).
  Future<void> shortlistStudent({
    required String recruiterUid,
    required String studentUid,
    required String studentName,
    required String jobTitle,
    required double matchPercentage,
  }) async {
    final existing = await _placementsRef
        .where('recruiterUid', isEqualTo: recruiterUid)
        .where('studentUid', isEqualTo: studentUid)
        .where('jobTitle', isEqualTo: jobTitle)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final placement = PlacementModel(
      id: '', // Firestore assigns the ID on add()
      recruiterUid: recruiterUid,
      studentUid: studentUid,
      studentName: studentName,
      jobTitle: jobTitle,
      matchPercentage: matchPercentage,
      searchedAt: DateTime.now(),
    );
    await _placementsRef.add(placement.toMap());
  }

  /// FR-20 — moves a candidate to a new pipeline stage (Pipeline Board,
  /// S-22 — drag between Kanban columns).
  Future<void> updateStatus(String placementId, PlacementStatus status) {
    return _placementsRef.doc(placementId).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// FR-40 — private recruiter notes on a candidate's pipeline card.
  Future<void> updateNotes(String placementId, String notes) {
    return _placementsRef.doc(placementId).update({'notes': notes, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
