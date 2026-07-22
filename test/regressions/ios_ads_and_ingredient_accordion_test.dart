import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/providers/ingredient_selection_provider.dart';
import 'package:kolay_tarifler/services/ad_consent_service.dart';

void main() {
  test('malzeme akordeonu ilk açılışta kapalıdır', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(expandedIngredientCategoryProvider), isNull);
  });

  test('TestFlight test reklamı izin formunu beklemeden başlayabilir', () {
    expect(
      shouldBypassAdConsentForTestAds(
        isDebugBuild: false,
        buildUsesTestAds: true,
      ),
      isTrue,
    );
    expect(
      shouldBypassAdConsentForTestAds(
        isDebugBuild: false,
        buildUsesTestAds: false,
      ),
      isFalse,
    );
  });

  test('reklam isteği SDK başlatması tamamlanana kadar kapalı kalır', () async {
    final notifier = ValueNotifier(false);
    addTearDown(notifier.dispose);
    final initialization = Completer<void>();

    final activation = enableAdRequestsAfterSdkInitialization(
      notifier: notifier,
      initializeSdk: () => initialization.future,
    );

    expect(notifier.value, isFalse);
    initialization.complete();
    await activation;
    expect(notifier.value, isTrue);
  });

  test('Codemagic TestFlight derlemesi sabit iOS test bannerını kullanır', () {
    final yaml = File('codemagic.yaml').readAsStringSync();
    final adConfig = File('lib/services/ad_config.dart').readAsStringSync();

    expect(yaml, contains('use_test_ads:'));
    expect(yaml, contains('default: "true"'));
    expect(yaml, contains('ADMOB_USE_TEST_ADS=true'));
    expect(adConfig, contains('kDebugMode || usesTestAds'));
    expect(adConfig, contains('ca-app-pub-3940256099942544/2934735716'));
    expect(adConfig, isNot(contains('ca-app-pub-3940256099942544/2435281174')));
    expect(
      yaml,
      contains('ADMOB_APP_ID=ca-app-pub-3940256099942544~1458002511'),
    );
    expect(yaml, contains('Verified archived AdMob app ID:'));
  });
}
