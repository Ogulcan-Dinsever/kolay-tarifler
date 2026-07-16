import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kolay_tarifler/widgets/anchored_banner_ad.dart';

void main() {
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
}
