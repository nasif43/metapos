import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter - formatBDT', () {
    test('formats standard positive amount as whole number without decimals', () {
      final result = CurrencyFormatter.formatBDT(1530.0);
      expect(result, equals('৳ 1,530'));
      expect(result.contains('\u09F3'), isTrue);
    });

    test('formats integer input as whole number with commas', () {
      expect(CurrencyFormatter.formatBDT(1530), equals('৳ 1,530'));
      expect(CurrencyFormatter.formatBDT(100), equals('৳ 100'));
    });

    test('rounds fractional amounts cleanly to nearest whole taka', () {
      expect(CurrencyFormatter.formatBDT(1530.40), equals('৳ 1,530'));
      expect(CurrencyFormatter.formatBDT(1530.50), equals('৳ 1,531'));
      expect(CurrencyFormatter.formatBDT(1530.90), equals('৳ 1,531'));
    });

    test('formats zero properly as whole number', () {
      expect(CurrencyFormatter.formatBDT(0), equals('৳ 0'));
      expect(CurrencyFormatter.formatBDT(0.0), equals('৳ 0'));
    });

    test('formats negative numbers with leading minus sign as whole number', () {
      expect(CurrencyFormatter.formatBDT(-170.0), equals('-৳ 170'));
      expect(CurrencyFormatter.formatBDT(-1530.50), equals('-৳ 1,531'));
    });

    test('formats large numbers with appropriate comma groupings without decimals', () {
      expect(CurrencyFormatter.formatBDT(1000000.0), equals('৳ 1,000,000'));
      expect(CurrencyFormatter.formatBDT(12345678.90), equals('৳ 12,345,679'));
    });

    test('respects showDecimals parameter when explicitly set to true', () {
      expect(CurrencyFormatter.formatBDT(1530, showDecimals: true), equals('৳ 1,530.00'));
      expect(CurrencyFormatter.formatBDT(0, showDecimals: true), equals('৳ 0.00'));
      expect(CurrencyFormatter.formatBDT(1530.50, showDecimals: true), equals('৳ 1,530.50'));
    });

    test('respects spaceAfterSymbol parameter when false', () {
      expect(CurrencyFormatter.formatBDT(1530.0, spaceAfterSymbol: false), equals('৳1,530'));
      expect(CurrencyFormatter.formatBDT(-170.0, spaceAfterSymbol: false), equals('-৳170'));
    });

    test('handles null, NaN, and Infinity gracefully without throwing', () {
      expect(CurrencyFormatter.formatBDT(null), equals('৳ 0'));
      expect(CurrencyFormatter.formatBDT(double.nan), equals('৳ 0'));
      expect(CurrencyFormatter.formatBDT(double.infinity), equals('৳ 0'));
      expect(CurrencyFormatter.formatBDT(double.negativeInfinity), equals('৳ 0'));
    });
  });

  group('CurrencyFormatter - formatBDTSigned', () {
    test('formats negative amounts with - prefix and whole number', () {
      expect(CurrencyFormatter.formatBDTSigned(-170.0), equals('- ৳ 170'));
    });

    test('formats positive amounts with + prefix and whole number', () {
      expect(CurrencyFormatter.formatBDTSigned(170.0), equals('+ ৳ 170'));
    });

    test('formats zero with standard neutral format', () {
      expect(CurrencyFormatter.formatBDTSigned(0), equals('৳ 0'));
    });

    test('respects showDecimals when explicitly enabled', () {
      expect(CurrencyFormatter.formatBDTSigned(-170.0, showDecimals: true), equals('- ৳ 170.00'));
    });
  });

  group('CurrencyFormatter - formatBDTCompact', () {
    test('formats amounts under 1,000 as standard integer', () {
      expect(CurrencyFormatter.formatBDTCompact(850), equals('৳ 850'));
      expect(CurrencyFormatter.formatBDTCompact(0), equals('৳ 0'));
    });

    test('formats thousands with commas instead of K suffix', () {
      expect(CurrencyFormatter.formatBDTCompact(1500), equals('৳ 1,500'));
      expect(CurrencyFormatter.formatBDTCompact(5000), equals('৳ 5,000'));
    });

    test('formats millions with M suffix', () {
      expect(CurrencyFormatter.formatBDTCompact(2500000), equals('৳ 2.5M'));
      expect(CurrencyFormatter.formatBDTCompact(10000000), equals('৳ 10M'));
    });

    test('formats negative compact values with minus sign', () {
      expect(CurrencyFormatter.formatBDTCompact(-1500), equals('-৳ 1,500'));
    });

    test('handles null and invalid numbers gracefully', () {
      expect(CurrencyFormatter.formatBDTCompact(null), equals('৳ 0'));
      expect(CurrencyFormatter.formatBDTCompact(double.nan), equals('৳ 0'));
    });
  });

  group('CurrencyFormatter - parseBDT', () {
    test('parses formatted currency string back to double', () {
      expect(CurrencyFormatter.parseBDT('৳ 1,530.00'), equals(1530.0));
      expect(CurrencyFormatter.parseBDT('৳ 100'), equals(100.0));
    });

    test('parses negative formatted string correctly', () {
      expect(CurrencyFormatter.parseBDT('-৳ 170.00'), equals(-170.0));
      expect(CurrencyFormatter.parseBDT('- ৳ 170.00'), equals(-170.0));
    });

    test('parses raw numbers without symbol', () {
      expect(CurrencyFormatter.parseBDT('1,530.50'), equals(1530.50));
      expect(CurrencyFormatter.parseBDT('500'), equals(500.0));
    });

    test('returns 0.0 for invalid or empty strings', () {
      expect(CurrencyFormatter.parseBDT(null), equals(0.0));
      expect(CurrencyFormatter.parseBDT(''), equals(0.0));
      expect(CurrencyFormatter.parseBDT('invalid text'), equals(0.0));
    });
  });
}
