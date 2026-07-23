package com.kolaytarifler.app;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.google.android.gms.ads.nativead.MediaView;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import io.flutter.plugins.googlemobileads.NativeAdFactory;
import java.util.Map;

final class InFeedNativeAdFactory implements NativeAdFactory {
  private static final int MEDIA_SIZE_DP = 120;
  private static final int CARD_HEIGHT_DP = 136;
  private static final int CARD_PADDING_DP = 8;

  private final Context context;

  InFeedNativeAdFactory(Context context) {
    this.context = context;
  }

  @Override
  public NativeAdView createNativeAd(
      NativeAd nativeAd, Map<String, Object> customOptions) {
    final boolean isDark =
        customOptions != null && Boolean.TRUE.equals(customOptions.get("isDark"));
    final int background = Color.parseColor(isDark ? "#1D2D3D" : "#FFFFFF");
    final int primaryText = Color.parseColor(isDark ? "#F3F4F6" : "#172033");
    final int secondaryText = Color.parseColor(isDark ? "#A9B4C3" : "#667085");

    final NativeAdView adView = new NativeAdView(context);
    adView.setLayoutParams(
        new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(CARD_HEIGHT_DP)));
    adView.setBackground(roundedBackground(background));

    final LinearLayout row = new LinearLayout(context);
    row.setOrientation(LinearLayout.HORIZONTAL);
    row.setPadding(dp(CARD_PADDING_DP), dp(CARD_PADDING_DP),
        dp(CARD_PADDING_DP), dp(CARD_PADDING_DP));
    adView.addView(
        row,
        new NativeAdView.LayoutParams(
            NativeAdView.LayoutParams.MATCH_PARENT, dp(CARD_HEIGHT_DP)));

    final MediaView mediaView = new MediaView(context);
    row.addView(mediaView, new LinearLayout.LayoutParams(dp(MEDIA_SIZE_DP), dp(MEDIA_SIZE_DP)));
    adView.setMediaView(mediaView);
    mediaView.setMediaContent(nativeAd.getMediaContent());

    final LinearLayout details = new LinearLayout(context);
    details.setOrientation(LinearLayout.VERTICAL);
    details.setPadding(dp(10), 0, 0, 0);
    row.addView(
        details,
        new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));

    final TextView attribution = textView("Reklam", secondaryText, 10, Typeface.BOLD);
    details.addView(attribution, wrapContent());

    final TextView headline = textView(nativeAd.getHeadline(), primaryText, 15, Typeface.BOLD);
    headline.setMaxLines(1);
    details.addView(headline, wrapContent());
    adView.setHeadlineView(headline);

    final TextView body = textView(nativeAd.getBody(), secondaryText, 12, Typeface.NORMAL);
    body.setMaxLines(2);
    body.setVisibility(nativeAd.getBody() == null ? View.INVISIBLE : View.VISIBLE);
    details.addView(body, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
    adView.setBodyView(body);

    final Button callToAction = new Button(context);
    callToAction.setAllCaps(false);
    callToAction.setText(nativeAd.getCallToAction());
    callToAction.setTextColor(Color.WHITE);
    callToAction.setTextSize(13);
    callToAction.setGravity(Gravity.CENTER);
    callToAction.setMinHeight(0);
    callToAction.setMinimumHeight(0);
    callToAction.setPadding(dp(8), 0, dp(8), 0);
    callToAction.setBackground(roundedBackground(Color.parseColor("#16C86D")));
    callToAction.setVisibility(
        nativeAd.getCallToAction() == null ? View.INVISIBLE : View.VISIBLE);
    details.addView(
        callToAction,
        new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(34)));
    adView.setCallToActionView(callToAction);

    adView.setNativeAd(nativeAd);
    return adView;
  }

  private TextView textView(String value, int color, int sizeSp, int style) {
    final TextView view = new TextView(context);
    view.setText(value == null ? "" : value);
    view.setTextColor(color);
    view.setTextSize(sizeSp);
    view.setTypeface(Typeface.DEFAULT, style);
    return view;
  }

  private LinearLayout.LayoutParams wrapContent() {
    return new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
  }

  private GradientDrawable roundedBackground(int color) {
    final GradientDrawable drawable = new GradientDrawable();
    drawable.setColor(color);
    drawable.setCornerRadius(dp(12));
    return drawable;
  }

  private int dp(int value) {
    return Math.round(value * context.getResources().getDisplayMetrics().density);
  }
}
