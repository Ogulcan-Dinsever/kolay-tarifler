import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/ad_consent_service.dart';

/// Starts one banner load and reports its terminal callback.
///
/// This seam lets widget tests drive AdMob success and failure paths without a
/// platform channel.
typedef AnchoredBannerLoadStarter =
    Future<void> Function({
      required String adUnitId,
      required AdSize size,
      required ValueChanged<BannerAd> onLoaded,
      required ValueChanged<Object> onFailed,
    });

/// Computes the delay before the next banner request in widget tests.
typedef AnchoredBannerRetryDelay =
    Duration Function(int failedAttempts, Object error);

/// A fixed-height banner that sits above app navigation on non-admin shell
/// routes.
class AnchoredBannerAd extends StatefulWidget {
  const AnchoredBannerAd({super.key})
    : adUnitIdOverride = null,
      loadStarter = null,
      retryDelay = null;

  /// Creates a banner with injectable loading and retry behavior for tests.
  @visibleForTesting
  const AnchoredBannerAd.test({
    super.key,
    required this.adUnitIdOverride,
    required this.loadStarter,
    this.retryDelay,
  });

  /// Overrides the production AdMob unit identifier in tests.
  final String? adUnitIdOverride;

  /// Replaces the native Google Mobile Ads loader in tests.
  final AnchoredBannerLoadStarter? loadStarter;

  /// Replaces the production retry schedule in tests.
  final AnchoredBannerRetryDelay? retryDelay;

  @override
  State<AnchoredBannerAd> createState() => _AnchoredBannerAdState();
}

class _AnchoredBannerAdState extends State<AnchoredBannerAd>
    with WidgetsBindingObserver {
  static const _bannerSize = AdSize.banner;
  static const _maxBackoffAttempt = 6;

  final Random _random = Random();
  BannerAd? _ad;
  Timer? _retryTimer;
  BannerAd? _loadingAd;
  bool _loadInProgress = false;
  bool _hasLoadFailed = false;
  bool _isAppActive = true;
  int _failedAttempts = 0;
  int _loadGeneration = 0;

  String? get _adUnitId => widget.adUnitIdOverride ?? AdConfig.anchoredBannerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    AdConsentService.canRequestAdsNotifier.addListener(_handleConsentChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdConsentService.canRequestAdsNotifier.removeListener(
      _handleConsentChanged,
    );
    _retryTimer?.cancel();
    _loadingAd?.dispose();
    _ad?.dispose();
    super.dispose();
  }

  void _handleConsentChanged() {
    if (AdConsentService.canRequestAds) return;
    _cancelPendingLoad(disposeLoadedAd: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    if (_isAppActive == isResumed) return;
    _isAppActive = isResumed;
    if (!isResumed) {
      _cancelPendingLoad(disposeLoadedAd: false);
      return;
    }
    if (mounted &&
        AdConsentService.canRequestAds &&
        _ad == null &&
        !_loadInProgress) {
      setState(() => _hasLoadFailed = false);
    }
  }

  void _cancelPendingLoad({required bool disposeLoadedAd}) {
    _loadGeneration += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    _loadingAd?.dispose();
    _loadingAd = null;
    if (disposeLoadedAd) {
      _ad?.dispose();
      _ad = null;
    }
    _loadInProgress = false;
    _hasLoadFailed = false;
    _failedAttempts = 0;
  }

  Future<void> _load() async {
    if (!mounted) return;
    final adUnitId = _adUnitId;
    if (!_isAppActive ||
        !AdConsentService.canRequestAds ||
        _ad != null ||
        _loadInProgress ||
        adUnitId == null) {
      return;
    }
    _loadInProgress = true;
    final generation = ++_loadGeneration;

    try {
      final starter = widget.loadStarter ?? _startGoogleBannerLoad;
      await starter(
        adUnitId: adUnitId,
        size: _bannerSize,
        onLoaded: (ad) => _handleAdLoaded(generation, ad),
        onFailed: (error) => _handleLoadFailure(generation, error),
      );
    } catch (error) {
      _handleLoadFailure(generation, error);
    }
  }

  Future<void> _startGoogleBannerLoad({
    required String adUnitId,
    required AdSize size,
    required ValueChanged<BannerAd> onLoaded,
    required ValueChanged<Object> onFailed,
  }) async {
    late final BannerAd nextAd;
    nextAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_loadingAd == nextAd) _loadingAd = null;
          onLoaded(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          if (_loadingAd == nextAd) _loadingAd = null;
          ad.dispose();
          onFailed(error);
        },
      ),
    );
    _loadingAd = nextAd;
    try {
      await nextAd.load();
    } catch (_) {
      if (_loadingAd == nextAd) _loadingAd = null;
      nextAd.dispose();
      rethrow;
    }
  }

  void _handleAdLoaded(int generation, BannerAd ad) {
    if (!mounted ||
        generation != _loadGeneration ||
        !AdConsentService.canRequestAds) {
      ad.dispose();
      return;
    }
    _retryTimer?.cancel();
    setState(() {
      _ad = ad;
      _loadInProgress = false;
      _hasLoadFailed = false;
      _failedAttempts = 0;
    });
  }

  void _handleLoadFailure(int generation, Object error) {
    if (!mounted || generation != _loadGeneration || !_loadInProgress) return;
    _failedAttempts = min(_failedAttempts + 1, _maxBackoffAttempt);
    debugPrint('Banner ad failed to load (attempt $_failedAttempts): $error');
    setState(() {
      _loadInProgress = false;
      _hasLoadFailed = true;
    });
    if (_shouldRetry(error)) _scheduleRetry(error);
  }

  bool _shouldRetry(Object error) {
    if (error is! LoadAdError) return true;

    // Google Mobile Ads uses different numeric error mappings on Android and
    // iOS. Code 1 is invalid-request on Android but ordinary no-fill on iOS.
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => error.code != 1 && error.code != 8,
      TargetPlatform.iOS => error.code != 0,
      _ => true,
    };
  }

  void _scheduleRetry(Object error) {
    _retryTimer?.cancel();
    final delay =
        widget.retryDelay?.call(_failedAttempts, error) ??
        anchoredBannerRetryDelay(_failedAttempts) +
            Duration(milliseconds: _random.nextInt(2501));
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && _isAppActive && AdConsentService.canRequestAds) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdConsentService.canRequestAdsNotifier,
      builder: (context, canRequestAds, _) {
        if (!canRequestAds || _adUnitId == null) {
          return const SizedBox.shrink();
        }
        if (_ad == null &&
            !_loadInProgress &&
            !_hasLoadFailed &&
            _retryTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load();
          });
        }
        final ad = _ad;
        // Reklam yüklenirken standart banner kadar alanı koru; alt navigasyon
        // zıplamasın ve reklam ekrandan gereksiz yer kaplamasın.
        if (ad == null && !_hasLoadFailed) {
          return SizedBox(height: _bannerSize.height.toDouble());
        }
        if (ad == null) return const SizedBox.shrink();
        return AnchoredBannerFrame(
          size: ad.size,
          child: AdWidget(ad: ad),
        );
      },
    );
  }
}

/// Backoff used after a banner request is not filled or fails transiently.
///
/// The delay is capped so the banner can recover during the same app session
/// without hammering AdMob when inventory or connectivity is unavailable.
@visibleForTesting
Duration anchoredBannerRetryDelay(int failedAttempts) {
  return switch (failedAttempts) {
    <= 1 => const Duration(seconds: 5),
    2 => const Duration(seconds: 15),
    3 => const Duration(seconds: 30),
    4 => const Duration(minutes: 1),
    5 => const Duration(minutes: 2),
    _ => const Duration(minutes: 5),
  };
}

/// Keeps the banner slot exactly as tall as the creative supplied by AdMob.
///
/// Public so the layout contract can be covered by a widget regression test.
class AnchoredBannerFrame extends StatelessWidget {
  const AnchoredBannerFrame({
    super.key,
    required this.size,
    required this.child,
  });

  final AdSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.height.toDouble(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x1A000000))),
        ),
        child: Center(
          child: SizedBox(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
            child: child,
          ),
        ),
      ),
    );
  }
}
