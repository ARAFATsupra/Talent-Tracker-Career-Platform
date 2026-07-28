import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../providers/notification_providers.dart';

/// S-07's "notification bell badge" — a single reusable AppBar action
/// used by all 3 dashboards (S-08, S-18, S-25) instead of duplicating
/// the same badge-counting logic 3 times.
class NotificationBellAction extends ConsumerWidget {
  const NotificationBellAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        backgroundColor: AppColors.errorRed,
        child: const Icon(Icons.notifications_none),
      ),
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
    );
  }
}

/// S-06's entry point — a profile/settings icon for the AppBar, also
/// shared across all 3 dashboards.
class ProfileSettingsAction extends StatelessWidget {
  const ProfileSettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_outline),
      tooltip: 'Profile Settings',
      onPressed: () => context.push('/profile'),
    );
  }
}
