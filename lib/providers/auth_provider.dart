import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Firebase auth state'i (User? — null ise oturum yok)
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Kullanıcı gerçek üye mi (anonim değil, oturum açmış)?
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  return user != null && !user.isAnonymous;
});

/// Oturum açmış kullanıcının AppUser profili
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null || user.isAnonymous) return null;
  return ref.watch(authServiceProvider).fetchCurrentUser();
});
