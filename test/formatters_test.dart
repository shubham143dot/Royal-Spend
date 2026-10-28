import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/utils/currency_formatter.dart';
import 'package:royal_spend/core/utils/date_formatter.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('CurrencyFormatter formats integers and decimals with custom symbols', () {
      expect(CurrencyFormatter.format(1500, symbol: '₹'), '₹1,500');
      expect(CurrencyFormatter.format(1500.50, symbol: '₹'), '₹1,500.50');
      expect(CurrencyFormatter.format(249.99, symbol: '\$'), '\$249.99');
    });

    test('CurrencyFormatter compact formats large numbers correctly', () {
      expect(CurrencyFormatter.format(15000, symbol: '₹', compact: true), '₹15.0k');
      expect(CurrencyFormatter.format(2500000, symbol: '\$', compact: true), '\$2.5M');
    });

    test('CurrencyFormatter formatSigned prefixes + for income and - for expense', () {
      expect(CurrencyFormatter.formatSigned(500, symbol: '₹', isIncome: false), '-₹500');
      expect(CurrencyFormatter.formatSigned(5000, symbol: '₹', isIncome: true), '+₹5,000');
    });

    test('DateFormatter formats dates in ISO format for exports', () {
      final testDate = DateTime(2026, 10, 24, 14, 30);
      expect(DateFormatter.formatDate(testDate), '2026-10-24');
      expect(DateFormatter.formatMonthYear(testDate), 'October 2026');
    });
  });
}
