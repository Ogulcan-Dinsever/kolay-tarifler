import 'package:flutter/material.dart';

// Tasarım referans boyutu — orta seviye Android telefon
const _kBaseW = 390.0;
const _kBaseH = 844.0;

extension ResponsiveExt on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenW => screenSize.width;
  double get screenH => screenSize.height;

  // 390px baz alınarak ölçekleme faktörü
  double get _sw => (screenW / _kBaseW).clamp(0.72, 1.25);
  double get _sh => (screenH / _kBaseH).clamp(0.72, 1.25);

  bool get isSmallScreen => screenW < 360 || screenH < 660;
  bool get isTinyScreen => screenW < 320 || screenH < 568;

  /// Font boyutu — ekran genişliğine orantılı
  double sp(double size) => size * _sw;

  /// Genel boyut (padding, margin, ikon) — genişlik bazlı
  double rs(double size) => size * _sw;

  /// Yükseklik bazlı boyut (kart yüksekliği vb.)
  double rh(double size) => size * _sh;

  /// Yatay padding — küçük ekranda azalır
  EdgeInsets get hPad => EdgeInsets.symmetric(horizontal: rs(16));

  /// Dikey padding — küçük ekranda azalır
  EdgeInsets rPad({
    double h = 16,
    double v = 12,
    double? top,
    double? bottom,
  }) =>
      EdgeInsets.fromLTRB(
        rs(h),
        top != null ? rs(top) : rs(v),
        rs(h),
        bottom != null ? rs(bottom) : rs(v),
      );
}
