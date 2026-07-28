import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: systemLogs/{id} — written by Cloud Functions (Section
/// 14.1's `logSystemError` helper in
/// functions/src/triggers/onStudentGradeUpdated.ts), read by the Admin
/// Portal's System Error Log screen (S-31).
///
/// Mirrors functions/src/types.ts's `SystemLog` interface — kept in
/// sync by hand the same way match_engine.dart/matchEngine.ts are (see
/// PHASE6_GUIDE.md).
enum LogSeverity { error, warning, info }

LogSeverity logSeverityFromString(String value) {
  switch (value.toUpperCase()) {
    case 'ERROR':
      return LogSeverity.error;
    case 'WARNING':
      return LogSeverity.warning;
    default:
      return LogSeverity.info;
  }
}

extension LogSeverityLabel on LogSeverity {
  String get label {
    switch (this) {
      case LogSeverity.error:
        return 'ERROR';
      case LogSeverity.warning:
        return 'WARNING';
      case LogSeverity.info:
        return 'INFO';
    }
  }
}

class SystemLogModel {
  final String id;
  final LogSeverity severity;
  final String message;
  final String source;
  final bool resolved;
  final DateTime? occurredAt;

  const SystemLogModel({
    required this.id,
    required this.severity,
    required this.message,
    required this.source,
    this.resolved = false,
    this.occurredAt,
  });

  factory SystemLogModel.fromMap(String id, Map<String, dynamic> map) {
    return SystemLogModel(
      id: id,
      severity: logSeverityFromString(map['severity'] ?? 'INFO'),
      message: map['message'] ?? '',
      source: map['source'] ?? '',
      resolved: map['resolved'] ?? false,
      occurredAt: (map['occurredAt'] as Timestamp?)?.toDate(),
    );
  }
}
