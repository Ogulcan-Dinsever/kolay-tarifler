import 'dart:io';

import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const _androidTestBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const _iosTestBannerId = 'ca-app-pub-3940256099942544/2435281174';

  static const _androidReleaseBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosReleaseBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );

  /// Debug builds always use Google's test units. Release builds render no ad
  /// until a real unit ID is supplied at build time.
  static String? get anchoredBannerId {
    if (kIsWeb) return null;
    if (kDebugMode) {
      return Platform.isAndroid
          ? _androidTestBannerId
          : Platform.isIOS
          ? _iosTestBannerId
          : null;
    }
    return Platform.isAndroid
        ? _androidReleaseBannerId.isEmpty
              ? null
              : _androidReleaseBannerId
        : Platform.isIOS
        ? _iosReleaseBannerId.isEmpty
              ? null
              : _iosReleaseBannerId
        : null;
  }
}
