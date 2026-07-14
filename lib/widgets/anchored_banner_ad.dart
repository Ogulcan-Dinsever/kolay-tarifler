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
  BannerAd? _ad;
  int? _loadedWidth;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(int width) async {
    if (_loadedWidth == width || AdConfig.anchoredBannerId == null) return;
    _loadedWidth = width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;

    final previousAd = _ad;
    late final BannerAd nextAd;
    nextAd = BannerAd(
      adUnitId: AdConfig.anchoredBannerId!,
      request: const AdRequest(),
      size: size,
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.truncate();
            if (width > 0 && width != _loadedWidth) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _load(width));
            }
            final ad = _ad;
            // Reklam yüklenirken alanı koru; alt navigasyon zıplamasın.
            if (ad == null) return const SizedBox(height: 58);
            return Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1A000000))),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
