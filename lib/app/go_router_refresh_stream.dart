import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a [Stream] (e.g. `FirebaseAuth.authStateChanges()`) to a
/// [Listenable], so GoRouter's `refreshListenable` re-evaluates the
/// `redirect` callback whenever the stream emits — i.e. on sign-in /
/// sign-out.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
