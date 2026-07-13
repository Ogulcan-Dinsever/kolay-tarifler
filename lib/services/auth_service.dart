import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import 'crash_service.dart';
import 'notification_service.dart';

/// Hesap silme akışında kullanıcının yeniden giriş yapması gerektiğini bildirir.
enum AccountDeletionException { requiresRecentLogin }

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null && !currentUser!.isAnonymous;

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
    await NotificationService.saveToken(uid);
    return user;
  }

  Future<void> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) return;
    await CrashService.setUser(user.uid);
    await NotificationService.saveToken(user.uid);
    // Profil belgesi yoksa oluştur — eski/dış hesaplarda users/{uid} eksik
    // olabilir; bu durumda yorum/etkileşim akışları kırılmasın.
    await _ensureUserDoc(user);
  }

  /// users/{uid} belgesi yoksa auth bilgisinden minimal bir profil oluşturur.
  Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (doc.exists) return;
    final appUser = AppUser(
      id: user.uid,
      displayName: (user.displayName?.isNotEmpty == true)
          ? user.displayName!
          : (user.email?.split('@').first ?? 'Kullanıcı'),
      username: user.email?.split('@').first ?? '',
      avatarUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
    await ref.set(appUser.toFirestore());
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

    await CrashService.setUser(user.uid);
    await NotificationService.saveToken(user.uid);

    // Firestore'da kayıt yoksa oluştur
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      final appUser = AppUser(
        id: user.uid,
        displayName: user.displayName ?? googleUser.displayName ?? 'Kullanıcı',
        username: googleUser.email.split('@').first,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set(appUser.toFirestore());
      return appUser;
    }
    return AppUser.fromFirestore(doc);
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

    await CrashService.setUser(user.uid);
    await NotificationService.saveToken(user.uid);

    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email?.split('@').first ?? 'Kullanıcı');
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(displayName);
      }
      final appUser = AppUser(
        id: user.uid,
        displayName: displayName,
        username: user.email?.split('@').first ?? '',
        avatarUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      await ref.set(appUser.toFirestore());
      return appUser;
    }
    return AppUser.fromFirestore(doc);
  }

  Future<void> continueAsGuest() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null && !currentUser!.isAnonymous) {
      await NotificationService.clearToken(uid);
    }
    await CrashService.clearUser();
    await _auth.signOut();
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
