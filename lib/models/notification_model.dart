import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: notifications/{uid}/items/{itemId} — written by Cloud
/// Functions (Section 14.1: onNewJDAdded, onStudentShortlisted's
/// grade-change notifier, onJDArchived) and by the Admin Portal's
/// Broadcast Notification screen (S-30, Phase 7).
///
/// Read by S-07 Notifications Screen — the one piece that was missing
/// to actually SEE everything those writers produce.
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'new_jd' | 'profile_update' | 'jd_archived' | 'broadcast'
  final String? targetScreen;
  final bool read;
  final DateTime? sentAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.targetScreen,
    this.read = false,
    this.sentAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      targetScreen: map['targetScreen'],
      read: map['read'] ?? false,
      sentAt: (map['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
