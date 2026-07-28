import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: feedback/{id} — Section 9.1.
/// Submitted from the Feedback Screen (S-33): "1 to 5 star rating selector,
/// optional text comment box, submit button". Per Section 9.5, students can
/// write their own document once; only Admin can read.
class FeedbackModel {
  final String studentUid;
  final int rating; // 1-5
  final String comment;
  final DateTime? createdAt;

  const FeedbackModel({
    required this.studentUid,
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      studentUid: map['studentUid'] ?? '',
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// 1-5 star rating, per the spec.
  bool get isValid => rating >= 1 && rating <= 5;
}
