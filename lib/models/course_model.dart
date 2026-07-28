import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore: courses/{courseId} — Section 5.4 (S-27 Course Master
/// Screen): "Course table with code, name, credits, department, tagged
/// skills."
///
/// 🔶 Like `jobDescriptions`, this collection isn't in Section 9's
/// detailed schema tables (9.2-9.5) — only named in the screen
/// description and the access matrix's collection list (which
/// `firestore.rules` already covers, added in Phase 5). This model
/// fills in the field shape implied by S-27's "Key UI Components"
/// column. It's intentionally separate from CourseGradeModel (a
/// student's grade record for one course) — this is the admin-managed
/// MASTER list of courses that exist at all, independent of any
/// student's transcript.
class CourseModel {
  final String courseId;
  final String courseCode;
  final String courseName;
  final int creditHours;
  final String department;
  final List<String> taggedSkills; // links a course to JD requiredSkills (Section 12.4)
  final DateTime? createdAt;

  const CourseModel({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    this.creditHours = 3,
    this.department = '',
    this.taggedSkills = const [],
    this.createdAt,
  });

  factory CourseModel.fromMap(String courseId, Map<String, dynamic> map) {
    return CourseModel(
      courseId: courseId,
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      creditHours: map['creditHours'] ?? 3,
      department: map['department'] ?? '',
      taggedSkills: List<String>.from(map['taggedSkills'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'creditHours': creditHours,
      'department': department,
      'taggedSkills': taggedSkills,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  CourseModel copyWith({
    String? courseCode,
    String? courseName,
    int? creditHours,
    String? department,
    List<String>? taggedSkills,
  }) {
    return CourseModel(
      courseId: courseId,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      creditHours: creditHours ?? this.creditHours,
      department: department ?? this.department,
      taggedSkills: taggedSkills ?? this.taggedSkills,
      createdAt: createdAt,
    );
  }
}
