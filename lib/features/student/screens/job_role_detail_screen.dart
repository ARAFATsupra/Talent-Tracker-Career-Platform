import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_constants.dart';

import '../../../models/match_score_result.dart';
import '../../../services/ai/match_engine.dart';
import '../providers/student_providers.dart';
import '../../../services/ai/match_engine.dart';

/// S-12 — Job Role Detail Screen (redesigned).
class JobRoleDetailScreen extends ConsumerWidget {
  const JobRoleDetailScreen({super.key, required this.jdId});

  final String jdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jdsAsync = ref.watch(activeJDsProvider);
    final courses = ref.watch(allGradedCoursesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: jdsAsync.when(
        data: (jds) {
          final matches = jds.where((j) => j.jdId == jdId);
          if (matches.isEmpty) {
            return const Center(child: Text('This role is no longer available.'));
          }
          final jd = matches.first;
          final evaluation = MatchEngine.evaluateJD(studentCourses: courses, jd: jd);
          final score = evaluation.score;

          final missingSkills = evaluation.gaps
              .where((g) => g.type == GapType.missingSkill)
              .map((g) => g.skillName)
              .whereType<String>()
              .toSet();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 150,
                leading: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
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
                        padding: const EdgeInsets.fromLTRB(56, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              jd.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                jd.category,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                backgroundColor: const Color(0xFF1565C0),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _MatchSummaryCard(score: score),
                    const SizedBox(height: 20),

                    _SectionCard(
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF00695C),
                      title: 'Salary Range',
                      child: Text(
                        '৳ ${jd.salaryMinBDT} – ৳ ${jd.salaryMaxBDT} / month',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.checklist_rounded,
                      iconColor: const Color(0xFF6A1B9A),
                      title: 'Required Skills',
                      child: jd.requiredSkills.isEmpty
                          ? Text('No specific skills listed for this role.', style: TextStyle(color: Colors.grey[500]))
                          : Column(
                              children: jd.requiredSkills
                                  .map((skill) => _SkillRow(
                                        skill: skill,
                                        isMet: !missingSkills.contains(skill),
                                      ))
                                  .toList(),
                            ),
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.school_rounded,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Critical Courses',
                      child: score.breakdown.isEmpty
                          ? Text('No weighted courses configured for this role yet.', style: TextStyle(color: Colors.grey[500]))
                          : Column(
                              children: score.breakdown
                                  .map((c) => _CourseBreakdownRow(contribution: c))
                                  .toList(),
                            ),
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.link_rounded,
                      iconColor: const Color(0xFFE65100),
                      title: 'Original Job Posting',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (jd.sourceUrl.isEmpty)
                            Text('No source link provided.', style: TextStyle(color: Colors.grey[500]))
                          else
                            SelectableText(
                              jd.sourceUrl,
                              style: const TextStyle(color: Color(0xFF1565C0)),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

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
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            ref.read(selectedJdIdProvider.notifier).state = jd.jdId;
                            context.push('/student/roadmap');
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'View Skill Gap Roadmap',
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
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load this role: $e')),
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Match summary hero card ────────────────────────────────────────────
class _MatchSummaryCard extends StatelessWidget {
  const _MatchSummaryCard({required this.score});

  final MatchScoreResult score;

  @override
  Widget build(BuildContext context) {
    final confidenceText = switch (score.confidence) {
      MatchConfidence.empty => 'Enter your grades to see a real score.',
      MatchConfidence.partial =>
        'Based on the courses you\'ve taken so far — some critical courses are still missing.',
      MatchConfidence.full => 'All critical-path courses for this role have been taken.',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00695C).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${score.matchPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Text(
                'Match Score',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              confidenceText,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill row ──────────────────────────────────────────────────────────
class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill, required this.isMet});

  final String skill;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? const Color(0xFF00897B) : const Color(0xFFD32F2F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMet ? Icons.check_rounded : Icons.close_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              skill,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course breakdown row ───────────────────────────────────────────────
class _CourseBreakdownRow extends StatelessWidget {
  const _CourseBreakdownRow({required this.contribution});

  final CourseContribution contribution;

  @override
  Widget build(BuildContext context) {
    final taken = contribution.gradePoint > 0;
    final color = taken
        ? (contribution.gradePoint < minPassingGradePointForGap
            ? const Color(0xFFD32F2F)
            : const Color(0xFF00897B))
        : const Color(0xFFD32F2F);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            taken ? Icons.check_circle_outline : Icons.remove_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${contribution.courseCode} — ${contribution.courseName}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            taken ? 'GP ${contribution.gradePoint.toStringAsFixed(2)}' : 'Not taken',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'w=${contribution.weight.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}