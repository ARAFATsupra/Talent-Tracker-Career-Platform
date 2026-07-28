import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/jd_model.dart';
import '../../../models/match_score_result.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// S-15 — Certification Library Screen (redesigned).
class CertificationLibraryScreen extends ConsumerWidget {
  const CertificationLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(roadmapJdEvaluationProvider);
    final completedKeys = ref.watch(completedGapKeysProvider).valueOrNull ?? const {};
    final jds = ref.watch(activeJDsProvider).valueOrNull ?? const [];
    final jd = evaluation == null ? null : _findJD(jds, evaluation.score.jdId);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
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
                      Color(0xFF00695C),
                      Color(0xFF00897B),
                      Color(0xFF26A69A),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF00695C),
            title: const Text(
              'Certification Library',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (evaluation == null || jd == null)
            const SliverFillRemaining(
              child: _EmptyState(
                message: 'No job role selected yet — pick one from Desired Role Selector.',
              ),
            )
          else if (jd.certifications.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                message: 'No certifications are listed yet for "${evaluation.score.jobTitle}".',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF00897B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recommended for ${evaluation.score.jobTitle}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00695C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final cert in jd.certifications)
                    _CertificationCard(
                      name: cert,
                      matchingGap: _findMatchingGap(cert, evaluation.gaps),
                      completedKeys: completedKeys,
                    ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  SkillGap? _findMatchingGap(String certName, List<SkillGap> gaps) {
    for (final gap in gaps) {
      if (gap.remediation.toLowerCase().contains(certName.toLowerCase())) return gap;
    }
    return null;
  }

  JDModel? _findJD(List<JDModel> jds, String jdId) {
    for (final jd in jds) {
      if (jd.jdId == jdId) return jd;
    }
    return null;
  }
}

// ── Certification card ────────────────────────────────────────────────
class _CertificationCard extends ConsumerWidget {
  const _CertificationCard({
    required this.name,
    required this.matchingGap,
    required this.completedKeys,
  });

  final String name;
  final SkillGap? matchingGap;
  final Set<String> completedKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdded = matchingGap != null && completedKeys.contains(matchingGap!.gapKey);
    final hasLink = matchingGap != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAdded
                      ? [const Color(0xFF00897B), const Color(0xFF00695C)]
                      : [const Color(0xFFFFA000), const Color(0xFFFF8F00)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isAdded ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_outlined, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Provider not specified',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.schedule_outlined, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Duration N/A',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  if (matchingGap != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Closes gap: ${matchingGap!.label}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF00695C), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Tooltip(
                    message: matchingGap == null
                        ? 'No specific skill gap linked to this certification yet'
                        : (isAdded ? 'Already on your roadmap' : 'Mark as in progress on your roadmap'),
                    child: SizedBox(
                      width: double.infinity,
                      child: hasLink && !isAdded
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00897B), Color(0xFF00695C)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _addToRoadmap(ref),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                label: const Text(
                                  'Add to Roadmap',
                                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isAdded ? const Color(0xFF00897B) : Colors.grey[400],
                                side: BorderSide(
                                  color: isAdded
                                      ? const Color(0xFF00897B).withOpacity(0.4)
                                      : Colors.grey[300]!,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(
                                isAdded ? Icons.check_circle_outline : Icons.link_off_rounded,
                                size: 16,
                              ),
                              label: Text(
                                isAdded ? 'Added ✓' : 'Not linked',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToRoadmap(WidgetRef ref) async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null || matchingGap == null) return;
    await ref.read(progressRepositoryProvider).setGapDone(uid, matchingGap!.gapKey, true);
  }
}

// ── Empty state ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 44, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}