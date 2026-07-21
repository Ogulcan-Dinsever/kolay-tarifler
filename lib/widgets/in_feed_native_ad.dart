import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/theme/app_colors.dart';
import '../services/ad_config.dart';
import '../services/ad_consent_service.dart';
import '../services/crash_service.dart';

sealed class InFeedEntry<T> {
  const InFeedEntry();
}

final class InFeedContent<T> extends InFeedEntry<T> {
  const InFeedContent(this.item, this.contentIndex);

  final T item;
  final int contentIndex;
}

final class InFeedAdSlot<T> extends InFeedEntry<T> {
  const InFeedAdSlot(this.slotIndex);

  final int slotIndex;
}

/// Inserts the first ad after five cards and another after every ten cards.
/// The recipe order is never changed.
List<InFeedEntry<T>> buildInFeedEntries<T>(
  List<T> items, {
  int firstAdAfter = 5,
  int interval = 10,
}) {
  assert(firstAdAfter > 0);
  assert(interval > 0);
  final entries = <InFeedEntry<T>>[];
  var adSlot = 0;
  for (var index = 0; index < items.length; index++) {
    entries.add(InFeedContent(items[index], index));
    final shown = index + 1;
    if (shown >= firstAdAfter && (shown - firstAdAfter) % interval == 0) {
      entries.add(InFeedAdSlot(adSlot++));
    }
  }
  return entries;
}

/// A compact AdMob native advanced ad designed to sit between recipe cards.
class InFeedNativeAd extends StatefulWidget {
  const InFeedNativeAd({super.key});

  @override
  State<InFeedNativeAd> createState() => _InFeedNativeAdState();
}

class _InFeedNativeAdState extends State<InFeedNativeAd>
    with WidgetsBindingObserver {
  static const _height = 112.0;
  static const _maxBackoffAttempt = 5;

  final _random = Random();
  NativeAd? _ad;
  NativeAd? _loadingAd;
  Timer? _retryTimer;
  bool _loading = false;
  bool _isAppActive = true;
  int _failedAttempts = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _isAppActive = state == null || state == AppLifecycleState.resumed;
    AdConsentService.canRequestAdsNotifier.addListener(_onConsentChanged);
    unawaited(AdConsentService.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdConsentService.canRequestAdsNotifier.removeListener(_onConsentChanged);
    _generation++;
    _retryTimer?.cancel();
    _loadingAd?.dispose();
    _ad?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (!_isAppActive) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    unawaited(AdConsentService.initialize());
    _requestLoad();
  }

  void _onConsentChanged() {
    if (!AdConsentService.canRequestAds) {
      _generation++;
      _retryTimer?.cancel();
      _retryTimer = null;
      _loadingAd?.dispose();
      _loadingAd = null;
      _ad?.dispose();
      _ad = null;
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    _requestLoad();
  }

  void _requestLoad() {
    if (!mounted ||
        !_isAppActive ||
        !AdConsentService.canRequestAds ||
        _loading ||
        _ad != null ||
        _retryTimer != null) {
      return;
    }
    final adUnitId = AdConfig.inFeedNativeId;
    if (adUnitId == null) return;

    _loading = true;
    final generation = ++_generation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final NativeAd nextAd;
    nextAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: isDark ? AppColors.darkCard : Colors.white,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark ? AppColors.darkText : AppColors.lightText,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
          size: 11,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (_loadingAd == nextAd) _loadingAd = null;
          if (!mounted ||
              generation != _generation ||
              !AdConsentService.canRequestAds) {
            ad.dispose();
            return;
          }
          _retryTimer?.cancel();
          setState(() {
            _ad = ad as NativeAd;
            _loading = false;
            _failedAttempts = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (_loadingAd == nextAd) _loadingAd = null;
          ad.dispose();
          _handleFailure(generation, error);
        },
      ),
    );
    _loadingAd = nextAd;
    nextAd.load().catchError((Object error) {
      if (_loadingAd == nextAd) _loadingAd = null;
      nextAd.dispose();
      _handleFailure(generation, error);
    });
  }

  void _handleFailure(int generation, Object error) {
    if (!mounted || generation != _generation || !_loading) return;
    _failedAttempts = min(_failedAttempts + 1, _maxBackoffAttempt);
    _loading = false;
    debugPrint('Native ad failed to load (attempt $_failedAttempts): $error');
    unawaited(_recordFailure(error));
    final delay =
        inFeedNativeRetryDelay(_failedAttempts) +
        Duration(milliseconds: _random.nextInt(2001));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _requestLoad();
    });
  }

  Future<void> _recordFailure(Object error) async {
    try {
      await CrashService.setKey(
        'native_ad_platform',
        defaultTargetPlatform.name,
      );
      await CrashService.setKey('native_ad_load_attempt', _failedAttempts);
      await CrashService.setKey(
        'native_ad_uses_test_unit',
        AdConfig.usesTestAds,
      );
      if (error is LoadAdError) {
        await CrashService.setKey('native_ad_error_code', error.code);
        await CrashService.setKey('native_ad_error_domain', error.domain);
        await CrashService.setKey('native_ad_error_message', error.message);
      }
      await CrashService.recordError(
        error,
        StackTrace.current,
        context: 'in_feed_native_ad_load_failed',
      );
    } catch (_) {
      // Diagnostics must never interfere with ad loading.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdConsentService.canRequestAdsNotifier,
      builder: (context, canRequestAds, _) {
        if (!canRequestAds || AdConfig.inFeedNativeId == null) {
          return const SizedBox.shrink();
        }
        if (_ad == null && !_loading && _retryTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _requestLoad());
        }
        final ad = _ad;
        if (ad == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: double.infinity,
                height: _height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AdWidget(ad: ad),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

@visibleForTesting
Duration inFeedNativeRetryDelay(int failedAttempts) => switch (failedAttempts) {
  <= 1 => const Duration(seconds: 10),
  2 => const Duration(seconds: 30),
  3 => const Duration(minutes: 1),
  4 => const Duration(minutes: 2),
  _ => const Duration(minutes: 5),
};
