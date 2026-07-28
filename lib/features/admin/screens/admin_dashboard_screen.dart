import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/screens/common_app_bar_actions.dart';
import '../providers/admin_providers.dart';

/// S-25 — Admin Dashboard (redesigned).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final counts = ref.watch(userCountsByRoleProvider);
    final topRoles = ref.watch(topRolesByJdCategoryProvider);
    final totalUsers = counts.values.fold<int>(0, (a, b) => a + b);
    final errorCount = ref.watch(unresolvedErrorCountProvider);
    final placementsThisMonth = ref.watch(adminPlacementsThisMonthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: userAsync.when(
        data: (user) => CustomScrollView(
          slivers: [
            // ── Gradient App Bar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF004D40),
                        Color(0xFF00695C),
                        Color(0xFF00897B),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${user?.fullName.split(' ').first ?? 'Admin'} 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'System overview & control',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _AppBarIcon(
                                icon: Icons.person_outline,
                                onTap: () => context.push('/profile'),
                              ),
                              const SizedBox(width: 8),
                              _AppBarIcon(
                                icon: Icons.notifications_none,
                                onTap: () => context.push('/notifications'),
                              ),
                              const SizedBox(width: 8),
                              _AppBarIcon(
                                icon: Icons.logout,
                                onTap: () => ref.read(authControllerProvider.notifier).signOut(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              backgroundColor: const Color(0xFF00695C),
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            // ── Body content ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats grid - 2x3
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _StatCard(
                        icon: Icons.people_rounded,
                        label: 'Total Users',
                        value: '$totalUsers',
                        gradient: const [Color(0xFF1565C0), Color(0xFF0288D1)],
                      ),
                      _StatCard(
                        icon: Icons.school_rounded,
                        label: 'Students',
                        value: '${counts[UserRole.student] ?? 0}',
                        gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                      ),
                      _StatCard(
                        icon: Icons.business_center_rounded,
                        label: 'Recruiters',
                        value: '${counts[UserRole.recruiter] ?? 0}',
                        gradient: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                      ),
                      _StatCard(
                        icon: Icons.error_rounded,
                        label: 'Unresolved Errors',
                        value: '$errorCount',
                        gradient: const [Color(0xFFC62828), Color(0xFFD32F2F)],
                        onTap: () => context.push('/admin/error-log'),
                      ),
                      _StatCard(
                        icon: Icons.celebration_rounded,
                        label: 'Placed This Month',
                        value: '$placementsThisMonth',
                        gradient: const [Color(0xFFE65100), Color(0xFFFF8F00)],
                        onTap: () => context.push('/admin/analytics'),
                      ),
                      _StatCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Course Master',
                        value: 'Manage',
                        gradient: const [Color(0xFF00838F), Color(0xFF00ACC1)],
                        onTap: () => context.push('/admin/courses'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Top roles chart
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF00897B)),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Top Roles by Active JDs',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (topRoles.isEmpty)
                          Text(
                            'No active job descriptions yet.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          )
                        else
                          for (final entry in topRoles) _TopRoleBar(category: entry.key, count: entry.value, maxCount: topRoles.first.value),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Quick Links',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _QuickLinkTile(
                    icon: Icons.manage_accounts_rounded,
                    label: 'User Management',
                    color: const Color(0xFF1565C0),
                    onTap: () => context.push('/admin/users'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.work_rounded,
                    label: 'JD Library',
                    color: const Color(0xFF6A1B9A),
                    onTap: () => context.push('/admin/jds'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.menu_book_rounded,
                    label: 'Course Master',
                    color: const Color(0xFF00838F),
                    onTap: () => context.push('/admin/courses'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.campaign_rounded,
                    label: 'Broadcast Notification',
                    color: const Color(0xFFE65100),
                    onTap: () => context.push('/admin/broadcast'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.bug_report_rounded,
                    label: 'System Error Log',
                    color: const Color(0xFFD32F2F),
                    onTap: () => context.push('/admin/error-log'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.archive_rounded,
                    label: 'Data Export & Archive',
                    color: const Color(0xFF5D4037),
                    onTap: () => context.push('/admin/export-archive'),
                  ),
                  _QuickLinkTile(
                    icon: Icons.show_chart_rounded,
                    label: 'Monthly Analytics',
                    color: const Color(0xFF00695C),
                    onTap: () => context.push('/admin/analytics'),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── App bar icon ───────────────────────────────────────────────────────
class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top role bar chart row ─────────────────────────────────────────────
class _TopRoleBar extends StatelessWidget {
  const _TopRoleBar({required this.category, required this.count, required this.maxCount});

  final String category;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick link tile ────────────────────────────────────────────────────
class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 12, 2, 2),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 141, 144, 58).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}