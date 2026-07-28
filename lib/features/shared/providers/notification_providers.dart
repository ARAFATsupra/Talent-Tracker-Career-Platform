import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../repository/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository());

/// S-07 — live stream of the signed-in user's notifications, regardless
/// of role (Section 5.1: "Common Screens — All User Roles").
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchNotifications(uid);
});

/// "Read/unread dot" badge count — used by every dashboard's bell icon
/// (Phase 4/5's Icons.notifications_none action buttons) to show how
/// many are unread, same pattern as unresolvedErrorCountProvider (Phase
/// 7) for the Admin's error badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.read).length;
});
