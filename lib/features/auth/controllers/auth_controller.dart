import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/user_model.dart';
import '../../../services/auth/lockout_policy.dart';
import '../repository/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

/// UI-facing state for the auth screens (Login, Register, Forgot Password).
class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});

  const AuthState.idle() : this(status: AuthStatus.idle);
  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.success() : this(status: AuthStatus.success);
  const AuthState.error(String message) : this(status: AuthStatus.error, errorMessage: message);

  bool get isLoading => status == AuthStatus.loading;
}

/// Handles Login (FR-02), Register (FR-01 / FR-03), Forgot Password
/// (FR-04), account lockout (FR-36, via [LockoutPolicy] — UT-10), and the
/// deactivated-account check (FR-05). The actual navigation after a
/// successful sign-in is handled by `app_router.dart`'s redirect — this
/// controller only reports success/error so the screen can show a message.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState.idle());

  final AuthRepository _repo;

  // --------------------------------------------------------------------
  // FR-36 — lockout state persistence.
  //
  // The actual threshold/duration LOGIC lives in [LockoutPolicy]
  // (lib/services/auth/lockout_policy.dart), which is pure and unit
  // tested directly (UT-10). This class is just responsible for loading
  // and saving that state via shared_preferences, keyed by email.
  //
  // 🔶 Phase 2/3 note: storing this on-device satisfies FR-36's
  // *behaviour* for a single device, but a user could bypass it by
  // reinstalling the app. A true account-wide lock needs a Cloud
  // Function (Section 14) reading/writing users/{uid} via the Admin SDK.
  // --------------------------------------------------------------------

  Future<LockoutState> _loadLockoutState(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt('failed_attempts_$email') ?? 0;
    final lockedUntilMillis = prefs.getInt('locked_until_$email');
    return LockoutState.fromMap({
      'failedAttempts': attempts,
      'lockedUntilMillis': lockedUntilMillis,
    });
  }

  Future<void> _saveLockoutState(String email, LockoutState state) async {
    final prefs = await SharedPreferences.getInstance();
    final map = state.toMap();
    await prefs.setInt('failed_attempts_$email', map['failedAttempts'] ?? 0);
    final lockedUntilMillis = map['lockedUntilMillis'];
    if (lockedUntilMillis == null) {
      await prefs.remove('locked_until_$email');
    } else {
      await prefs.setInt('locked_until_$email', lockedUntilMillis);
    }
  }

  /// FR-02, FR-05, FR-36 — sign in, enforcing lockout + active-account checks.
  Future<void> signIn({required String email, required String password}) async {
    state = const AuthState.loading();
    final normalizedEmail = email.trim().toLowerCase();
    final now = DateTime.now();

    // FR-36 — refuse to even try Firebase if this device is locked out.
    final lockout = await _loadLockoutState(normalizedEmail);
    if (LockoutPolicy.isLocked(lockout, now)) {
      final minutesLeft = LockoutPolicy.minutesRemaining(lockout, now);
      state = AuthState.error(
        'Your account is locked due to too many failed attempts. '
        'Try again in about $minutesLeft minute(s), or reset your password.',
      );
      return;
    }

    try {
      final credential = await _repo.signIn(email: normalizedEmail, password: password);
      final uid = credential.user!.uid;

      final userModel = await _repo.getUserModel(uid);
      if (userModel == null) {
        await _repo.signOut();
        state = const AuthState.error(
          'No profile found for this account. Please contact the admin.',
        );
        return;
      }

      // FR-05 — Admin can deactivate accounts; block sign-in if so.
      if (!userModel.isActive) {
        await _repo.signOut();
        state = const AuthState.error(
          'Your account has been deactivated by the admin. '
          'Please contact the placement office.',
        );
        return;
      }

      await _saveLockoutState(normalizedEmail, LockoutPolicy.reset());
      await _repo.updateLastLogin(uid);
      state = const AuthState.success();
    } on FirebaseAuthException catch (e) {
      final updated = LockoutPolicy.recordFailedAttempt(lockout, now);
      await _saveLockoutState(normalizedEmail, updated);
      state = AuthState.error(_mapAuthError(e));
    } catch (_) {
      state = const AuthState.error('Something went wrong. Please try again.');
    }
  }

  /// FR-01, FR-03 — register a new account and write its Firestore profile.
  Future<void> register({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = const AuthState.loading();
    final normalizedEmail = email.trim().toLowerCase();

    // FR-01 — defence in depth; the UI also validates this.
    if (!normalizedEmail.endsWith('@diu.edu.bd')) {
      state = const AuthState.error('Please use your @diu.edu.bd email address.');
      return;
    }

    try {
      final credential = await _repo.register(email: normalizedEmail, password: password);
      final uid = credential.user!.uid;

      final user = UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: normalizedEmail,
        role: role,
        studentId: studentId.trim(),
        createdAt: DateTime.now(),
      );
      await _repo.createUserDocument(user);

      state = const AuthState.success();
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(_mapAuthError(e));
    } catch (_) {
      state = const AuthState.error('Something went wrong. Please try again.');
    }
  }

  /// FR-04 — send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    state = const AuthState.loading();
    try {
      await _repo.sendPasswordResetEmail(email.trim().toLowerCase());
      state = const AuthState.success();
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(_mapAuthError(e));
    } catch (_) {
      state = const AuthState.error('Something went wrong. Please try again.');
    }
  }

  /// Signs out the current device/session. See [AuthRepository.signOut]
  /// for the FR-37 ("all devices") caveat.
  Future<void> signOut() => _repo.signOut();

  /// Clears any stale success/error state — call when a screen mounts.
  void resetState() => state = const AuthState.idle();

  /// User-friendly messages for common FirebaseAuth error codes.
  /// Section 15: "Never show technical error codes to users."
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact the admin.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (minimum 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
