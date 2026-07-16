import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/ad_consent_service.dart';

/// A fixed-height banner that sits above the app navigation. It is only shown
/// on routes that contain browseable recipe content.
class AnchoredBannerAd extends StatefulWidget {
  const AnchoredBannerAd({super.key});

  @override
  State<AnchoredBannerAd> createState() => _AnchoredBannerAdState();
}

class _AnchoredBannerAdState extends State<AnchoredBannerAd> {
  static const _bannerSize = AdSize.banner;

  BannerAd? _ad;
  bool _loadStarted = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadStarted || AdConfig.anchoredBannerId == null) return;
    _loadStarted = true;

    final previousAd = _ad;
    late final BannerAd nextAd;
    nextAd = BannerAd(
      adUnitId: AdConfig.anchoredBannerId!,
      request: const AdRequest(),
      size: _bannerSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || ad != nextAd) return;
          setState(() => _ad = ad as BannerAd);
          previousAd?.dispose();
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    await nextAd.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdConsentService.canRequestAdsNotifier,
      builder: (context, canRequestAds, _) {
        if (!canRequestAds || AdConfig.anchoredBannerId == null) {
          return const SizedBox.shrink();
        }
        if (!_loadStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final ad = _ad;
        // Reklam yüklenirken standart banner kadar alanı koru; alt navigasyon
        // zıplamasın ve reklam ekrandan gereksiz yer kaplamasın.
        if (ad == null) {
          return SizedBox(height: _bannerSize.height.toDouble());
        }
        return AnchoredBannerFrame(
          size: ad.size,
          child: AdWidget(ad: ad),
        );
      },
    );
  }
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
