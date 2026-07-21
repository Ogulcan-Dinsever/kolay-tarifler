import 'dart:io';

import 'package:flutter/foundation.dart';
import 'ad_consent_service.dart';

class AdConfig {
  const AdConfig._();

  static const usesTestAds = bool.fromEnvironment('ADMOB_USE_TEST_ADS');

  // AnchoredBannerAd renders the fixed 320x50 AdSize.banner creative. Keep
  // these IDs paired with that format; the adaptive-banner sample units are
  // a different inventory type and can fail to fill on iOS.
  static const _androidTestBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidTestNativeId = 'ca-app-pub-3940256099942544/2247696110';
  static const _iosTestNativeId = 'ca-app-pub-3940256099942544/3986624511';

  static const _androidReleaseBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-1746933154428344/9848805510',
  );
  static const _iosReleaseBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: 'ca-app-pub-1746933154428344/9045794078',
  );
  static const _androidReleaseNativeId = String.fromEnvironment(
    'ADMOB_ANDROID_NATIVE_ID',
    defaultValue: 'ca-app-pub-1746933154428344/2107924599',
  );
  static const _iosReleaseNativeId = String.fromEnvironment(
    'ADMOB_IOS_NATIVE_ID',
    defaultValue: 'ca-app-pub-1746933154428344/1367622794',
  );

  /// Debug builds always use Google's test units. Release builds render no ad
  /// until a real unit ID is supplied at build time.
  static String? get anchoredBannerId {
    if (kIsWeb) return null;
    if (kDebugMode || usesTestAds) {
      return Platform.isAndroid
          ? _androidTestBannerId
          : Platform.isIOS
          ? _iosTestBannerId
          : null;
    }
    if (!AdConsentService.canRequestAds) return null;
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

  /// Native advanced unit used between recipe cards.
  ///
  /// Debug and explicit test-ad builds always use Google's sample units so
  /// development traffic can never create invalid activity on the live units.
  static String? get inFeedNativeId {
    if (kIsWeb) return null;
    if (kDebugMode || usesTestAds) {
      return Platform.isAndroid
          ? _androidTestNativeId
          : Platform.isIOS
          ? _iosTestNativeId
          : null;
    }
    if (!AdConsentService.canRequestAds) return null;
    return Platform.isAndroid
        ? _androidReleaseNativeId.isEmpty
              ? null
              : _androidReleaseNativeId
        : Platform.isIOS
        ? _iosReleaseNativeId.isEmpty
              ? null
              : _iosReleaseNativeId
        : null;
  }
}
