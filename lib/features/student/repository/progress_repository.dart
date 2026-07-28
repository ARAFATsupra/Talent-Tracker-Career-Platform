import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';

/// Data access for `users/{uid}/roadmapProgress` — backs the Progress
/// Tracker (S-17, FR-38: "mark certifications as done and watch match
/// score rise").
///
/// 🔶 This sub-collection isn't in Section 9's schema tables (9.2-9.5) —
/// FR-38 is listed as "Should Have" and Section 5.2 describes the SCREEN
/// (S-17: "Checklist per skill gap, completion % bar, Mark Done toggle,
/// updated match score after each completion") without a corresponding
/// Firestore schema entry. This collection is added to make that screen
/// functional; see PHASE7_GUIDE.md for the full note, including the
/// `firestore.rules` addition this needed.
///
/// Each document is keyed by [SkillGap.gapKey] (e.g.
/// `notTaken:CSE-402`) so completion survives the gap being recomputed
/// fresh on every [MatchEngine] run — the same gap key always maps to
/// the same "done" flag, regardless of which JD it currently appears
/// under (a course gap closed for one role's roadmap is closed for all
/// of them, since it's the SAME underlying course).
class ProgressRepository {
  ProgressRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _progressRef(String uid) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.roadmapProgress);

  /// Live stream of every gap key this student has marked done, e.g.
  /// `{'notTaken:CSE-402', 'lowGrade:MGT-210'}`.
  Stream<Set<String>> watchCompletedGapKeys(String uid) {
    return _progressRef(uid).where('done', isEqualTo: true).snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toSet(),
        );
  }

  /// FR-38 — toggle one gap's completion state.
  Future<void> setGapDone(String uid, String gapKey, bool done) {
    return _progressRef(uid).doc(gapKey).set({
      'done': done,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
