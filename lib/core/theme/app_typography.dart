import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// MetaPOS Typography Tokens.
///
/// Dual-font typography hierarchy:
/// - Latin alphanumeric & prices: `Plus Jakarta Sans`
/// - Bengali literature & labels: `Hind Siliguri` (fallback: `Noto Sans Bengali`)
///
/// Type scale:
/// - Display (Total Due / Banner): 32sp SemiBold (1.2 line height)
/// - Heading 1: 22sp Bold (1.3 line height)
/// - Heading 2: 18sp SemiBold (1.3 line height)
/// - Body Regular: 14sp Regular (1.4 line height)
/// - Body Medium: 14sp Medium (1.4 line height)
/// - Caption: 12sp Medium (1.2 line height)
/// - Keypad Digit: 24sp SemiBold (1.0 line height)
abstract final class AppTypography {
  static const String latinFontFamily = 'Plus Jakarta Sans';
  static const String bengaliFontFamily = 'Hind Siliguri';
  static const List<String> bengaliFallbacks = <String>[
    'Hind Siliguri',
    'Noto Sans Bengali',
  ];

  /// Toggle for GoogleFonts dynamic font fetching. Enabled by default in production,
  /// but can be set to false in headless unit tests to avoid network calls.
  static bool enableGoogleFonts = true;

  static TextStyle _buildStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
    bool isBengali = false,
  }) {
    if (enableGoogleFonts) {
      return isBengali
          ? GoogleFonts.hindSiliguri(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: height,
              color: color,
            )
          : GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: height,
              color: color,
            );
    }
    return TextStyle(
      fontFamily: isBengali ? bengaliFontFamily : latinFontFamily,
      fontFamilyFallback: bengaliFallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  // Latin / Alphanumeric Type Scale (Plus Jakarta Sans)
  static TextStyle get display => _buildStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading1 => _buildStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading2 => _buildStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyRegular => _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => _buildStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.textSecondary,
      );

  static TextStyle get keypadDigit => _buildStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.0,
        color: AppColors.textPrimary,
      );

  // Bengali Type Scale (Hind Siliguri)
  static TextStyle get displayBengali => _buildStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
        isBengali: true,
      );

  static TextStyle get heading1Bengali => _buildStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
        isBengali: true,
      );

  static TextStyle get heading2Bengali => _buildStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
        isBengali: true,
      );

  static TextStyle get bodyRegularBengali => _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary,
        isBengali: true,
      );

  static TextStyle get bodyMediumBengali => _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textPrimary,
        isBengali: true,
      );

  static TextStyle get captionBengali => _buildStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.textSecondary,
        isBengali: true,
      );

  /// Material 3 TextTheme mapped with MetaPOS typographic scale.
  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        displayMedium: display.copyWith(fontSize: 28),
        displaySmall: display.copyWith(fontSize: 24),
        headlineLarge: heading1,
        headlineMedium: heading2,
        headlineSmall: heading2.copyWith(fontSize: 16),
        titleLarge: heading2,
        titleMedium: bodyMedium.copyWith(fontSize: 16),
        titleSmall: bodyMedium,
        bodyLarge: bodyMedium.copyWith(fontSize: 16),
        bodyMedium: bodyRegular,
        bodySmall: caption,
        labelLarge: bodyMedium.copyWith(fontWeight: FontWeight.w600),
        labelMedium: caption,
        labelSmall: caption.copyWith(fontSize: 10),
      );
}
