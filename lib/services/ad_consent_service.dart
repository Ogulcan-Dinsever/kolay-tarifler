import 'dart:async';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  AdConsentService._();

  static const _buildUsesTestAds = bool.fromEnvironment('ADMOB_USE_TEST_ADS');

  static final ValueNotifier<bool> canRequestAdsNotifier = ValueNotifier(false);
  static bool get canRequestAds => canRequestAdsNotifier.value;
  static bool privacyOptionsRequired = false;
  static bool _initializing = false;
  static bool _initialized = false;
  static bool _consentAllowsAds = false;
  static bool _mobileAdsInitialized = false;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _usesTestAdsWithoutConsent => shouldBypassAdConsentForTestAds(
    isDebugBuild: kDebugMode,
    buildUsesTestAds: _buildUsesTestAds,
  );

  static Future<void> initialize() async {
    if (!_isMobile || _initialized || _initializing) return;
    _initializing = true;
    try {
      // Debug sürümü yalnız Google test reklamı kullanır. UMP test coğrafyası ve
      // AdMob mesajı ayrıca yapılandırılmadan emülatörde boş bir form açılmasın.
      if (_usesTestAdsWithoutConsent) {
        _consentAllowsAds = true;
        await _activateAdsIfAllowed();
        _initialized = true;
        return;
      }
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: false),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) async {
            await _refreshStatus();
            if (!completer.isCompleted) completer.complete();
          });
        },
        (_) async {
          // Önceki oturumda geçerli izin varsa geçici ağ hatasında kullanılabilir.
          await _refreshStatus();
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
      await _activateAdsIfAllowed();
      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _activateAdsIfAllowed() async {
    if (!_consentAllowsAds) {
      canRequestAdsNotifier.value = false;
      return;
    }
    // ATT reddedilirse Google Mobile Ads IDFA göndermeden reklam istemeye
    // devam eder. UMP seçimi de kişiselleştirilmiş / kişiselleştirilmemiş /
    // sınırlı reklam sunum modunu belirler.
    if (!_usesTestAdsWithoutConsent) {
      await _requestTrackingPermissionIfNeeded();
    }
    if (!_mobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
    }
    // Banner ancak SDK tamamen hazır olduğunda yükleme isteği gönderebilir.
    canRequestAdsNotifier.value = true;
  }

  static Future<void> _requestTrackingPermissionIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {
      // ATT kullanılamıyorsa reklamlar IDFA olmadan çalışmaya devam eder.
    }
  }

  static Future<void> _refreshStatus() async {
    _consentAllowsAds = await ConsentInformation.instance.canRequestAds();
    privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  static Future<FormError?> showPrivacyOptions() async {
    if (!_isMobile) return null;
    final completer = Completer<FormError?>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (!completer.isCompleted) completer.complete(error);
    });
    final result = await completer.future;
    await _refreshStatus();
    await _activateAdsIfAllowed();
    return result;
  }
}

/// Test reklamları kişiselleştirilmiş reklam verisi kullanmaz. Debug ve
/// TestFlight test-ad derlemelerinde UMP/ATT formunu beklemeden SDK'yı açar.
@visibleForTesting
bool shouldBypassAdConsentForTestAds({
  required bool isDebugBuild,
  required bool buildUsesTestAds,
}) => isDebugBuild || buildUsesTestAds;
