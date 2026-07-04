import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashService {
  static final _crashlytics = FirebaseCrashlytics.instance;

  /// Kullanıcı giriş yaptığında çağır — hata raporlarına kullanıcı ID'si ekler.
  static Future<void> setUser(String userId) async {
    if (kDebugMode) return;
    await _crashlytics.setUserIdentifier(userId);
  }

  /// Kullanıcı çıkış yaptığında temizle.
  static Future<void> clearUser() async {
    if (kDebugMode) return;
    await _crashlytics.setUserIdentifier('');
  }

  /// Beklenmeyen hataları logla (stack trace ile birlikte).
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? context,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('[CrashService] $context — $error\n$stack');
      return;
    }
    await _crashlytics.recordError(
      error,
      stack,
      reason: context,
      fatal: fatal,
    );
  }

  /// Hata olmadan bilgi mesajı logla (breadcrumb gibi).
  static Future<void> log(String message) async {
    if (kDebugMode) {
      debugPrint('[CrashService] $message');
      return;
    }
    await _crashlytics.log(message);
  }

  /// Özel anahtar-değer çifti ekle (ekran adı, kullanıcı tipi vs.)
  static Future<void> setKey(String key, Object value) async {
    if (kDebugMode) return;
    await _crashlytics.setCustomKey(key, value);
  }
}
