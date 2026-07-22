import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import 'crash_service.dart';
import 'notification_service.dart';

/// Hesap silme akışında kullanıcının yeniden giriş yapması gerektiğini bildirir.
enum AccountDeletionException { requiresRecentLogin }

/// Kimlik doğrulama tamamlandıktan sonraki yardımcı işlemler oturumu geri
/// almamalı. Özellikle iOS'ta APNs token'ı ilk açılışta henüz hazır olmayabilir.
@visibleForTesting
Future<void> runPostSignInSideEffect(
  Future<void> Function() operation, {
  Future<void> Function(Object error, StackTrace stack)? onError,
}) async {
  try {
    await operation();
  } catch (error, stack) {
    if (onError == null) return;
    try {
      await onError(error, stack);
    } catch (_) {
      // Hata raporlama servisi de oturum açmayı engellememeli.
    }
  }
}

/// Çıkış öncesi temizlik işlemleri başarısız olsa bile gerçek oturum kapatma
/// adımını çalıştırır. FCM/APNs gibi yardımcı servisler kullanıcıyı uygulamada
/// kilitli bırakamaz.
@visibleForTesting
Future<void> runSignOutFlow({
  required List<Future<void> Function()> cleanupOperations,
  required Future<void> Function() signOut,
  Future<void> Function(Object error, StackTrace stack)? onCleanupError,
}) async {
  for (final cleanup in cleanupOperations) {
    await runPostSignInSideEffect(cleanup, onError: onCleanupError);
  }
  await signOut();
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null && !currentUser!.isAnonymous;

  Future<void> _saveNotificationToken(String userId) => runPostSignInSideEffect(
    () => NotificationService.saveToken(userId),
    onError: (error, stack) => CrashService.recordError(
      error,
      stack,
      context: 'Bildirim tokenı giriş sonrasında kaydedilemedi',
    ),
  );

  Future<void> _ensureNotSuspended(String userId) async {
    final ban = await _db.collection('moderation_bans').doc(userId).get();
    if (!ban.exists) return;

    await _auth.signOut();
    throw FirebaseAuthException(
      code: 'user-disabled',
      message:
          'Bu hesap topluluk kurallarını ihlal ettiği için askıya alınmıştır.',
    );
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) throw Exception('Kullanıcı oluşturulamadı');

    await cred.user!.updateDisplayName(displayName);

    final user = AppUser(
      id: uid,
      displayName: displayName,
      username: username,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.id).set(user.toFirestore());
    await CrashService.setUser(uid);
    await _saveNotificationToken(uid);
    return user;
  }

  Future<void> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) return;
    await _ensureNotSuspended(user.uid);
    await CrashService.setUser(user.uid);
    // Profil belgesi yoksa oluştur — eski/dış hesaplarda users/{uid} eksik
    // olabilir; bu durumda yorum/etkileşim akışları kırılmasın.
    await _ensureUserDoc(user);
    await _saveNotificationToken(user.uid);
  }

  /// users/{uid} belgesi yoksa veya yalnızca cihaz tokenı içeriyorsa auth
  /// bilgisinden eksik profil alanlarını tamamlar.
  Future<AppUser> _ensureUserDoc(
    User user, {
    String? fallbackDisplayName,
    String? fallbackUsername,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    final data = doc.data();
    final hasProfile =
        doc.exists &&
        data?['displayName'] is String &&
        (data!['displayName'] as String).isNotEmpty &&
        data['username'] is String;
    if (hasProfile) return AppUser.fromFirestore(doc);

    final appUser = AppUser(
      id: user.uid,
      displayName: (user.displayName?.isNotEmpty == true)
          ? user.displayName!
          : (fallbackDisplayName?.isNotEmpty == true)
          ? fallbackDisplayName!
          : (user.email?.split('@').first ?? 'Kullanıcı'),
      username: fallbackUsername ?? user.email?.split('@').first ?? '',
      avatarUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
    await ref.set(appUser.toFirestore(), SetOptions(merge: true));
    return appUser;
  }

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('google_cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    if (user == null) throw Exception('Google girişi başarısız');

    await _ensureNotSuspended(user.uid);
    await CrashService.setUser(user.uid);
    final appUser = await _ensureUserDoc(
      user,
      fallbackDisplayName: googleUser.displayName,
      fallbackUsername: googleUser.email.split('@').first,
    );
    await _saveNotificationToken(user.uid);
    return appUser;
  }

  // ── Apple ile Giriş ──────────────────────────────────────────────────────
  // App Store Guideline 4.8 gereği Google girişi sunulduğu için zorunlu.

  Future<AppUser?> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final cred = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    final user = cred.user;
    if (user == null) throw Exception('Apple girişi başarısız');

    await _ensureNotSuspended(user.uid);
    await CrashService.setUser(user.uid);
    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email?.split('@').first ?? 'Kullanıcı');
    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(displayName);
    }
    final appUser = await _ensureUserDoc(
      user,
      fallbackDisplayName: displayName,
    );
    await _saveNotificationToken(user.uid);
    return appUser;
  }

  Future<void> continueAsGuest() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    final user = currentUser;
    final uid = user?.uid;
    await runSignOutFlow(
      cleanupOperations: [
        if (uid != null && !user!.isAnonymous)
          () => NotificationService.clearToken(uid),
        CrashService.clearUser,
      ],
      signOut: _auth.signOut,
      onCleanupError: (error, stack) => CrashService.recordError(
        error,
        stack,
        context: 'Çıkış öncesi temizlik tamamlanamadı',
      ),
    );
  }

  // ── Hesap silme ────────────────────────────────────────────────────────────
  // App Store Guideline 5.1.1(v) gereği hesap oluşturan uygulamalar için zorunlu.
  //
  // [AccountDeletionException.requiresRecentLogin] fırlatırsa, çağıran taraf
  // kullanıcıyı yeniden giriş yapmaya yönlendirip tekrar denemeli — Firebase
  // hesap silme için yakın zamanda kimlik doğrulaması ister.

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Silinecek bir hesap yok');
    }
    final uid = user.uid;

    // Apple, Sign in with Apple kullanan hesaplar silinirken verilen yetkinin
    // de iptal edilmesini ister. Yeniden kimlik doğrulama hem güncel bir
    // authorization code üretir hem de Firebase'in recent-login şartını
    // karşılar.
    if (!kIsWeb && user.providerData.any((p) => p.providerId == 'apple.com')) {
      try {
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final credential = await user.reauthenticateWithProvider(provider);
        final authorizationCode =
            credential.additionalUserInfo?.authorizationCode;
        if (authorizationCode == null || authorizationCode.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-apple-authorization-code',
            message: 'Apple yetkilendirme kodu alınamadı.',
          );
        }
        await _auth.revokeTokenWithAuthorizationCode(authorizationCode);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw AccountDeletionException.requiresRecentLogin;
        }
        rethrow;
      }
    }

    // FCM token'ını temizle ki silinen kullanıcıya bildirim gönderilmeye
    // çalışılmasın.
    await NotificationService.clearToken(uid);

    // Kullanıcının beğeni alt-belgelerini temizle (collectionGroup sorgusu).
    try {
      final likes = await _db
          .collectionGroup('likes')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in likes.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // Beğeni temizliği başarısız olsa da hesap silmeyi engelleme.
    }

    // Kullanıcı profil belgesini sil.
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {}

    // Son adım: Firebase Auth hesabını sil.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionException.requiresRecentLogin;
      }
      rethrow;
    }

    await CrashService.clearUser();
  }

  Future<AppUser?> fetchCurrentUser() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) return AppUser.fromFirestore(doc);
    // Firestore profili yoksa auth bilgisinden minimal profil döndür —
    // böylece yorum vb. akışlar user==null yüzünden kırılmaz.
    return AppUser(
      id: user.uid,
      displayName: (user.displayName?.isNotEmpty == true)
          ? user.displayName!
          : (user.email?.split('@').first ?? 'Kullanıcı'),
      username: user.email?.split('@').first ?? '',
      avatarUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
  }
}
