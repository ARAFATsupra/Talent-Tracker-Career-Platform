import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/jd_model.dart';

/// Data access for `jobDescriptions` (Section 9.4) — "All authenticated
/// users" can read (Section 9.5 access matrix).
class JDRepository {
  JDRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _jdRef =>
      _firestore.collection(FirestoreCollections.jobDescriptions);

  /// Live stream of every JD with `isActive == true` — the pool the AI
  /// Matching Engine (Phase 3) scores against for AI Job Match (S-11) and
  /// the Desired Role Selector (S-14).
  Stream<List<JDModel>> watchActiveJDs() {
    return _jdRef.where('isActive', isEqualTo: true).snapshots().map(
          (snap) => snap.docs.map((d) => JDModel.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Fetches a single JD by ID — used when deep-linking into the Job Role
  /// Detail screen (S-12) from a notification or saved roadmap.
  Future<JDModel?> getJD(String jdId) async {
    final snap = await _jdRef.doc(jdId).get();
    if (!snap.exists || snap.data() == null) return null;
    return JDModel.fromMap(snap.id, snap.data()!);
  }
}
