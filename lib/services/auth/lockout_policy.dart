import '../../app/app_constants.dart';

/// FR-36 — "lock an account for 30 minutes after 5 consecutive failed
/// login attempts".
///
/// Immutable snapshot of one email's lockout state. Persisted via
/// shared_preferences by [AuthController] (Phase 2) — see the
/// 🔶 device-vs-account-wide note there.
class LockoutState {
  final int failedAttempts;
  final DateTime? lockedUntil;

  const LockoutState({this.failedAttempts = 0, this.lockedUntil});

  static const initial = LockoutState();

  Map<String, int?> toMap() => {
        'failedAttempts': failedAttempts,
        'lockedUntilMillis': lockedUntil?.millisecondsSinceEpoch,
      };

  factory LockoutState.fromMap(Map<String, int?> map) {
    final millis = map['lockedUntilMillis'];
    return LockoutState(
      failedAttempts: map['failedAttempts'] ?? 0,
      lockedUntil: millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// Pure FR-36 policy logic — no Firebase, no shared_preferences — so it
/// can be unit tested directly (UT-10) without mocking either.
class LockoutPolicy {
  const LockoutPolicy._();

  /// Is [state] currently locked, as of [now]?
  static bool isLocked(LockoutState state, DateTime now) {
    final until = state.lockedUntil;
    return until != null && now.isBefore(until);
  }

  /// How many whole minutes remain until the lock lifts (>= 1 if locked,
  /// 0 if not locked). For showing "try again in N minute(s)".
  static int minutesRemaining(LockoutState state, DateTime now) {
    final until = state.lockedUntil;
    if (until == null || !now.isBefore(until)) return 0;
    final remaining = until.difference(now).inMinutes;
    return remaining > 0 ? remaining : 1;
  }

  /// Records one failed login attempt and returns the new state.
  ///
  /// - Increments [LockoutState.failedAttempts].
  /// - Once the count reaches [maxFailedLoginAttempts] (5), resets the
  ///   counter to 0 and sets [LockoutState.lockedUntil] to
  ///   `now + accountLockDurationMinutes` (30 minutes) — UT-10:
  ///   "isLocked = true, login blocked for 30 minutes".
  static LockoutState recordFailedAttempt(LockoutState state, DateTime now) {
    final attempts = state.failedAttempts + 1;
    if (attempts >= maxFailedLoginAttempts) {
      return LockoutState(
        failedAttempts: 0,
        lockedUntil: now.add(const Duration(minutes: accountLockDurationMinutes)),
      );
    }
    return LockoutState(failedAttempts: attempts, lockedUntil: state.lockedUntil);
  }

  /// Called after a SUCCESSFUL login — clears both the counter and any
  /// lock.
  static LockoutState reset() => LockoutState.initial;
}
