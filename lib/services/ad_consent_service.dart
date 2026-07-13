import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  AdConsentService._();

  static final ValueNotifier<bool> canRequestAdsNotifier = ValueNotifier(false);
  static bool get canRequestAds => canRequestAdsNotifier.value;
  static bool privacyOptionsRequired = false;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (!_isMobile) return;
    // Debug sürümü yalnız Google test reklamı kullanır. UMP test coğrafyası ve
    // AdMob mesajı ayrıca yapılandırılmadan emülatörde boş bir form açılmasın.
    if (kDebugMode) {
      canRequestAdsNotifier.value = true;
      await MobileAds.instance.initialize();
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
    if (canRequestAds) await MobileAds.instance.initialize();
  }

  static Future<void> _refreshStatus() async {
    canRequestAdsNotifier.value = await ConsentInformation.instance
        .canRequestAds();
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
    return result;
  }
}
