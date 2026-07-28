import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../models/match_score_result.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/screens/common_app_bar_actions.dart';
import '../providers/student_providers.dart';

/// S-08 — Student Dashboard (redesigned).
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final top3 = ref.watch(top3EvaluationsProvider);
    final roadmap = ref.watch(roadmapEntriesProvider);
    final courses = ref.watch(allGradedCoursesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: userAsync.when(
        data: (user) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(semestersProvider),
          child: CustomScrollView(
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
                          Color(0xFF1A237E),
                          Color(0xFF1565C0),
                          Color(0xFF0288D1),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${user?.fullName.split(' ').first ?? 'Student'} 👋',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Track your career journey',
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
                                    const _NotificationIcon(),
                                    const SizedBox(width: 8),
                                    _AppBarIcon(
                                      icon: Icons.logout,
                                      onTap: () => ref
                                          .read(authControllerProvider.notifier)
                                          .signOut(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                backgroundColor: const Color(0xFF1565C0),
                title: const Text(
                  'Student Dashboard',
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
                    // CGPA + Quick Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'CGPA',
                            value: (user?.cgpa ?? 0.0).toStringAsFixed(2),
                            icon: Icons.school_rounded,
                            gradient: const [Color(0xFF1565C0), Color(0xFF0288D1)],
                            onTap: () => context.push('/student/grades-summary'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Top Match',
                            value: top3.isNotEmpty
                                ? '${top3.first.score.matchPercentage.toStringAsFixed(0)}%'
                                : '--',
                            icon: Icons.psychology_rounded,
                            gradient: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                            onTap: () => context.push('/student/matches'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Courses',
                            value: '${courses.length}',
                            icon: Icons.menu_book_rounded,
                            gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                            onTap: () => context.push('/student/grades'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Top Matched Role card
                    _TopMatchBanner(
                      topEvaluation: top3.isNotEmpty ? top3.first : null,
                      hasAnyGrades: courses.isNotEmpty,
                    ),

                    const SizedBox(height: 16),

                    // Roadmap card
                    _RoadmapCard(roadmap: roadmap),

                    const SizedBox(height: 20),

                    // Quick Add Grade button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push('/student/grades'),
                          borderRadius: BorderRadius.circular(14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Quick-Add Grade',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick links grid
                    const _QuickLinksGrid(),

                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
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

// ── Notification icon with badge ──────────────────────────────────────
class _NotificationIcon extends ConsumerWidget {
  const _NotificationIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.notifications_none,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// ── Mini stat card (top row) ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

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
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.85), size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top match banner ──────────────────────────────────────────────────
class _TopMatchBanner extends StatelessWidget {
  const _TopMatchBanner({
    required this.topEvaluation,
    required this.hasAnyGrades,
  });

  final JDEvaluation? topEvaluation;
  final bool hasAnyGrades;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/student/matches'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.work_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Matched Role',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!hasAnyGrades)
                    const Text(
                      'Enter grades to see AI job matches',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else if (topEvaluation == null)
                    const Text(
                      'No job roles in the library yet',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else ...[
                    Text(
                      topEvaluation!.score.jobTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A1B9A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${topEvaluation!.score.matchPercentage.toStringAsFixed(1)}% match',
                            style: const TextStyle(
                              color: Color(0xFF6A1B9A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Roadmap card ──────────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.roadmap});

  final List<RoadmapEntry> roadmap;

  @override
  Widget build(BuildContext context) {
    final total = roadmap.length;

    return GestureDetector(
      onTap: () => context.push('/student/roadmap'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF57F17), Color(0xFFFF8F00)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skill Gap Roadmap',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'No open skill gaps 🎉'
                        : '$total item${total == 1 ? '' : 's'} on your roadmap',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF8F00),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick links grid ──────────────────────────────────────────────────
class _QuickLinksGrid extends StatelessWidget {
  const _QuickLinksGrid();

  static const _links = [
    (Icons.bar_chart_rounded, 'Grades', '/student/grades-summary', Color(0xFF1565C0)),
    (Icons.travel_explore_rounded, 'Browse Roles', '/student/roles', Color(0xFF6A1B9A)),
    (Icons.workspace_premium_rounded, 'Certifications', '/student/certifications', Color(0xFF00695C)),
    (Icons.feedback_rounded, 'Feedback', '/student/feedback', Color(0xFFE65100)),
    (Icons.trending_up_rounded, 'Progress', '/student/progress', Color(0xFFC62828)),
    (Icons.picture_as_pdf_rounded, 'Export PDF', '/student/roadmap/export', Color(0xFF00838F)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: _links.map((link) {
            final (icon, label, route, color) = link;
            return GestureDetector(
              onTap: () => context.push(route),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}