import 'package:cloud_firestore/cloud_firestore.dart';

/// FR-20 — pipeline stages shown on the Pipeline Board (S-22).
enum PlacementStatus { shortlisted, contacted, interviewScheduled, placed, rejected }

PlacementStatus placementStatusFromString(String value) {
  switch (value) {
    case 'contacted':
      return PlacementStatus.contacted;
    case 'interviewScheduled':
      return PlacementStatus.interviewScheduled;
    case 'placed':
      return PlacementStatus.placed;
    case 'rejected':
      return PlacementStatus.rejected;
    default:
      return PlacementStatus.shortlisted;
  }
}

extension PlacementStatusLabel on PlacementStatus {
  /// Human-readable label for Kanban columns (S-22).
  String get label {
    switch (this) {
      case PlacementStatus.shortlisted:
        return 'Shortlisted';
      case PlacementStatus.contacted:
        return 'Contacted';
      case PlacementStatus.interviewScheduled:
        return 'Interview Scheduled';
      case PlacementStatus.placed:
        return 'Placed';
      case PlacementStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Firestore: placements/{id} — Section 9.1, queried via IDX-02
/// (recruiterUid ASC, status ASC, searchedAt DESC).
class PlacementModel {
  final String id;
  final String recruiterUid;
  final String studentUid;
  final String studentName;
  final String jobTitle;
  final double matchPercentage;
  final PlacementStatus status;
  final String notes; // FR-40 — private recruiter notes, visible only to them
  final DateTime? searchedAt;
  final DateTime? updatedAt;

  const PlacementModel({
    required this.id,
    required this.recruiterUid,
    required this.studentUid,
    required this.studentName,
    required this.jobTitle,
    this.matchPercentage = 0.0,
    this.status = PlacementStatus.shortlisted,
    this.notes = '',
    this.searchedAt,
    this.updatedAt,
  });

  factory PlacementModel.fromMap(String id, Map<String, dynamic> map) {
    return PlacementModel(
      id: id,
      recruiterUid: map['recruiterUid'] ?? '',
      studentUid: map['studentUid'] ?? '',
      studentName: map['studentName'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      matchPercentage: (map['matchPercentage'] ?? 0.0).toDouble(),
      status: placementStatusFromString(map['status'] ?? 'shortlisted'),
      notes: map['notes'] ?? '',
      searchedAt: (map['searchedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recruiterUid': recruiterUid,
      'studentUid': studentUid,
      'studentName': studentName,
      'jobTitle': jobTitle,
      'matchPercentage': matchPercentage,
      'status': status.name,
      'notes': notes,
      'searchedAt':
          searchedAt != null ? Timestamp.fromDate(searchedAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PlacementModel copyWith({PlacementStatus? status, String? notes}) {
    return PlacementModel(
      id: id,
      recruiterUid: recruiterUid,
      studentUid: studentUid,
      studentName: studentName,
      jobTitle: jobTitle,
      matchPercentage: matchPercentage,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      searchedAt: searchedAt,
      updatedAt: updatedAt,
    );
  }
}
