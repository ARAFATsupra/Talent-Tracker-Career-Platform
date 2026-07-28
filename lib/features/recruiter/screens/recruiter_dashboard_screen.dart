import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/placement_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/screens/common_app_bar_actions.dart';
import '../providers/recruiter_providers.dart';

/// S-18 — Recruiter Dashboard (redesigned).
class RecruiterDashboardScreen extends ConsumerWidget {
  const RecruiterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final placementsAsync = ref.watch(placementsProvider);
    final placementsThisMonth = ref.watch(placementsThisMonthProvider);

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
                        Color(0xFF4A148C),
                        Color(0xFF6A1B9A),
                        Color(0xFF8E24AA),
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
                                'Hello, ${user?.fullName.split(' ').first ?? 'Recruiter'} 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Find your next great hire',
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
              backgroundColor: const Color(0xFF6A1B9A),
              title: const Text(
                'Recruiter Dashboard',
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
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.groups_rounded,
                          label: 'Active in Pipeline',
                          value: '${placementsAsync.valueOrNull?.where((p) => p.status != PlacementStatus.rejected).length ?? 0}',
                          gradient: const [Color(0xFF1565C0), Color(0xFF0288D1)],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.celebration_rounded,
                          label: 'Placed This Month',
                          value: '$placementsThisMonth',
                          gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Find candidates - big CTA
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A1B9A).withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/recruiter/search'),
                        borderRadius: BorderRadius.circular(16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'FIND CANDIDATES',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick actions grid
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.view_kanban_rounded,
                          label: 'Pipeline',
                          color: const Color(0xFF1565C0),
                          onTap: () => context.push('/recruiter/pipeline'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.ios_share_rounded,
                          label: 'Export',
                          color: const Color(0xFF00897B),
                          onTap: () => context.push('/recruiter/export'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.history_rounded,
                          label: 'History',
                          color: const Color(0xFFE65100),
                          onTap: () => context.push('/recruiter/request-log'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Recent Shortlists',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  placementsAsync.when(
                    data: (placements) {
                      if (placements.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'No searches yet — try Find Candidates above.',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final recent = placements.take(5).toList();
                      return Column(
                        children: recent
                            .map((p) => _ShortlistTile(placement: p))
                            .toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Could not load recent shortlists: $e'),
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

// ── App bar icon button ───────────────────────────────────────────────
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
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Action tile ────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shortlist tile ─────────────────────────────────────────────────────
class _ShortlistTile extends StatelessWidget {
  const _ShortlistTile({required this.placement});

  final PlacementModel placement;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(placement.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/recruiter/profile/${placement.studentUid}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                  child: Text(
                    placement.studentName.isNotEmpty ? placement.studentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placement.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              placement.jobTitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              placement.status.label,
                              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${placement.matchPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(PlacementStatus status) {
    switch (status) {
      case PlacementStatus.placed:
        return const Color(0xFF00897B);
      case PlacementStatus.rejected:
        return const Color(0xFFD32F2F);
      case PlacementStatus.interviewScheduled:
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF1565C0);
    }
  }
}