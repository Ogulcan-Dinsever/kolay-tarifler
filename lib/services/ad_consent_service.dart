import 'dart:async';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'crash_service.dart';

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
  static bool _mobileAdsInitializationStarted = false;
  static Timer? _initializationRetryTimer;
  static int _initializationFailures = 0;

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
    _initializationRetryTimer?.cancel();
    _initializationRetryTimer = null;
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
      await runAdPrivacyFlowBeforeAds(
        requestTrackingPermission: _requestTrackingPermissionIfNeeded,
        requestConsent: _requestConsentAndRefresh,
      );
      await _activateAdsIfAllowed();
      _initialized = true;
    } catch (error, stack) {
      canRequestAdsNotifier.value = false;
      _initializationFailures += 1;
      _scheduleInitializationRetry();
      unawaited(_recordInitializationFailure(error, stack));
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _requestConsentAndRefresh() async {
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
  }

  static void _scheduleInitializationRetry() {
    if (_initializationRetryTimer != null) return;
    final delay = switch (_initializationFailures) {
      <= 1 => const Duration(seconds: 5),
      2 => const Duration(seconds: 15),
      3 => const Duration(seconds: 30),
      _ => const Duration(minutes: 1),
    };
    _initializationRetryTimer = Timer(delay, () {
      _initializationRetryTimer = null;
      if (_consentAllowsAds) {
        _startMobileAdsInitialization();
      } else {
        unawaited(initialize());
      }
    });
  }

  static Future<void> _recordInitializationFailure(
    Object error,
    StackTrace stack,
  ) async {
    try {
      await CrashService.setKey(
        'ad_sdk_initialization_failures',
        _initializationFailures,
      );
      await CrashService.setKey('ad_sdk_test_mode', _usesTestAdsWithoutConsent);
      await CrashService.recordError(
        error,
        stack,
        context: 'mobile_ads_initialization_failed',
      );
    } catch (_) {
      // Diagnostics must never block the SDK retry path.
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
    // Google requires the Mobile Ads SDK to finish initialization before the
    // first ad is loaded. Android often tolerates an early request, while iOS
    // can reject it during scene/controller setup. Keep the request gate shut
    // until initialization completes; the widgets react to the notifier and
    // load immediately afterwards.
    if (_mobileAdsInitialized) {
      canRequestAdsNotifier.value = true;
      return;
    }
    _startMobileAdsInitialization();
  }

  static void _startMobileAdsInitialization() {
    if (_mobileAdsInitialized || _mobileAdsInitializationStarted) return;
    _mobileAdsInitializationStarted = true;
    unawaited(_initializeMobileAds());
  }

  static Future<void> _initializeMobileAds() async {
    try {
      await enableAdRequestsAfterSdkInitialization(
        notifier: canRequestAdsNotifier,
        initializeSdk: () async {
          await MobileAds.instance.initialize();
        },
      );
      _mobileAdsInitialized = true;
      _initializationFailures = 0;
      unawaited(_logInitializationSuccess());
    } catch (error, stack) {
      _mobileAdsInitializationStarted = false;
      _initializationFailures += 1;
      _scheduleInitializationRetry();
      unawaited(_recordInitializationFailure(error, stack));
    }
  }

  static Future<void> _logInitializationSuccess() async {
    try {
      await CrashService.log('Google Mobile Ads SDK initialized');
    } catch (_) {
      // Ad delivery must not depend on diagnostics availability.
    }
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

/// Runs Apple's system tracking authorization before any Google consent UI.
///
/// App Review rejects a Google/custom consent prompt shown before ATT because
/// it appears to replace the system tracking authorization request.
@visibleForTesting
Future<void> runAdPrivacyFlowBeforeAds({
  required Future<void> Function() requestTrackingPermission,
  required Future<void> Function() requestConsent,
}) async {
  await requestTrackingPermission();
  await requestConsent();
}

/// Test reklamları kişiselleştirilmiş reklam verisi kullanmaz. Debug ve
/// TestFlight test-ad derlemelerinde UMP/ATT formunu beklemeden SDK'yı açar.
@visibleForTesting
bool shouldBypassAdConsentForTestAds({
  required bool isDebugBuild,
  required bool buildUsesTestAds,
}) => isDebugBuild || buildUsesTestAds;

/// Opens the request gate only after Google Mobile Ads has initialized.
///
/// Kept as a seam so the iOS initialization ordering cannot regress silently.
@visibleForTesting
Future<void> enableAdRequestsAfterSdkInitialization({
  required ValueNotifier<bool> notifier,
  required Future<void> Function() initializeSdk,
}) async {
  notifier.value = false;
  await initializeSdk();
  notifier.value = true;
}
