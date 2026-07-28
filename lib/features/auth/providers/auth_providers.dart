import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../controllers/auth_controller.dart';
import '../repository/auth_repository.dart';

/// Singleton data-access layer for Firebase Auth + users/{uid}.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// UI-facing controller for Login / Register / Forgot Password screens.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Live Firebase Auth session — null when signed out. Also drives the
/// router's redirect logic (see app_router.dart).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Live Firestore profile (users/{uid}) for the signed-in user, or null
/// when signed out or no profile exists yet. Use this in dashboards, e.g.
/// `Text('Welcome, ${userModel.fullName}')`.
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) => user == null ? Stream.value(null) : repo.watchUserModel(user.uid),
    loading: () => Stream.empty(),
    error: (_, __) => Stream.value(null),
  );
});
