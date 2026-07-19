import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kolay_tarifler/services/ad_consent_service.dart';
import 'package:kolay_tarifler/widgets/anchored_banner_ad.dart';

void main() {
  setUp(() {
    AdConsentService.canRequestAdsNotifier.value = true;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AdConsentService.canRequestAdsNotifier.value = false;
  });

  test('banner retry uses capped backoff delays', () {
    expect(anchoredBannerRetryDelay(1), const Duration(seconds: 5));
    expect(anchoredBannerRetryDelay(2), const Duration(seconds: 15));
    expect(anchoredBannerRetryDelay(3), const Duration(seconds: 30));
    expect(anchoredBannerRetryDelay(4), const Duration(minutes: 1));
    expect(anchoredBannerRetryDelay(5), const Duration(minutes: 2));
    expect(anchoredBannerRetryDelay(20), const Duration(minutes: 5));
  });

  testWidgets('banner frame adds no height beyond the AdMob creative', (
    tester,
  ) async {
    const creativeKey = Key('banner-creative');
    const frameKey = Key('banner-frame');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AnchoredBannerFrame(
              key: frameKey,
              size: AdSize.banner,
              child: ColoredBox(key: creativeKey, color: Colors.blue),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(frameKey)).height, AdSize.banner.height);
    expect(tester.getSize(find.byKey(creativeKey)), const Size(320, 50));
  });

  testWidgets('failed banner collapses then retries after backoff', (
    tester,
  ) async {
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(loader.loadCount, 1);
    expect(tester.getSize(find.byType(AnchoredBannerAd)).height, 50);

    loader.failCurrent();
    await tester.pump();
    expect(tester.getSize(find.byType(AnchoredBannerAd)).height, 0);

    await tester.pump(const Duration(seconds: 4));
    expect(loader.loadCount, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(loader.loadCount, 2);
  });

  testWidgets('revoked consent cancels a pending banner retry', (tester) async {
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    loader.failCurrent();
    await tester.pump();

    AdConsentService.canRequestAdsNotifier.value = false;
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));

    expect(loader.loadCount, 1);
    expect(tester.getSize(find.byType(AnchoredBannerAd)).height, 0);
  });

  testWidgets('synchronous load exception also schedules a retry', (
    tester,
  ) async {
    var loadCount = 0;
    Future<void> throwingLoader({
      required String adUnitId,
      required AdSize size,
      required ValueChanged<BannerAd> onLoaded,
      required ValueChanged<Object> onFailed,
    }) async {
      loadCount += 1;
      throw StateError('platform channel unavailable');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: throwingLoader,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(loadCount, 1);
    expect(tester.getSize(find.byType(AnchoredBannerAd)).height, 0);

    await tester.pump(const Duration(seconds: 5));
    expect(loadCount, 2);
  });

  testWidgets('invalid request errors are not retried', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(milliseconds: 1),
          ),
        ),
      ),
    );
    await tester.pump();
    loader.failCurrent(_TestLoadAdError(1));
    await tester.pump();
    await tester.pump(const Duration(minutes: 10));

    expect(loader.loadCount, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('transient failures keep retrying with a capped backoff tier', (
    tester,
  ) async {
    final loader = _ControlledBannerLoader();
    final retryAttempts = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (attempt, _) {
              retryAttempts.add(attempt);
              return const Duration(milliseconds: 1);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    for (var attempt = 1; attempt <= 6; attempt += 1) {
      loader.failCurrent();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump(const Duration(minutes: 10));

    expect(loader.loadCount, 7);
    expect(retryAttempts, <int>[1, 2, 3, 4, 5, 6]);
  });

  testWidgets('iOS no-fill response is retried with backoff', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();

    loader.failCurrent(_TestLoadAdError(1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(loader.loadCount, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS invalid request is not retried', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();

    loader.failCurrent(_TestLoadAdError(0));
    await tester.pump();
    await tester.pump(const Duration(minutes: 10));

    expect(loader.loadCount, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('disposing the widget cancels a pending retry', (tester) async {
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    loader.failCurrent();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));

    expect(loader.loadCount, 1);
  });

  testWidgets('backgrounding pauses retries until the app resumes', (
    tester,
  ) async {
    final loader = _ControlledBannerLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredBannerAd.test(
            adUnitIdOverride: 'test-banner',
            loadStarter: loader.load,
            retryDelay: (_, _) => const Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    loader.failCurrent();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(loader.loadCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(loader.loadCount, 2);
  });
}

class _ControlledBannerLoader {
  int loadCount = 0;
  ValueChanged<Object>? _onFailed;

  Future<void> load({
    required String adUnitId,
    required AdSize size,
    required ValueChanged<BannerAd> onLoaded,
    required ValueChanged<Object> onFailed,
  }) async {
    loadCount += 1;
    _onFailed = onFailed;
  }

  void failCurrent([Object? error]) {
    _onFailed?.call(error ?? StateError('no fill'));
  }
}

class _TestLoadAdError extends LoadAdError {
  _TestLoadAdError(int code) : super(code, 'test', 'test error', null);
}
