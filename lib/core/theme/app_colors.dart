import 'package:flutter/material.dart';

/// MetaPOS design system color tokens.
///
/// Implements the brand color specification:
/// - Primary Emerald: `#0BC279`
/// - Primary Dark: `#089E62`
/// - Mint Accent: `#E6F9F1`
/// - Deep Slate / Surface Dark: `#131926`
/// - Canvas: `#F8FAFC`
/// - Surface Card: `#FFFFFF`
/// - Border: `#E2E8F0`
/// - Status & Tenders: InStock `#10B981`, LowStock `#F59E0B`, OutOfStock `#EF4444`,
///   bKash `#E2136E`, Cash `#059669`.
abstract final class AppColors {
  // Brand Emerald & Variants
  static const Color emerald = Color(0xFF0BC279);
  static const Color emeraldDark = Color(0xFF089E62);
  static const Color brandPrimary = emerald;
  static const Color brandPrimaryDark = emeraldDark;
  static const Color mint = Color(0xFFE6F9F1);
  static const Color brandPrimaryLight = mint;

  // Background & Surfaces
  static const Color deepSlate = Color(0xFF131926);
  static const Color surfaceDark = deepSlate;
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color canvasBackground = canvas;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = surface;

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDefault = border;
  static const Color borderFocus = emerald;

  // Typography & Content
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Status Colors
  static const Color statusInStock = Color(0xFF10B981);
  static const Color statusLowStock = Color(0xFFF59E0B);
  static const Color statusOutOfStock = Color(0xFFEF4444);

  // Status Backgrounds
  static const Color statusInStockBg = Color(0xFFE6F9F1);
  static const Color statusLowStockBg = Color(0xFFFEF3C7);
  static const Color statusOutOfStockBg = Color(0xFFFEE2E2);

  // Tender & Action Accents
  static const Color bKashMagenta = Color(0xFFE2136E);
  static const Color cashGreen = Color(0xFF059669);
  static const Color whatsAppGreen = Color(0xFF25D366);
  static const Color smsIndigo = Color(0xFF4F46E5);
}
