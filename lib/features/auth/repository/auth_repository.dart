import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/app_constants.dart';
import '../../../models/user_model.dart';

/// Thin wrapper around Firebase Auth + the `users/{uid}` Firestore
/// collection. Implements the data-access side of FR-01 to FR-05.
///
/// 🔶 Keep this class free of UI / state-management concerns — that lives
/// in [AuthController]. This makes both sides independently testable.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// FR-02 — live Firebase Auth session stream (null = signed out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, if any.
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestoreCollections.users);

  /// FR-02 — sign in with email + password.
  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// FR-01 / FR-02 — create the Firebase Auth account itself.
  /// The caller (AuthController) is responsible for then calling
  /// [createUserDocument] with the chosen role (FR-03).
  Future<UserCredential> register({required String email, required String password}) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// FR-03 — write the role + profile document to users/{uid}.
  Future<void> createUserDocument(UserModel user) {
    return _usersRef.doc(user.uid).set(user.toMap());
  }

  /// FR-04 — send a Firebase password-reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Signs out the current session.
  ///
  /// 🔶 FR-37 ("log out from all devices") needs Firebase Admin SDK's
  /// `revokeRefreshTokens` — this only ends the *current* session/device.
  /// Implement the multi-device version as a Cloud Function in a later
  /// backend phase.
  Future<void> signOut() => _auth.signOut();

  /// Fetches users/{uid} once and maps it to a [UserModel], or null if the
  /// document doesn't exist yet (e.g. mid-registration, before
  /// [createUserDocument] has run).
  Future<UserModel?> getUserModel(String uid) async {
    final snap = await _usersRef.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromMap(uid, snap.data()!);
  }

  /// Live stream of users/{uid} — for dashboards / profile screens that
  /// need to react to Admin-side changes (e.g. FR-05 deactivation).
  Stream<UserModel?> watchUserModel(String uid) {
    return _usersRef.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(uid, snap.data()!);
    });
  }

  /// Updates `lastLogin` on a successful sign-in (Section 9.2).
  Future<void> updateLastLogin(String uid) {
    return _usersRef.doc(uid).update({'lastLogin': FieldValue.serverTimestamp()});
  }

  // ------------------------------------------------------------------
  // S-06 Profile Settings Screen
  // ------------------------------------------------------------------

  /// "Name edit" — updates both the Firestore profile and Firebase
  /// Auth's `displayName` (kept in sync so the two never disagree, even
  /// though this app's UI always reads the Firestore copy).
  Future<void> updateFullName(String uid, String fullName) async {
    await _usersRef.doc(uid).update({'fullName': fullName});
    await _auth.currentUser?.updateDisplayName(fullName);
  }

  /// "Language toggle EN/BN" (NFR-15).
  Future<void> updatePreferredLanguage(String uid, String languageCode) {
    return _usersRef.doc(uid).update({'preferredLanguage': languageCode});
  }

  /// "Profile photo (tap to change)" — caller (the screen) handles
  /// picking + uploading the file to Firebase Storage via `image_picker`
  /// + `firebase_storage` (see `storage.rules`'s `profile_photos/{uid}`
  /// path, Phase 5); this just persists the resulting download URL.
  Future<void> updateProfilePhotoUrl(String uid, String? url) {
    return _usersRef.doc(uid).update({'profilePhotoUrl': url});
  }

  /// "Password change" — Firebase requires a recent sign-in for this;
  /// callers should re-authenticate first if this throws
  /// `requires-recent-login` (see [reauthenticate]).
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.updatePassword(newPassword);
  }

  /// Re-authenticates the current user with their existing password —
  /// required by Firebase before a sensitive operation (password
  /// change, account deletion) if the session isn't "recent."
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw StateError('No signed-in user.');
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
  }

  /// "Delete account" — removes the Firestore profile AND the Firebase
  /// Auth account itself (self-service deletion can use the client SDK
  /// directly, unlike the Admin-initiated deletion in
  /// `AdminRepository.deleteUserProfile`, which can only remove the
  /// Firestore side without a Cloud Function). Deletes the Firestore
  /// doc FIRST so a failure deleting the Auth account doesn't leave an
  /// orphaned profile with no way to sign in and retry.
  Future<void> deleteOwnAccount(String uid) async {
    await _usersRef.doc(uid).delete();
    await _auth.currentUser?.delete();
  }
}
