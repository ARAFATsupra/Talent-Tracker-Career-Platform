import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/course_model.dart';
import '../../../models/jd_model.dart';
import '../../../models/system_log_model.dart';
import '../../../models/user_model.dart';

/// Data access for the Admin Portal (Section 5.4):
///  - FR-22 — full CRUD on users, JD library (and, later, course data).
///  - FR-24 — dashboard metrics (total students, top 5 roles).
///  - FR-25 — AI weighting config UI, writing `courseWeights` on a JD.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get _jdRef =>
      _firestore.collection(FirestoreCollections.jobDescriptions);

  // ------------------------------------------------------------------
  // S-26 User Management (FR-22)
  // ------------------------------------------------------------------

  /// Live stream of every user account, newest first. The User
  /// Management screen (S-26) does its own client-side search/role
  /// filtering on top of this — the full user count is also small enough
  /// for a university placement system that a single live query is fine
  /// (no pagination needed yet).
  Stream<List<UserModel>> watchAllUsers() {
    return _usersRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList(),
        );
  }

  /// FR-22 / FR-05 — toggle a user's active status (the same field the
  /// sign-in flow checks — see AuthController's FR-05 block).
  Future<void> setUserActive(String uid, bool isActive) {
    return _usersRef.doc(uid).update({'isActive': isActive});
  }

  /// FR-22 — change a user's role. 🔶 Use with care: combined with the
  /// `firestore.rules` SECURITY TODO on `users/{uid}` (a user can edit
  /// their own doc's `role` field client-side today), this admin-side
  /// method is fine, but the rules hardening described there is still
  /// the real fix for self-promotion. This method exists for the Admin
  /// UI's Edit action; it doesn't change that risk either way.
  Future<void> setUserRole(String uid, UserRole role) {
    return _usersRef.doc(uid).update({'role': userRoleToString(role)});
  }

  /// FR-22 — full account deletion. Only removes the Firestore profile;
  /// 🔶 the matching Firebase Auth account needs the Admin SDK
  /// (`auth.deleteUser(uid)`) to fully remove, which requires a Cloud
  /// Function — out of scope for the client-only Admin Portal in this
  /// phase. Deactivating (`setUserActive(uid, false)`) is the safer,
  /// fully-client-side option and is what the User Management screen
  /// leads with.
  Future<void> deleteUserProfile(String uid) {
    return _usersRef.doc(uid).delete();
  }

  // ------------------------------------------------------------------
  // S-28 JD Library / S-29 AI Weighting Config (FR-22, FR-25)
  // ------------------------------------------------------------------

  /// Live stream of every JD (active AND archived) — the JD Library
  /// screen (S-28) shows both, with an active/archived toggle per row.
  Stream<List<JDModel>> watchAllJDs() {
    return _jdRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => JDModel.fromMap(d.id, d.data())).toList(),
        );
  }

  /// FR-22/FR-25 — create a brand-new JD. Returns the generated `jdId`.
  Future<String> createJD(JDModel jd, String adminUid) async {
    final data = jd.toMap()..['addedBy'] = adminUid;
    final doc = await _jdRef.add(data);
    return doc.id;
  }

  /// FR-22 — update any field on an existing JD (title, skills, courses,
  /// salary, source link, certifications, remediations, active flag).
  Future<void> updateJD(JDModel jd) {
    return _jdRef.doc(jd.jdId).set(jd.toMap(), SetOptions(merge: true));
  }

  /// FR-22 — "archive" a JD rather than hard-deleting it, since past
  /// `placements` records reference it by title/jdId and Section 9.5
  /// doesn't define cascading deletes.
  Future<void> setJDActive(String jdId, bool isActive) {
    return _jdRef.doc(jdId).update({'isActive': isActive});
  }

  /// FR-25 — "configure the AI weighting model through a UI form,
  /// without writing any code." Replaces a single JD's
  /// `criticalPathCourses` + `courseWeights` matrix cell-by-cell, exactly
  /// the data [MatchEngine] (Phase 3) reads — so a change here takes
  /// effect for every student's AI Job Match (S-11) on their next visit,
  /// with no extra propagation step needed (the engine runs on-device,
  /// live, against whatever is currently in Firestore).
  Future<void> updateCourseWeights(
    String jdId, {
    required List<String> criticalPathCourses,
    required Map<String, double> courseWeights,
  }) {
    return _jdRef.doc(jdId).update({
      'criticalPathCourses': criticalPathCourses,
      'courseWeights': courseWeights,
    });
  }

  // ------------------------------------------------------------------
  // S-25 Admin Dashboard (FR-24)
  // ------------------------------------------------------------------

  /// FR-24 — "total students, placements this month, top 5 roles, error
  /// count". The Admin Dashboard provider (`userCountsByRoleProvider`)
  /// currently derives this client-side from [watchAllUsers] instead
  /// (simpler — one stream covers every role-count card at once). This
  /// method is kept as the lighter-weight alternative — a single
  /// server-side aggregate read instead of streaming every user
  /// document — for whenever the user table grows large enough that
  /// streaming all profiles just to count them stops being efficient.
  Future<int> countStudents() async {
    final snap = await _usersRef.where('role', isEqualTo: 'student').count().get();
    return snap.count ?? 0;
  }

  // ------------------------------------------------------------------
  // S-27 Course Master (FR-22)
  // ------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      _firestore.collection(FirestoreCollections.courses);

  /// Live stream of the full master course list — S-27's "Course table
  /// with code, name, credits, department, tagged skills."
  Stream<List<CourseModel>> watchAllCourses() {
    return _coursesRef.orderBy('courseCode').snapshots().map(
          (snap) => snap.docs.map((d) => CourseModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> createCourse(CourseModel course) async {
    await _coursesRef.add(course.toMap());
  }

  Future<void> updateCourse(CourseModel course) {
    return _coursesRef.doc(course.courseId).set(course.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCourse(String courseId) {
    return _coursesRef.doc(courseId).delete();
  }

  /// S-27's "bulk CSV import" — expects rows of
  /// `[courseCode, courseName, creditHours, department, taggedSkills]`,
  /// where `taggedSkills` is a single semicolon-separated cell (CSV
  /// columns can't hold a nested list directly). One Firestore batch per
  /// call — fine for the row counts a university course catalogue
  /// realistically has (hundreds, not millions).
  Future<int> bulkImportCourses(List<List<dynamic>> rows) async {
    final batch = _firestore.batch();
    var count = 0;
    for (final row in rows) {
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
      final code = row[0].toString().trim();
      final name = row.length > 1 ? row[1].toString().trim() : code;
      final credits = row.length > 2 ? int.tryParse(row[2].toString().trim()) ?? 3 : 3;
      final department = row.length > 3 ? row[3].toString().trim() : '';
      final skills = row.length > 4
          ? row[4].toString().split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];

      final doc = _coursesRef.doc();
      batch.set(
        doc,
        CourseModel(
          courseId: doc.id,
          courseCode: code,
          courseName: name,
          creditHours: credits,
          department: department,
          taggedSkills: skills,
        ).toMap(),
      );
      count++;
    }
    if (count > 0) await batch.commit();
    return count;
  }

  // ------------------------------------------------------------------
  // S-30 Broadcast Notification (target selector, message, schedule)
  // ------------------------------------------------------------------

  /// FR-? (Section 5.4's S-30): "Target selector (All/Students/
  /// Recruiters), message title, body, schedule time option, Send Now
  /// button." Fans the broadcast out to every matching user's own
  /// `notifications/{uid}/items` sub-collection (the same shape Cloud
  /// Functions write to — Section 14.1/14.2) — one Firestore batch per
  /// ~450 recipients (Firestore's per-batch write limit is 500;
  /// `notifications` write + the originating doc keeps headroom).
  ///
  /// 🔶 "Schedule time option" — actually delaying delivery until a
  /// future time needs a Cloud Function (Pub/Sub scheduled task or a
  /// Firestore-triggered check), since a Flutter client can't reliably
  /// fire something at a specific future time once the app is closed.
  /// This method sends immediately; [scheduledFor] is still accepted and
  /// stored on each notification doc so a future Cloud Function could
  /// pick up genuinely-scheduled sends without a UI change.
  Future<int> sendBroadcast({
    required String target, // 'all' | 'student' | 'recruiter'
    required String title,
    required String body,
    DateTime? scheduledFor,
  }) async {
    Query<Map<String, dynamic>> query = _usersRef.where('isActive', isEqualTo: true);
    if (target != 'all') {
      query = query.where('role', isEqualTo: target);
    }
    final usersSnap = await query.get();

    var batch = _firestore.batch();
    var opsInBatch = 0;
    var sentCount = 0;

    for (final userDoc in usersSnap.docs) {
      final itemRef = _firestore
          .collection(FirestoreCollections.notifications)
          .doc(userDoc.id)
          .collection('items')
          .doc();
      batch.set(itemRef, {
        'title': title,
        'body': body,
        'type': 'broadcast',
        'targetScreen': 'notifications',
        'read': false,
        'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
        'sentAt': FieldValue.serverTimestamp(),
      });
      opsInBatch++;
      sentCount++;

      if (opsInBatch >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        opsInBatch = 0;
      }
    }
    if (opsInBatch > 0) await batch.commit();

    return sentCount;
  }

  // ------------------------------------------------------------------
  // S-31 System Error Log (Cloud Functions write, Admin reads)
  // ------------------------------------------------------------------

  /// Live stream of every system log, newest first. The screen does its
  /// own client-side severity filter on top of this (matching
  /// IDX-05's `severity, resolved, occurredAt` shape from
  /// `firestore.indexes.json`, Phase 6).
  Stream<List<SystemLogModel>> watchSystemLogs() {
    return _firestore
        .collection(FirestoreCollections.systemLogs)
        .orderBy('occurredAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SystemLogModel.fromMap(d.id, d.data())).toList());
  }

  /// S-31's "Mark Resolved button."
  Future<void> markLogResolved(String logId) {
    return _firestore.collection(FirestoreCollections.systemLogs).doc(logId).update({'resolved': true});
  }

  // ------------------------------------------------------------------
  // S-32 Data Export & Archive (FR-27)
  // ------------------------------------------------------------------

  /// FR-27 — "export all data as a backup file." Builds the same
  /// shape as the Cloud Function's weekly `scheduledDataBackup`
  /// (Section 14.1) — every active student's profile + semesters +
  /// cached match results — but on-demand, for an admin-chosen date
  /// range and the "data type checkboxes" S-32 describes.
  ///
  /// 🔶 [dateRange] filters by `users.createdAt` (when the student
  /// registered) rather than grade-entry date, since semesters don't
  /// carry their own timestamp in the current schema (Section 9.3) —
  /// flagged rather than silently ignored if exact date-range semantics
  /// matter for a real archive cycle.
  Future<Map<String, dynamic>> exportData({
    required bool includeUsers,
    required bool includePlacements,
    required bool includeJDs,
    DateTimeRangeFilter? dateRange,
  }) async {
    final export = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
    };

    if (includeUsers) {
      Query<Map<String, dynamic>> query = _usersRef;
      if (dateRange != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      }
      final snap = await query.get();
      export['users'] = snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    }

    if (includePlacements) {
      final snap = await _firestore.collection(FirestoreCollections.placements).get();
      export['placements'] = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    if (includeJDs) {
      final snap = await _jdRef.get();
      export['jobDescriptions'] = snap.docs.map((d) => {'jdId': d.id, ...d.data()}).toList();
    }

    return export;
  }

  /// S-32's "Archive This Cycle button" — marks every currently-active
  /// JD as inactive in one batch, the same effect as archiving each one
  /// individually from the JD Library (S-28) but scoped to "everything
  /// at once" for a placement-cycle rollover. 🔶 Doesn't touch
  /// `placements`/`users` — Section 9.5 doesn't define what "archiving a
  /// cycle" should do to those, so this is scoped to the one collection
  /// (`jobDescriptions`) where "active/archived" is already a defined
  /// concept (FR-22's JD Library toggle) rather than inventing new
  /// archived-state semantics for users/placements.
  Future<int> archiveCurrentCycle() async {
    final activeSnap = await _jdRef.where('isActive', isEqualTo: true).get();
    if (activeSnap.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in activeSnap.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();
    return activeSnap.docs.length;
  }
}

/// Simple date-range value type for [AdminRepository.exportData] — kept
/// local rather than importing Flutter's `DateTimeRange` (Material) into
/// a data-layer file with no other Flutter dependency.
class DateTimeRangeFilter {
  final DateTime start;
  final DateTime end;
  const DateTimeRangeFilter({required this.start, required this.end});
}
