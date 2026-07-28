import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/notification_model.dart';

/// Data access for S-07 — Notifications Screen, shared across all 3
/// roles (Section 5.1: "Common Screens — All User Roles").
///
/// Reads/writes notifications/{uid}/items/{itemId} — the same path
/// Cloud Functions (Phase 6: onNewJDAdded, the grade-change notifier,
/// onJDArchived) and the Admin Portal's Broadcast Notification screen
/// (Phase 7, S-30) already write to.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid) {
    return _firestore.collection(FirestoreCollections.notifications).doc(uid).collection('items');
  }

  /// Live stream of this user's notifications, newest first.
  Stream<List<NotificationModel>> watchNotifications(String uid) {
    return _itemsRef(uid)
        .orderBy('sentAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> markRead(String uid, String notificationId) {
    return _itemsRef(uid).doc(notificationId).update({'read': true});
  }

  /// S-07's "Clear All button" — Section 7's UI text says "Clear All,"
  /// which usually means "dismiss everything" rather than "delete
  /// everything." This marks every notification read (recoverable —
  /// nothing is destroyed) rather than hard-deleting the documents,
  /// since Cloud Functions / Admin broadcasts that already fired
  /// shouldn't become permanently unrecoverable from a single tap. If
  /// "Clear All" should mean true deletion instead, swap this batch's
  /// `update` for `delete` — the batching logic stays the same either
  /// way.
  Future<void> markAllRead(String uid) async {
    final snap = await _itemsRef(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
