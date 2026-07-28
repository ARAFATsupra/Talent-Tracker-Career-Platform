import 'package:cloud_firestore/cloud_firestore.dart';

import 'match_score_result.dart';

/// Firestore: matchResults/{uid} — written by Cloud Functions ONLY
/// (Section 9.5 access matrix). Represents one of the up to 3
/// AI-recommended roles for a student (FR-08, FR-09, FR-10).
///
/// 🔶 Phase 3: this is the output shape produced by the AI Matching
/// Engine's `MatchScore` formula (Section 12.2). [MatchEngine] itself
/// returns the richer [JDEvaluation] type — use [fromEvaluation] to
/// convert before writing to Firestore (Phase 5) or caching offline
/// (Hive, FR-31).
class MatchResultModel {
  final String jdId;
  final String jobTitle;
  final double matchPercentage; // 0-100, Section 12.2 formula
  final List<String> missingSkills; // FR-10
  final List<String> missingCourses; // critical-path courses not taken / failed
  final String confidenceFlag; // 'full' | 'partial' | 'empty' — Glossary, FR-31/FR-32
  final DateTime? computedAt;

  const MatchResultModel({
    required this.jdId,
    required this.jobTitle,
    required this.matchPercentage,
    this.missingSkills = const [],
    this.missingCourses = const [],
    this.confidenceFlag = 'full',
    this.computedAt,
  });

  /// Builds a [MatchResultModel] from [MatchEngine.evaluateJD]'s output.
  /// [MatchConfidence.name] ('full' | 'partial' | 'empty') matches the
  /// `confidenceFlag` strings from the Glossary / FR-31 / FR-32 exactly.
  factory MatchResultModel.fromEvaluation(JDEvaluation evaluation) {
    final gaps = evaluation.gaps;
    return MatchResultModel(
      jdId: evaluation.score.jdId,
      jobTitle: evaluation.score.jobTitle,
      matchPercentage: evaluation.score.matchPercentage,
      missingCourses: gaps
          .where((g) => g.type != GapType.missingSkill && g.courseCode != null)
          .map((g) => g.courseCode!)
          .toList(),
      missingSkills: gaps
          .where((g) => g.type == GapType.missingSkill && g.skillName != null)
          .map((g) => g.skillName!)
          .toList(),
      confidenceFlag: evaluation.score.confidence.name,
      computedAt: DateTime.now(),
    );
  }

  factory MatchResultModel.fromMap(Map<String, dynamic> map) {
    return MatchResultModel(
      jdId: map['jdId'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      matchPercentage: (map['matchPercentage'] ?? 0.0).toDouble(),
      missingSkills: List<String>.from(map['missingSkills'] ?? []),
      missingCourses: List<String>.from(map['missingCourses'] ?? []),
      confidenceFlag: map['confidenceFlag'] ?? 'full',
      computedAt: (map['computedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jdId': jdId,
      'jobTitle': jobTitle,
      'matchPercentage': matchPercentage,
      'missingSkills': missingSkills,
      'missingCourses': missingCourses,
      'confidenceFlag': confidenceFlag,
      'computedAt': FieldValue.serverTimestamp(),
    };
  }
}
