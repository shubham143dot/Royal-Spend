import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/services/ocr/ocr_service.dart';
import 'package:royal_spend/core/services/ocr/parsed_transaction.dart';
import 'package:royal_spend/core/services/ocr/receipt_parser.dart';

void main() {
  group('Amount Extraction Bug Investigation', () {
    test('Scenario 1: Grand Total label on separate line without currency symbol', () {
      const receipt = '''
RESTAURANT XYZ
GSTIN: 29AABCD1234E1Z5
Date: 24/10/2026
Ph: 9876543210
Invoice: 12345
Paneer Butter Masala   ₹ 250.00
Butter Naan             80.00
SUB TOTAL              330.00
CGST 2.5%                8.25
SGST 2.5%                8.25
Grand Total
346.50
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(346.50));
    });

    test('Scenario 2: Total Amount without currency symbol when items/subtotal have ₹', () {
      const receipt = '''
SUPER STORE
Phone: +91 98765 43210
Date: 25.10.2026
Item A   ₹ 450.00
Item B   ₹ 800.00
SUBTOTAL: ₹ 1,250.00
Discount: ₹ 100.00
Total Amount: 1,150.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(1150.00));
    });

    test('Scenario 3: Indian currency format 1,25,000.00 under Net Amount', () {
      const receipt = '''
ELECTRONICS STORE
INVOICE NO: 8812
GSTIN: 27AABCU9603R1ZX
Total Items: 1
Net Amount: 1,25,000.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(125000.00));
    });

    test('Scenario 4: OCR spacing without colon: Grand Total 450.00', () {
      const receipt = '''
CAFE COFFEE
Table No: 5
Grand Total 450.00
Cash Tendered 500.00
Change 50.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(450.00));
    });

    test('Scenario 5: Colon and currency attached: TOTAL: ₹450', () {
      const receipt = '''
RETAIL SHOP
Phone: 9876543210
TOTAL: ₹450
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(450.00));
    });

    test('Scenario 6: Amount Paid 1,250.00 with subtotal and tax', () {
      const receipt = '''
CLOTHING STORE
Date: 2026-10-24
Subtotal: 1,200.00
Tax: 50.00
Amount Paid 1,250.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(1250.00));
    });

    test('Scenario 7: Total Payable on separate line with visual ocrLines', () {
      const receipt = '''
HOTEL BILL
Sub Total: ₹400.00
CGST: ₹10.00
SGST: ₹10.00
Total Payable
₹420.00
''';
      final ocrLines = [
        const OcrLineData(text: 'HOTEL BILL', top: 10, left: 20, width: 100, height: 20),
        const OcrLineData(text: 'Sub Total: ₹400.00', top: 40, left: 20, width: 200, height: 18),
        const OcrLineData(text: 'CGST: ₹10.00', top: 65, left: 20, width: 150, height: 18),
        const OcrLineData(text: 'SGST: ₹10.00', top: 90, left: 20, width: 150, height: 18),
        const OcrLineData(text: 'Total Payable', top: 120, left: 20, width: 120, height: 22),
        const OcrLineData(text: '₹420.00', top: 145, left: 20, width: 80, height: 22),
      ];
      final result = ReceiptParser.parse(receipt, ocrLines: ocrLines);
      expect(result.amount, equals(420.00));
    });

    test('Scenario 8: Ambiguous multiple plausible totals leaves amount unconfirmed', () {
      const receipt = '''
PARKING RECEIPT
Ticket # 9988
Total: 450.00
Total: 500.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, isNull);
      expect(result.amountStatus, equals(AmountExtractionStatus.ambiguous));
      expect(result.candidateAmounts, containsAll([450.00, 500.00]));
    });

    test('Scenario 9: Never select phone numbers, dates, GSTINs, or invoice numbers', () {
      const receipt = '''
SHOP NAME
GSTIN: 29AABCD1234E1Z5
TEL: 080 23456789
MOB: 9876543210
DATE: 24/10/2026
INVOICE: 4521
PIN: 560001
NET AMOUNT: Rs. 450.00
''';
      final result = ReceiptParser.parse(receipt);
      expect(result.amount, equals(450.00));
      expect(result.candidateAmounts, isNot(contains(23456789.0)));
      expect(result.candidateAmounts, isNot(contains(9876543210.0)));
      expect(result.candidateAmounts, isNot(contains(4521.0)));
      expect(result.candidateAmounts, isNot(contains(560001.0)));
    });
  });
}

