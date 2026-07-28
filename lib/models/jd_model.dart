import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: jobDescriptions/{jdId} — Section 9.4.
/// The library of job descriptions used by the AI matching engine.
class JDModel {
  final String jdId;
  final String title;
  final String category;
  final List<String> requiredSkills;
  final List<String> criticalPathCourses; // course codes — Section 12.2
  final Map<String, double> courseWeights; // courseCode -> weight 0.0..1.0
  final int salaryMinBDT;
  final int salaryMaxBDT;
  final String sourceUrl;
  final List<String> certifications; // general pool of remediations (Section 9.4)
  /// 🔶 EXTENSION beyond Section 9.4's documented fields. Section 12.4 says
  /// "Each gap is mapped to a recommended remediation ... pre-loaded in the
  /// JD library by the admin", but Section 9.4's field table has no field
  /// for this mapping — only the flat `certifications` list above. This
  /// map lets the admin (Phase 5, S29 AI Weighting Config) optionally
  /// target a remediation at a specific course code or skill name; when a
  /// gap has no entry here, [MatchEngine] falls back to a generic message
  /// built from [certifications].
  final Map<String, String> remediations; // courseCode|skillName -> remediation text
  final bool isActive; // FR-46 — archived JDs set this to false
  final String addedBy; // Admin UID
  final DateTime? createdAt;

  const JDModel({
    required this.jdId,
    required this.title,
    required this.category,
    this.requiredSkills = const [],
    this.criticalPathCourses = const [],
    this.courseWeights = const {},
    this.salaryMinBDT = 0,
    this.salaryMaxBDT = 0,
    this.sourceUrl = '',
    this.certifications = const [],
    this.remediations = const {},
    this.isActive = true,
    this.addedBy = '',
    this.createdAt,
  });

  factory JDModel.fromMap(String jdId, Map<String, dynamic> map) {
    final salary = Map<String, dynamic>.from(map['salaryRangeBDT'] ?? {});
    final rawWeights = Map<String, dynamic>.from(map['courseWeights'] ?? {});
    final rawRemediations = Map<String, dynamic>.from(map['remediations'] ?? {});

    return JDModel(
      jdId: jdId,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
      criticalPathCourses: List<String>.from(map['criticalPathCourses'] ?? []),
      courseWeights: rawWeights.map((k, v) => MapEntry(k, (v as num).toDouble())),
      salaryMinBDT: salary['min'] ?? 0,
      salaryMaxBDT: salary['max'] ?? 0,
      sourceUrl: map['sourceUrl'] ?? '',
      certifications: List<String>.from(map['certifications'] ?? []),
      remediations: rawRemediations.map((k, v) => MapEntry(k, v.toString())),
      isActive: map['isActive'] ?? true,
      addedBy: map['addedBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'requiredSkills': requiredSkills,
      'criticalPathCourses': criticalPathCourses,
      'courseWeights': courseWeights,
      'salaryRangeBDT': {'min': salaryMinBDT, 'max': salaryMaxBDT},
      'sourceUrl': sourceUrl,
      'certifications': certifications,
      'remediations': remediations,
      'isActive': isActive,
      'addedBy': addedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
