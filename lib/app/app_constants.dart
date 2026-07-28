import 'package:flutter/material.dart';

/// Section 7.1 — Colour Palette
class AppColors {
  static const primaryBlue = Color(0xFF1565C0);
  static const secondaryTeal = Color(0xFF00796B);
  static const successGreen = Color(0xFF2E7D32);
  static const warningAmber = Color(0xFFE65100);
  static const errorRed = Color(0xFFB71C1C);

  static const backgroundLight = Color(0xFFF5F7FA);
  static const backgroundDark = Color(0xFF121212);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1E1E1E);

  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

/// Firestore collection names — Section 9.1
class FirestoreCollections {
  static const users = 'users';
  static const semesters = 'semesters'; // sub-collection: users/{uid}/semesters
  static const jobDescriptions = 'jobDescriptions';
  static const courses = 'courses';
  static const matchResults = 'matchResults';
  static const placements = 'placements';
  static const notifications = 'notifications';
  static const systemLogs = 'systemLogs';
  static const auditLogs = 'auditLogs';
  static const feedback = 'feedback';
  /// sub-collection: users/{uid}/roadmapProgress — S-17 Progress Tracker
  /// (FR-38, "Should Have"). 🔶 Not in Section 9's schema tables (added
  /// this phase to back S-17); see PHASE7_GUIDE.md.
  static const roadmapProgress = 'roadmapProgress';
}

/// Valid letter grades shown in the grade dropdown — Section 7.3
const List<String> validGrades = [
  'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D', 'F',
];

/// Letter grade -> grade point on the 4.0 scale.
///
/// NOTE: A+, A, B+, B, C+, C, D, F values below are taken directly from
/// the worked example in Section 12.3 and cross-checked against every
/// demo student profile in Section 10 — all consistent.
///
/// A- and B- are part of the grade dropdown (Section 7.3) but are never
/// used in any worked example or demo profile. The values here are
/// interpolated placeholders.
/// 🔶 TODO: confirm the official DIU grading scale for A- / B- before this
/// feeds real GPA calculations (FR-07).
const Map<String, double> gradePoints = {
  'A+': 4.00,
  'A': 3.75,
  'A-': 3.625, // 🔶 placeholder — confirm with faculty advisor
  'B+': 3.50,
  'B': 3.25,
  'B-': 2.875, // 🔶 placeholder — confirm with faculty advisor
  'C+': 2.50,
  'C': 2.25,
  'D': 1.00,
  'F': 0.00,
};

/// Section 4 (NFR) / Section 3.1 (FR-36) constants
const int maxFailedLoginAttempts = 5; // FR-36
const int accountLockDurationMinutes = 30; // FR-36
const int totalSemesters = 8; // FR-06, FR-09 (Sem 1 to Sem 8)

/// Section 12.4 — a critical-path course grade below this counts as a gap
const double minPassingGradePointForGap = 2.0; // grade point below 2.0 = C or lower

/// Section 12.6 — courses with weight below this are excluded from
/// the recruiter scan so unrelated low marks don't penalise a student.
const double recruiterScanWeightThreshold = 0.20;
