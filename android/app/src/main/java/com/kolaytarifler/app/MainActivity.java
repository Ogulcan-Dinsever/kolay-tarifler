package com.kolaytarifler.app;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

public class MainActivity extends FlutterActivity {
  private static final String NATIVE_AD_FACTORY_ID = "inFeed";

  @Override
  public void configureFlutterEngine(FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GoogleMobileAdsPlugin.registerNativeAdFactory(
        flutterEngine, NATIVE_AD_FACTORY_ID, new InFeedNativeAdFactory(this));
  }

  @Override
  public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, NATIVE_AD_FACTORY_ID);
    super.cleanUpFlutterEngine(flutterEngine);
  }
}
