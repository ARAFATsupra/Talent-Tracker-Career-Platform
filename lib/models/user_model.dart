import 'package:cloud_firestore/cloud_firestore.dart';

/// FR-03 — Role assignment: student, recruiter, or admin
enum UserRole { student, recruiter, admin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'recruiter':
      return UserRole.recruiter;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.student;
  }
}

String userRoleToString(UserRole role) => role.name;

/// Firestore: users/{uid} — Section 9.2
/// Document ID = Firebase Auth UID.
class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final UserRole role;
  final String studentId;
  final String department;
  final String batch;
  final String? profilePhotoUrl;
  final double cgpa; // auto-recalculated whenever grades change (FR-07)
  final bool isActive; // controlled by Admin (FR-05)
  final String preferredLanguage; // 'en' or 'bn' (NFR-15)
  final int failedLoginCount; // FR-36
  final bool isLocked; // FR-36 — true after 5 failed logins
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.studentId = '',
    this.department = '',
    this.batch = '',
    this.profilePhotoUrl,
    this.cgpa = 0.0,
    this.isActive = true,
    this.preferredLanguage = 'en',
    this.failedLoginCount = 0,
    this.isLocked = false,
    this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: userRoleFromString(map['role'] ?? 'student'),
      studentId: map['studentId'] ?? '',
      department: map['department'] ?? '',
      batch: map['batch'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'],
      cgpa: (map['cgpa'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      failedLoginCount: map['failedLoginCount'] ?? 0,
      isLocked: map['isLocked'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'role': userRoleToString(role),
      'studentId': studentId,
      'department': department,
      'batch': batch,
      'profilePhotoUrl': profilePhotoUrl,
      'cgpa': cgpa,
      'isActive': isActive,
      'preferredLanguage': preferredLanguage,
      'failedLoginCount': failedLoginCount,
      'isLocked': isLocked,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? profilePhotoUrl,
    double? cgpa,
    bool? isActive,
    String? preferredLanguage,
    int? failedLoginCount,
    bool? isLocked,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      role: role,
      studentId: studentId,
      department: department,
      batch: batch,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      cgpa: cgpa ?? this.cgpa,
      isActive: isActive ?? this.isActive,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      failedLoginCount: failedLoginCount ?? this.failedLoginCount,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
