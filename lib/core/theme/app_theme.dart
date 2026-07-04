import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      secondary: AppColors.accent,
      outline: AppColors.lightBorder,
    ),
    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      bodyLarge: GoogleFonts.nunito(color: AppColors.lightText),
      bodyMedium: GoogleFonts.nunito(color: AppColors.lightText),
      bodySmall: GoogleFonts.nunito(color: AppColors.lightTextTertiary),
    ),
    dividerColor: AppColors.lightBorder,
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withValues(alpha: 0.06),
    ),
    extensions: const [
      AppPalette(
        card: AppColors.lightCard,
        border: AppColors.lightBorder,
        textPrimary: AppColors.lightText,
        textSecondary: AppColors.lightTextSecondary,
        textTertiary: AppColors.lightTextTertiary,
        g50: AppColors.lightG50,
        g100: AppColors.lightG100,
        g200: AppColors.lightG200,
      ),
    ],
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      secondary: AppColors.accent,
      outline: AppColors.darkBorder,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyLarge: GoogleFonts.nunito(color: AppColors.darkText),
      bodyMedium: GoogleFonts.nunito(color: AppColors.darkText),
      bodySmall: GoogleFonts.nunito(color: AppColors.darkTextTertiary),
    ),
    dividerColor: AppColors.darkBorder,
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: const [
      AppPalette(
        card: AppColors.darkCard,
        border: AppColors.darkBorder,
        textPrimary: AppColors.darkText,
        textSecondary: AppColors.darkTextSecondary,
        textTertiary: AppColors.darkTextTertiary,
        g50: AppColors.darkG50,
        g100: AppColors.darkG100,
        g200: AppColors.darkG200,
      ),
    ],
  );
}

class AppPalette extends ThemeExtension<AppPalette> {
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color g50;
  final Color g100;
  final Color g200;

  const AppPalette({
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.g50,
    required this.g100,
    required this.g200,
  });

  @override
  AppPalette copyWith({
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? g50,
    Color? g100,
    Color? g200,
  }) {
    return AppPalette(
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      g50: g50 ?? this.g50,
      g100: g100 ?? this.g100,
      g200: g200 ?? this.g200,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      g50: Color.lerp(g50, other.g50, t)!,
      g100: Color.lerp(g100, other.g100, t)!,
      g200: Color.lerp(g200, other.g200, t)!,
    );
  }
}

extension ThemeHelpers on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
