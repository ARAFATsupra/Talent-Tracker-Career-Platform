import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_constants.dart';
import '../../../models/notification_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/notification_providers.dart';

/// S-07 — Notifications Screen.
/// "Notification list with icon, title, body, timestamp; read/unread
/// dot; Clear All button."
///
/// Shared across all 3 roles (Section 5.1). Surfaces everything Cloud
/// Functions (Phase 6) and the Admin's Broadcast Notification screen
/// (Phase 7, S-30) write to notifications/{uid}/items — this was the one
/// missing piece that made those writers' output invisible.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: uid == null ? null : () => ref.read(notificationRepositoryProvider).markAllRead(uid),
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _NotificationTile(notification: notifications[index], uid: uid!),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notifications: $e')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.uid});

  final NotificationModel notification;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: _iconColor.withOpacity(0.12),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          if (!notification.read)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: notification.read ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 2),
          Text(
            notification.sentAt != null ? DateFormat('MMM d, h:mm a').format(notification.sentAt!) : '',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        if (!notification.read) {
          ref.read(notificationRepositoryProvider).markRead(uid, notification.id);
        }
        _navigateToTarget(context);
      },
    );
  }

  IconData get _icon {
    switch (notification.type) {
      case 'new_jd':
        return Icons.work_outline;
      case 'profile_update':
        return Icons.person_outline;
      case 'jd_archived':
        return Icons.archive_outlined;
      case 'broadcast':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case 'new_jd':
        return AppColors.successGreen;
      case 'profile_update':
        return AppColors.secondaryTeal;
      case 'jd_archived':
        return AppColors.warningAmber;
      case 'broadcast':
        return AppColors.primaryBlue;
      default:
        return AppColors.textSecondary;
    }
  }

  /// "targetScreen" was written by Cloud Functions (Section 14.2's
  /// payload examples: jobRoleDetail, studentProfileView, aiJobMatch) —
  /// maps those logical names to this app's actual routes. Falls back to
  /// doing nothing for types with no natural single destination (e.g. a
  /// broadcast aimed at "All").
  void _navigateToTarget(BuildContext context) {
    switch (notification.targetScreen) {
      case 'aiJobMatch':
        context.push('/student/matches');
      case 'studentProfileView':
        // 🔶 Recruiter-only target — the studentUid would need to be on
        // the notification payload to deep-link to a specific profile;
        // Cloud Functions (Phase 6) currently include it as a top-level
        // field but NotificationModel doesn't surface arbitrary extra
        // fields yet. Falls through to the Pipeline Board as the
        // closest reachable screen instead of a broken deep link.
        context.push('/recruiter/pipeline');
      default:
        break;
    }
  }
}
