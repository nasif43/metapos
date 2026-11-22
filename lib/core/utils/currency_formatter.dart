import 'package:intl/intl.dart';

/// Bangladeshi Taka (BDT ৳) currency formatter.
///
/// Formats numerical amounts according to Bangladeshi retail conventions:
/// - Unicode symbol: `৳` (`\u09F3`)
/// - Standard comma groupings (e.g. `৳ 1,530.00`)
/// - Handles zero, negative numbers, compact notation, and string parsing.
abstract final class CurrencyFormatter {
  /// Bangladeshi Taka currency symbol (Unicode \u09F3)
  static const String takaSymbol = '\u09F3';

  static final NumberFormat _standardFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _integerFormat = NumberFormat('#,##0', 'en_US');

  /// Formats [amount] in Bangladeshi Taka.
  ///
  /// In Bangladeshi retail, BDT is standardly represented as whole numbers
  /// (no fractional paisa in circulation). Decimal places are omitted by default
  /// ([showDecimals] defaults to `false`) and values are cleanly rounded.
  ///
  /// Examples:
  /// - `formatBDT(1530.0)` -> `"৳ 1,530"`
  /// - `formatBDT(0)` -> `"৳ 0"`
  /// - `formatBDT(-170.0)` -> `"-৳ 170"`
  /// - `formatBDT(1530.50)` -> `"৳ 1,531"`
  /// - `formatBDT(1530, showDecimals: true)` -> `"৳ 1,530.00"`
  static String formatBDT(
    num? amount, {
    bool showDecimals = false,
    bool spaceAfterSymbol = true,
  }) {
    if (amount == null || amount.isNaN || amount.isInfinite) {
      final space = spaceAfterSymbol ? ' ' : '';
      return '$takaSymbol$space${showDecimals ? '0.00' : '0'}';
    }

    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final space = spaceAfterSymbol ? ' ' : '';

    if (showDecimals) {
      final formattedNumber = _standardFormat.format(absAmount);
      return isNegative ? '-$takaSymbol$space$formattedNumber' : '$takaSymbol$space$formattedNumber';
    } else {
      final formattedNumber = _integerFormat.format(absAmount.round());
      return isNegative ? '-$takaSymbol$space$formattedNumber' : '$takaSymbol$space$formattedNumber';
    }
  }

  /// Formats [amount] with a leading sign and space for line-item deductions.
  ///
  /// Examples:
  /// - `formatBDTSigned(-170.0)` -> `"- ৳ 170"`
  /// - `formatBDTSigned(170.0)` -> `"+ ৳ 170"`
  static String formatBDTSigned(num? amount, {bool showDecimals = false}) {
    if (amount == null || amount == 0 || amount.isNaN || amount.isInfinite) {
      return formatBDT(0, showDecimals: showDecimals);
    }
    final sign = amount < 0 ? '- ' : '+ ';
    final formatted = formatBDT(amount.abs(), showDecimals: showDecimals);
    return '$sign$formatted';
  }

  /// Compact BDT representation for small screen tags or summary chips.
  ///
  /// Examples:
  /// - `formatBDTCompact(1500)` -> `"৳ 1.5K"`
  /// - `formatBDTCompact(2500000)` -> `"৳ 2.5M"`
  /// - `formatBDTCompact(850)` -> `"৳ 850"`
  static String formatBDTCompact(num? amount) {
    if (amount == null || amount.isNaN || amount.isInfinite) {
      return '$takaSymbol 0';
    }

    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final String sign = isNegative ? '-' : '';

    if (absAmount >= 1000000000) {
      final val = (absAmount / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return '$sign$takaSymbol ${val}B';
    } else if (absAmount >= 1000000) {
      final val = (absAmount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return '$sign$takaSymbol ${val}M';
    } else {
      return '$sign$takaSymbol ${_integerFormat.format(absAmount.round())}';
    }
  }

  /// Parses a formatted BDT string into a numeric double value.
  ///
  /// Cleans out currency symbols, spaces, commas and extracts the double.
  /// Returns `0.0` if parsing fails.
  static double parseBDT(String? formatted) {
    if (formatted == null || formatted.trim().isEmpty) {
      return 0.0;
    }

    final isNegative = formatted.contains('-');
    final cleaned = formatted
        .replaceAll(takaSymbol, '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .trim();

    final value = double.tryParse(cleaned) ?? 0.0;
    return isNegative ? -value : value;
  }
}
