// Section 17.1 — UT-10: Account lock after 5 failed logins ->
// isLocked = true, login blocked for 30 minutes (FR-36).

import 'package:flutter_test/flutter_test.dart';
import 'package:talent_tracker_ai/app/app_constants.dart';
import 'package:talent_tracker_ai/services/auth/lockout_policy.dart';

void main() {
  group('UT-10 — LockoutPolicy (FR-36)', () {
    test('first 4 failed attempts do not lock the account', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      var state = LockoutState.initial;

      for (var i = 0; i < 4; i++) {
        state = LockoutPolicy.recordFailedAttempt(state, now);
      }

      expect(state.failedAttempts, 4);
      expect(LockoutPolicy.isLocked(state, now), isFalse);
    });

    test('the 5th failed attempt locks the account for 30 minutes', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      var state = LockoutState.initial;

      for (var i = 0; i < 5; i++) {
        state = LockoutPolicy.recordFailedAttempt(state, now);
      }

      expect(LockoutPolicy.isLocked(state, now), isTrue);
      expect(state.failedAttempts, 0); // counter resets once locked
      expect(state.lockedUntil, isNotNull);
      expect(
        state.lockedUntil!.difference(now),
        const Duration(minutes: accountLockDurationMinutes),
      );
      expect(LockoutPolicy.minutesRemaining(state, now), accountLockDurationMinutes);
    });

    test('the lock lifts automatically after 30 minutes', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      var state = LockoutState.initial;
      for (var i = 0; i < 5; i++) {
        state = LockoutPolicy.recordFailedAttempt(state, now);
      }
      expect(LockoutPolicy.isLocked(state, now), isTrue);

      final after31Minutes = now.add(const Duration(minutes: 31));
      expect(LockoutPolicy.isLocked(state, after31Minutes), isFalse);
      expect(LockoutPolicy.minutesRemaining(state, after31Minutes), 0);
    });

    test('a successful login resets the lockout state', () {
      final reset = LockoutPolicy.reset();
      expect(reset.failedAttempts, 0);
      expect(reset.lockedUntil, isNull);
    });
  });
}
