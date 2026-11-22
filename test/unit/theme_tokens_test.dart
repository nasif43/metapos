import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/theme/app_colors.dart';
import 'package:metapos/core/theme/app_theme.dart';
import 'package:metapos/core/theme/app_typography.dart';

void main() {
  setUpAll(() {
    AppTypography.enableGoogleFonts = false;
  });

  tearDownAll(() {
    AppTypography.enableGoogleFonts = true;
  });

  group('AppColors Brand Tokens', () {
    test('brand color hex values match specification', () {
      expect(AppColors.emerald, equals(const Color(0xFF0BC279)));
      expect(AppColors.emeraldDark, equals(const Color(0xFF089E62)));
      expect(AppColors.mint, equals(const Color(0xFFE6F9F1)));
      expect(AppColors.deepSlate, equals(const Color(0xFF131926)));
      expect(AppColors.canvas, equals(const Color(0xFFF8FAFC)));
      expect(AppColors.surface, equals(const Color(0xFFFFFFFF)));
      expect(AppColors.border, equals(const Color(0xFFE2E8F0)));
      expect(AppColors.borderFocus, equals(const Color(0xFF0BC279)));
      expect(AppColors.textPrimary, equals(const Color(0xFF0F172A)));
      expect(AppColors.textSecondary, equals(const Color(0xFF64748B)));
      expect(AppColors.textMuted, equals(const Color(0xFF94A3B8)));
      expect(AppColors.statusInStock, equals(const Color(0xFF10B981)));
      expect(AppColors.statusLowStock, equals(const Color(0xFFF59E0B)));
      expect(AppColors.statusOutOfStock, equals(const Color(0xFFEF4444)));
      expect(AppColors.bKashMagenta, equals(const Color(0xFFE2136E)));
      expect(AppColors.cashGreen, equals(const Color(0xFF059669)));
    });

    test('alias tokens point to correct primary definitions', () {
      expect(AppColors.brandPrimary, equals(AppColors.emerald));
      expect(AppColors.brandPrimaryDark, equals(AppColors.emeraldDark));
      expect(AppColors.brandPrimaryLight, equals(AppColors.mint));
      expect(AppColors.surfaceDark, equals(AppColors.deepSlate));
      expect(AppColors.surfaceCard, equals(AppColors.surface));
      expect(AppColors.canvasBackground, equals(AppColors.canvas));
      expect(AppColors.borderDefault, equals(AppColors.border));
    });
  });

  group('AppTypography Type Scale', () {
    test('font families are configured for Latin and Bengali scripts', () {
      expect(AppTypography.latinFontFamily, equals('Plus Jakarta Sans'));
      expect(AppTypography.bengaliFontFamily, equals('Hind Siliguri'));
      expect(AppTypography.bengaliFallbacks, contains('Noto Sans Bengali'));
    });

    test('font sizes match specifications', () {
      expect(AppTypography.display.fontSize, equals(32.0));
      expect(AppTypography.heading1.fontSize, equals(22.0));
      expect(AppTypography.heading2.fontSize, equals(18.0));
      expect(AppTypography.bodyRegular.fontSize, equals(14.0));
      expect(AppTypography.bodyMedium.fontSize, equals(14.0));
      expect(AppTypography.caption.fontSize, equals(12.0));
      expect(AppTypography.keypadDigit.fontSize, equals(24.0));
    });

    test('font weights match specifications', () {
      expect(AppTypography.display.fontWeight, equals(FontWeight.w600));
      expect(AppTypography.heading1.fontWeight, equals(FontWeight.w700));
      expect(AppTypography.heading2.fontWeight, equals(FontWeight.w600));
      expect(AppTypography.bodyRegular.fontWeight, equals(FontWeight.w400));
      expect(AppTypography.bodyMedium.fontWeight, equals(FontWeight.w500));
      expect(AppTypography.caption.fontWeight, equals(FontWeight.w500));
      expect(AppTypography.keypadDigit.fontWeight, equals(FontWeight.w600));
    });

    test('Bengali typography variants preserve font sizes', () {
      expect(AppTypography.displayBengali.fontSize, equals(32.0));
      expect(AppTypography.heading1Bengali.fontSize, equals(22.0));
      expect(AppTypography.heading2Bengali.fontSize, equals(18.0));
      expect(AppTypography.bodyRegularBengali.fontSize, equals(14.0));
      expect(AppTypography.bodyMediumBengali.fontSize, equals(14.0));
      expect(AppTypography.captionBengali.fontSize, equals(12.0));
    });

    test('textTheme contains mapped typography hierarchy', () {
      final theme = AppTypography.textTheme;
      expect(theme.displayLarge?.fontSize, equals(32.0));
      expect(theme.headlineLarge?.fontSize, equals(22.0));
      expect(theme.headlineMedium?.fontSize, equals(18.0));
      expect(theme.bodyMedium?.fontSize, equals(14.0));
      expect(theme.bodySmall?.fontSize, equals(12.0));
    });
  });

  group('AppSpacing & AppTheme Constraints', () {
    test('spacing tokens conform to 8dp grid base', () {
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(16.0));
      expect(AppSpacing.lg, equals(24.0));
      expect(AppSpacing.xl, equals(32.0));
      expect(AppSpacing.xxl, equals(48.0));
    });

    test('touch targets meet minimum 48dp requirement', () {
      expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(48.0));
      expect(AppSpacing.keypadTarget, greaterThanOrEqualTo(48.0));
    });

    test('lightTheme applies required branding tokens', () {
      final theme = AppTheme.lightTheme;
      expect(theme.primaryColor, equals(AppColors.emerald));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.canvas));
      expect(theme.colorScheme.primary, equals(AppColors.emerald));
      expect(theme.colorScheme.secondary, equals(AppColors.deepSlate));
      expect(theme.cardTheme.color, equals(AppColors.surfaceCard));
    });

    test('button themes enforce >= 48dp x 48dp touch targets', () {
      final theme = AppTheme.lightTheme;

      final elevatedMin =
          theme.elevatedButtonTheme.style?.minimumSize?.resolve({}) ?? Size.zero;
      expect(elevatedMin.width, greaterThanOrEqualTo(48.0));
      expect(elevatedMin.height, greaterThanOrEqualTo(48.0));

      final outlinedMin =
          theme.outlinedButtonTheme.style?.minimumSize?.resolve({}) ?? Size.zero;
      expect(outlinedMin.width, greaterThanOrEqualTo(48.0));
      expect(outlinedMin.height, greaterThanOrEqualTo(48.0));

      final iconMin =
          theme.iconButtonTheme.style?.minimumSize?.resolve({}) ?? Size.zero;
      expect(iconMin.width, greaterThanOrEqualTo(48.0));
      expect(iconMin.height, greaterThanOrEqualTo(48.0));
    });
  });
}
