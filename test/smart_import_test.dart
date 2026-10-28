import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/services/ocr/duplicate_detector.dart';
import 'package:royal_spend/core/services/ocr/ocr_service.dart';
import 'package:royal_spend/core/services/ocr/parsed_transaction.dart';
import 'package:royal_spend/core/services/ocr/receipt_parser.dart';
import 'package:royal_spend/data/models/expense.dart';

void main() {
  group('ReceiptParser OCR Extraction Tests', () {
    test('1. PhonePe payment screenshot parsing', () {
      const phonePeOcr = '''
PhonePe
Transaction Successful
Paid to
Blue Tokai Coffee Roasters
bluetokai@ybl
₹ 280.00
Debited from
State Bank of India - XX4912
UTR: 429812345678
24 Oct 2026, 08:30 PM
Payment Details
''';

      final result = ReceiptParser.parse(phonePeOcr);

      expect(result.merchant, contains('Blue Tokai'));
      expect(result.amount, equals(280.0));
      expect(result.amountConfidence, greaterThan(0.8));
      expect(result.categoryId, equals('food'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.referenceId, equals('429812345678'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.year, equals(2026));
      expect(result.date?.month, equals(10));
      expect(result.date?.day, equals(24));
    });

    test('2. Google Pay transaction screenshot parsing', () {
      const gPayOcr = '''
Google Pay
Completed
Paid to
Starbucks Coffee India
starbucks@okhdfcbank
₹450
25 October 2026 at 10:45 AM
UPI transaction ID: 429987654321
Google transaction ID: CICAgPDLz6
To Starbucks Coffee India
''';

      final result = ReceiptParser.parse(gPayOcr);

      expect(result.merchant, contains('Starbucks'));
      expect(result.amount, equals(450.0));
      expect(result.categoryId, equals('food'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.referenceId, equals('429987654321'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.month, equals(10));
      expect(result.date?.day, equals(25));
    });

    test('3. Paytm transaction screenshot parsing', () {
      const paytmOcr = '''
Paytm Payments Bank
Payment to
Uber India Systems Pvt Ltd
₹320.50
Successful
23 Oct 2026, 07:15 PM
UPI Ref No: 429711223344
Order ID: PYTM-99281
''';

      final result = ReceiptParser.parse(paytmOcr);

      expect(result.merchant, contains('Uber'));
      expect(result.amount, equals(320.50));
      expect(result.categoryId, equals('transport'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.referenceId, equals('429711223344'));
      expect(result.hasConfidentDate, isTrue);
    });

    test('4. Physical shop receipt parsing (Decathlon)', () {
      const storeOcr = '''
DECATHLON SPORTS INDIA
RHYTHM SQUARE, BANGALORE
GSTIN: 29AABCD1234E1Z5
Bill No: DEC-2026-8812
Date: 22/10/2026 Time: 15:30
1 RUNNING SHOES    1,499.00
1 WATER BOTTLE       299.00
SUB TOTAL:         1,798.00
CGST 9%:             161.82
SGST 9%:             161.82
GRAND TOTAL:       1,798.00
PAID BY CARD:      1,798.00
VISA CARD ENDING IN 3491
THANK YOU VISIT AGAIN
''';

      final result = ReceiptParser.parse(storeOcr);

      expect(result.merchant, equals('Decathlon'));
      expect(result.amount, equals(1798.0));
      expect(result.categoryId, equals('shopping'));
      expect(result.paymentMethod, equals(PaymentMethod.creditCard));
      expect(result.referenceId, equals('DEC-2026-8812'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.day, equals(22));
    });

    test('5. Restaurant bill parsing with taxes and subtotal', () {
      const restaurantOcr = '''
BARBEQUE NATION
TABLE NO: 12
GUEST COUNT: 4
CHEF SPECIAL BUFFET   3,600.00
MOCKTAILS               600.00
SUBTOTAL:             4,200.00
SERVICE CHARGE 5%:      210.00
CGST 2.5%:              105.00
SGST 2.5%:              105.00
NET AMOUNT:           4,620.00
Date: 2026-10-21 Time: 21:00
PAID BY UPI
''';

      final result = ReceiptParser.parse(restaurantOcr);

      expect(result.merchant, equals('Barbeque Nation'));
      // Should pick NET AMOUNT (4620), not Subtotal (4200) or Tax (105)
      expect(result.amount, equals(4620.0));
      expect(result.categoryId, equals('food'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.date?.day, equals(21));
    });

    test('6. Blurry or empty image', () {
      final emptyResult = ReceiptParser.parse('');
      expect(emptyResult.amount, isNull);
      expect(emptyResult.hasConfidentDate, isFalse);
      expect(emptyResult.merchant, isNull);

      const blurryOcr = '~~~~ ... --- ...';
      final blurryResult = ReceiptParser.parse(blurryOcr);
      expect(blurryResult.amount, isNull);
      expect(blurryResult.hasConfidentDate, isFalse);
    });

    test('7. Multiple monetary amounts disambiguation', () {
      const multiAmountOcr = '''
RELIANCE RETAIL LIMITED
TAX INVOICE
ITEM 1: ₹120.00
ITEM 2: ₹350.00
DISCOUNT: ₹50.00
CGST: ₹18.00
SGST: ₹18.00
TOTAL AMOUNT: ₹456.00
CASH TENDERED: ₹500.00
CHANGE: ₹44.00
Date: 19/10/2026
''';

      final result = ReceiptParser.parse(multiAmountOcr);

      // Total amount should be recognized with highest confidence
      expect(result.amount, equals(456.0));
      expect(result.candidateAmounts, contains(456.0));
      expect(result.candidateAmounts, contains(120.0));
      expect(result.candidateAmounts, contains(350.0));
      expect(result.categoryId, equals('shopping'));
    });

    test('8. Image with no recognizable transaction amount', () {
      const noAmountOcr = '''
THANK YOU FOR VISITING
HOSPITAL CLINICAL RECEIPT
PATIENT: JOHN DOE
DOCTOR: DR. SMITH
PLEASE COLLECT MEDICINES AT PHARMACY COUNTER
DATE: 20/10/2026
''';

      final result = ReceiptParser.parse(noAmountOcr);

      expect(result.amount, isNull);
      expect(result.amountConfidence, equals(0.0));
      expect(result.categoryId, equals('health'));
      expect(result.hasConfidentDate, isTrue);
    });

    test('9. Image with unclear date', () {
      const noDateOcr = '''
SWIGGY ORDER
Paid to Swiggy
₹ 385.00
Payment Successful via UPI
''';

      final result = ReceiptParser.parse(noDateOcr);

      expect(result.amount, equals(385.0));
      expect(result.hasConfidentDate, isFalse);
      expect(result.date, isNull);
      expect(result.categoryId, equals('food'));
    });

    test(
      '12. PhonePe integer amount without decimals and OCR misread rupee symbol (?)',
      () {
        const phonePeIntegerOcr = '''
PhonePe
Transaction Successful
Paid to
Kavita Milk Center
? 500
24 Oct 2026, 08:30 pm
UTR: 429812345678
''';

        final result = ReceiptParser.parse(phonePeIntegerOcr);

        expect(result.merchant, equals('Kavita Milk Center'));
        expect(result.amount, equals(500.0));
        expect(result.amountConfidence, greaterThan(0.85));
        expect(result.referenceId, equals('429812345678'));
      },
    );

    test('13. Google Pay with + ₹450 prefix and multi-line payee', () {
      const gPayPlusOcr = '''
Google Pay
To
Sharma Sweets
+ ₹450
Completed
Oct 24, 2026, 9:15 PM
UPI transaction ID: 429810294812
''';

      final result = ReceiptParser.parse(gPayPlusOcr);

      expect(result.merchant, equals('Sharma Sweets'));
      expect(result.amount, equals(450.0));
      expect(result.amountConfidence, greaterThan(0.85));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
    });

    test(
      '14. UPI screenshot with amount on standalone line and NO currency symbol',
      () {
        const upiNoCurrencyOcr = '''
Paid to
Tea Post
150
Payment Successful
24 Oct 2026, 10:15 am
''';

        final result = ReceiptParser.parse(upiNoCurrencyOcr);

        expect(result.merchant, equals('Tea Post'));
        expect(result.amount, equals(150.0));
        expect(result.amountConfidence, greaterThan(0.80));
      },
    );

    test('15. Receipt with trailing slash format (1250/-)', () {
      const trailingSlashOcr = '''
APOLLO PHARMACY
BANGALORE - 560001
PIN: 560001
CASH MEMO
MEDICINE A: 250
MEDICINE B: 1000
TOTAL: 1250/-
DATE: 20/10/2026
''';

      final result = ReceiptParser.parse(trailingSlashOcr);

      expect(result.merchant, equals('Apollo Pharmacy'));
      expect(result.amount, equals(1250.0));
      expect(result.categoryId, equals('health'));
    });

    test('16. High amount with Indian comma format (₹ 1,50,000)', () {
      const highAmountOcr = '''
RELIANCE DIGITAL
TAX INVOICE
APPLE MACBOOK AIR
TOTAL AMOUNT: ₹ 1,50,000
PAID BY CARD
22/10/2026
''';

      final result = ReceiptParser.parse(highAmountOcr);

      expect(result.merchant, equals('Reliance Digital'));
      expect(result.amount, equals(150000.0));
      expect(result.categoryId, equals('shopping'));
    });

    test(
      '17. PhonePe screenshot with Account Balance at bottom (suppresses balance)',
      () {
        const phonePeWithBalanceOcr = '''
PhonePe
Transaction Successful
Paid to
Mukesh Grocery
₹ 350.00
Debited from SBI - XX4912
UTR: 429810293810
24 Oct 2026, 11:30 AM
Check Balance
Account Balance
₹ 14,250.00
''';

        final result = ReceiptParser.parse(phonePeWithBalanceOcr);

        expect(result.merchant, equals('Mukesh Grocery'));
        expect(result.amount, equals(350.0));
        expect(result.amountConfidence, greaterThan(0.85));
        expect(result.candidateAmounts, isNot(contains(14250.0)));
      },
    );

    test(
      '18. Google Pay screenshot with Promotional Referral Banner (suppresses ₹201 reward)',
      () {
        const gPayWithReferralOcr = '''
Google Pay
Completed
Paid to
Sharma Sweets
+ ₹450
Completed • Oct 24, 2026, 10:15 AM
UPI transaction ID: 429812938120
Invite friends to Google Pay and get ₹201
''';

        final result = ReceiptParser.parse(gPayWithReferralOcr);

        expect(result.merchant, equals('Sharma Sweets'));
        expect(result.amount, equals(450.0));
        expect(result.candidateAmounts, isNot(contains(201.0)));
      },
    );

    test(
      '19. PhonePe screenshot with Debited from SBI - 4912 (suppresses account digits)',
      () {
        const phonePeAccountOcr = '''
PhonePe
Transaction Successful
Paid to
Blue Tokai Coffee Roasters
₹ 280
Debited from
State Bank of India - 4912
UTR: 429812345678
''';

        final result = ReceiptParser.parse(phonePeAccountOcr);

        expect(result.amount, equals(280.0));
        expect(result.candidateAmounts, isNot(contains(4912.0)));
      },
    );

    test('20. CRED screenshot with CRED coins and cashback up to ₹50', () {
      const credOcr = '''
CRED
payment of ₹850 successful
paid to Cafe Coffee Day
earned 850 cred coins
claim cashback up to ₹50
UPI ID: ccd@axisbank
''';

      final result = ReceiptParser.parse(credOcr);

      expect(result.merchant, equals('Cafe Coffee Day'));
      expect(result.amount, equals(850.0));
      expect(result.candidateAmounts, isNot(contains(50.0)));
    });

    test('21. Card Payment Slip (Pine Labs POS EDC machine)', () {
      const pineLabsSlipOcr = '''
PINE LABS
STARBUCKS COFFEE INDIA
MID: 1029384756
TID: 63910248
BATCH NO: 000142
INVOICE NO: 004521
CARD NO: ************4912
CARD TYPE: VISA CHIP
SALE
BASE AMOUNT:       Rs. 380.00
TIP AMOUNT:        Rs.   0.00
TOTAL AMOUNT:      Rs. 380.00
AUTH CODE: 123456
RRN: 429810293810
DATE: 24/10/2026
''';

      final result = ReceiptParser.parse(pineLabsSlipOcr);

      expect(result.merchant, contains('Starbucks'));
      expect(
        result.amount,
        equals(380.0),
        reason:
            'status=${result.amountStatus}; candidates=${result.candidateAmounts}; confidence=${result.amountConfidence}',
      );
      expect(result.paymentMethod, equals(PaymentMethod.creditCard));
      expect(result.candidateAmounts, isNot(contains(63910248.0)));
      expect(result.candidateAmounts, isNot(contains(123456.0)));
    });

    test(
      '22. Visual Geometry Weighting picks hero font amount over status bar time and subtotal',
      () {
        const visualOcrText = '''
10:45
5G  85%
Blue Tokai
₹ 280.00
Payment Successful
Subtotal: 250.00
CGST: 15.00
SGST: 15.00
''';

        final ocrLines = [
          const OcrLineData(
            text: '10:45',
            top: 20,
            left: 20,
            width: 60,
            height: 25,
          ),
          const OcrLineData(
            text: '5G  85%',
            top: 20,
            left: 300,
            width: 80,
            height: 25,
          ),
          const OcrLineData(
            text: 'Blue Tokai',
            top: 150,
            left: 100,
            width: 200,
            height: 35,
          ),
          const OcrLineData(
            text: '₹ 280.00',
            top: 220,
            left: 80,
            width: 240,
            height: 110,
          ), // Huge hero font!
          const OcrLineData(
            text: 'Payment Successful',
            top: 360,
            left: 70,
            width: 260,
            height: 30,
          ),
          const OcrLineData(
            text: 'Subtotal: 250.00',
            top: 450,
            left: 50,
            width: 300,
            height: 28,
          ),
          const OcrLineData(
            text: 'CGST: 15.00',
            top: 500,
            left: 50,
            width: 150,
            height: 26,
          ),
          const OcrLineData(
            text: 'SGST: 15.00',
            top: 530,
            left: 50,
            width: 150,
            height: 26,
          ),
        ];

        final result = ReceiptParser.parse(visualOcrText, ocrLines: ocrLines);

        expect(result.amount, equals(280.0));
        expect(result.amountConfidence, greaterThan(0.90));
        expect(result.candidateAmounts, isNot(contains(10.45)));
      },
    );

    test('23. Fuel slip with RATE, VOLUME, and TOTAL AMOUNT', () {
      const fuelSlipOcr = '''
INDIAN OIL CORPORATION
PETROL PUMP
RATE: 102.50
VOLUME: 5.00 L
SALE
TOTAL AMOUNT: Rs. 512.50
PAID BY UPI
24/10/2026
''';

      final result = ReceiptParser.parse(fuelSlipOcr);

      expect(result.merchant, equals('Indian Oil'));
      expect(
        result.amount,
        equals(512.50),
        reason:
            'status=${result.amountStatus}; candidates=${result.candidateAmounts}; confidence=${result.amountConfidence}',
      );
      expect(result.categoryId, equals('transport'));
      expect(result.candidateAmounts, isNot(contains(102.50)));
      expect(result.candidateAmounts, isNot(contains(5.0)));
    });

    test(
      '24. UPI screenshot with phone number in UPI handle ignores phone digits and extracts payment amount',
      () {
        const upiWithPhoneOcr = '''
PhonePe
Paid to
Ramesh Kumar
9876543210@paytm
₹ 650.00
Transaction Successful
Debited from
State Bank of India - XX4912
UPI transaction ID: 429876543210
25 Oct 2026, 04:15 PM
''';

        final result = ReceiptParser.parse(upiWithPhoneOcr);

        expect(result.merchant, contains('Ramesh Kumar'));
        expect(result.amount, equals(650.0));
        expect(result.currencySymbol, equals('₹'));
        expect(result.candidateAmounts, isNot(contains(9876543210)));
        expect(result.candidateAmounts, isNot(contains(429876543210)));
        expect(result.candidateAmounts, isNot(contains(4912)));
      },
    );

    test(
      '25. USD dollar currency symbol (\$) and USD abbreviation extraction',
      () {
        const usReceiptOcr = '''
Blue Bottle Coffee
San Francisco, CA 94103
Date: 10/24/2026 09:30 AM
Receipt #: 88921
1 Hayes Valley Espresso    \$ 4.75
1 Bella Donovan Whole Bean \$ 22.00
Subtotal:                  \$ 26.75
Tax:                        \$ 2.27
TOTAL AMOUNT:              \$ 29.02
Payment: VISA ending in 1234
''';

        final result = ReceiptParser.parse(usReceiptOcr);

        expect(result.merchant, contains('Blue Bottle'));
        expect(result.amount, equals(29.02));
        expect(result.currencySymbol, equals('\$'));
        expect(result.candidateAmounts, contains(29.02));
        expect(result.candidateAmounts, contains(26.75));
        expect(result.candidateAmounts, isNot(contains(1234)));
        expect(result.candidateAmounts, isNot(contains(88921)));
      },
    );

    test('26. USD abbreviation with split currency line merging', () {
      const usdAbbrevOcr = '''
Apple Store
One Apple Park Way
Cupertino, CA
Invoice No: INV-98124
USD
149.00
PAID WITH CARD
''';

      final result = ReceiptParser.parse(usdAbbrevOcr);

      expect(result.merchant, contains('Apple'));
      expect(result.amount, equals(149.0));
      expect(result.currencySymbol, equals('\$'));
      expect(result.candidateAmounts, contains(149.0));
      expect(result.candidateAmounts, isNot(contains(98124)));
    });

    test(
      '27. Ambiguity candidates exposed when multiple valid monetary amounts exist',
      () {
        const multiAmountReceipt = '''
Samosa Party
Koramangala, Bangalore
Bill No: SP-9981
Order Total: ₹ 380.00
Discount: ₹ 30.00
Grand Total: ₹ 350.00
Paid via Google Pay
''';

        final result = ReceiptParser.parse(multiAmountReceipt);

        expect(result.amount, equals(350.0));
        expect(result.candidateAmounts, contains(350.0));
        expect(result.candidateAmounts, contains(380.0));
        expect(result.candidateAmounts.length, greaterThanOrEqualTo(2));
        expect(result.candidateAmounts, isNot(contains(9981)));
      },
    );

    test(
      '28. Small, grouped, and decimal currency values preserve every digit',
      () {
        final examples = <(String, double)>[
          ('₹1', 1),
          ('₹2', 2),
          ('₹3', 3),
          ('₹12', 12),
          ('₹21', 21),
          ('₹100', 100),
          ('₹1,000', 1000),
          ('₹1.50', 1.5),
          ('₹12.50', 12.5),
          ('₹1,234.56', 1234.56),
          ('₹12,345.00', 12345),
          ('₹1,23,456.78', 123456.78),
        ];

        for (final (ocrText, expected) in examples) {
          final result = ReceiptParser.parse(ocrText);
          expect(result.amount, equals(expected), reason: ocrText);
          expect(
            result.amountStatus,
            AmountExtractionStatus.extracted,
            reason: ocrText,
          );
        }
      },
    );

    test(
      '29. Malformed grouping and adjacent OCR digits require manual review',
      () {
        for (final ocrText in ['₹1,2', '₹1,23', 'You paid ₹1 2']) {
          final result = ReceiptParser.parse(ocrText);
          expect(result.amount, isNull, reason: ocrText);
          expect(
            result.amountStatus,
            AmountExtractionStatus.invalid,
            reason: ocrText,
          );
        }
      },
    );

    test(
      '30. Unlabeled competing amounts remain candidates without auto-selection',
      () {
        final result = ReceiptParser.parse('''
Coffee Shop
₹12
₹100
''');

        expect(result.amount, isNull);
        expect(result.amountStatus, AmountExtractionStatus.ambiguous);
        expect(result.candidateAmounts, containsAll([12.0, 100.0]));
      },
    );

    test('31. Supported rupee formats retain integer and decimal meaning', () {
      final examples = <(String, double)>[
        ('Rs. 1', 1),
        ('Rs 1', 1),
        ('INR 1', 1),
        ('Rs 12.50', 12.5),
        ('INR 1.00', 1),
        ('1 INR', 1),
      ];

      for (final (ocrText, expected) in examples) {
        final result = ReceiptParser.parse(ocrText);
        expect(
          result.amount,
          equals(expected),
          reason:
              '$ocrText; status=${result.amountStatus}; candidates=${result.candidateAmounts}; confidence=${result.amountConfidence}',
        );
        expect(
          result.amountStatus,
          AmountExtractionStatus.extracted,
          reason: ocrText,
        );
      }
    });

    test(
      '32. Ambiguous letter-to-digit OCR text is not silently rewritten',
      () {
        for (final ocrText in ['INR O1', 'Amount: INR I2']) {
          final result = ReceiptParser.parse(ocrText);
          expect(result.amount, isNull, reason: ocrText);
          expect(
            result.amountStatus,
            AmountExtractionStatus.missing,
            reason: ocrText,
          );
        }
      },
    );

    test(
      '33. Received and refunded transactions retain incoming direction',
      () {
        final received = ReceiptParser.parse('''
Payment received from Asha
Amount credited: ₹500
''');
        final refunded = ReceiptParser.parse('''
Refund credited
₹120.00
''');
        final receivedStatus = ReceiptParser.parse('''
Received
₹1
''');
        final cashback = ReceiptParser.parse('''
Cashback received
₹5
''');
        final sent = ReceiptParser.parse('''
Money sent to Asha
₹500
''');

        expect(received.amount, 500);
        expect(received.isIncome, isTrue);
        expect(refunded.amount, 120);
        expect(refunded.isIncome, isTrue);
        expect(receivedStatus.amount, 1);
        expect(receivedStatus.isIncome, isTrue);
        expect(cashback.amount, isNull);
        expect(cashback.isIncome, isFalse);
        expect(sent.amount, 500);
        expect(sent.isIncome, isFalse);
      },
    );

    test(
      '34. Euro and pound symbols and codes are parsed with their currency',
      () {
        final examples = <(String, double, String)>[
          ('€12.50', 12.5, '€'),
          ('£1', 1, '£'),
          ('EUR 1.00', 1, '€'),
          ('1.00 GBP', 1, '£'),
        ];

        for (final (ocrText, expectedAmount, expectedSymbol) in examples) {
          final result = ReceiptParser.parse(ocrText);
          expect(result.amount, expectedAmount, reason: ocrText);
          expect(result.currencySymbol, expectedSymbol, reason: ocrText);
          expect(result.amountStatus, AmountExtractionStatus.extracted);
        }
      },
    );

    test('35. Exact PhonePe receipt from user screenshot (Mohalla Tech, ₹1, AutoPay, UTR)', () {
      const phonePeScreenshotText = '''
Transaction Successful
09:31 AM on 09 Oct 2026
Paid to
ML
MOHALLA TECH PRIVATE LIMITED
₹1
AUTOPAY
Payment Details
Message
Subscription for MOHALLATECHP
PhonePe Transaction ID
OLEX2610090931475087256792
Debited from
XXXXXX2608
₹1
UTR: 185528484567
Check Balance
View History
Split Expense
Share Receipt
Manage AutoPay
Contact PhonePe Support
Powered by
UPI AUTOPAY
ICICI Bank
''';

      final result = ReceiptParser.parse(phonePeScreenshotText);

      expect(result.sourceType, equals('PhonePe UPI'));
      expect(result.amount, equals(1.0));
      expect(result.amountConfidence, greaterThanOrEqualTo(0.95));
      expect(result.merchant, equals('MOHALLA TECH PRIVATE LIMITED'));
      expect(result.referenceId, equals('185528484567'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.year, equals(2026));
      expect(result.date?.month, equals(10));
      expect(result.date?.day, equals(9));
      expect(result.date?.hour, equals(9));
      expect(result.date?.minute, equals(31));
      expect(result.timeString, equals('09:31 AM'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.isIncome, isFalse);
    });

    test('36. Exact Navi UPI receipt from user screenshot (Railway Employees, ₹30, UTR)', () {
      const naviScreenshotText = '''
Paid securely on
n navi UPI
Get up to ₹1,000 on every payment 🪙100 = ₹1
Payment successful
to RAILWAY EMPLOYEES CULTURAL ASSOCIATION
******6134m@pnb
₹30
Paid super fast with Navi UPI
25 Oct 2026, 7:40 PM
from M Shubham
State Bank of India - 2608
UPI txn ID : 006249434839
''';

      final result = ReceiptParser.parse(naviScreenshotText);

      expect(result.sourceType, equals('Navi UPI'));
      // Must extract ₹30, NOT ₹1,000 from promo banner, NOT ₹1 from 🪙100 = ₹1
      expect(result.amount, equals(30.0));
      expect(result.candidateAmounts, isNot(contains(1000.0)));
      expect(result.amountConfidence, greaterThanOrEqualTo(0.95));
      expect(result.merchant, equals('RAILWAY EMPLOYEES CULTURAL ASSOCIATION'));
      expect(result.referenceId, equals('006249434839'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.year, equals(2026));
      expect(result.date?.month, equals(10));
      expect(result.date?.day, equals(25));
      expect(result.date?.hour, equals(19));
      expect(result.date?.minute, equals(40));
      expect(result.timeString, equals('7:40 PM'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
      expect(result.isIncome, isFalse);
    });

    test('37. Exact Google Pay Rewards receipt from user screenshot (Google Pay rewards, ₹1, Income)', () {
      const gPayRewardsScreenshotText = '''
G
From Google Pay rewards
₹1
Rewarded for completing a payment to a merchant with Google Pay
Completed
29 Jan 2026, 5:33 pm
State Bank of India 2608
To: M. Shubham
....deep@okhdfcbank on Google Pay
Google transaction ID
CICAgJiChNu4ew
Payments may take up to 3 working days to be reflected in your account
Having issues?
Share
''';

      final result = ReceiptParser.parse(gPayRewardsScreenshotText);

      expect(result.sourceType, equals('Google Pay'));
      // Must extract ₹1 without being killed by "rewards"
      expect(result.amount, equals(1.0));
      expect(result.amountConfidence, greaterThanOrEqualTo(0.95));
      expect(result.isIncome, isTrue);
      expect(result.merchant, equals('Google Pay Rewards'));
      expect(result.referenceId, equals('CICAgJiChNu4ew'));
      expect(result.hasConfidentDate, isTrue);
      expect(result.date?.year, equals(2026));
      expect(result.date?.month, equals(1));
      expect(result.date?.day, equals(29));
      expect(result.date?.hour, equals(17));
      expect(result.date?.minute, equals(33));
      expect(result.timeString, equals('5:33 PM'));
      expect(result.paymentMethod, equals(PaymentMethod.upi));
    });

    test('39. Direct Rupee with number in various tricky formats (attached ₹500, Paid:₹500, split line, ₹.500, debited from with ₹)', () {
      final cases = [
        ('₹500', 500.0),
        ('Paid:₹500', 500.0),
        ('Total ₹ 500.50', 500.5),
        ('₹\n500', 500.0),
        ('Total: ₹.500', 500.0),
        ('Debited from SBI\n₹ 500\nUTR: 123456789012', 500.0),
        ('Paid to Merchant\n₹ 500 24 Oct 2026', 500.0),
        ('₹ 1,250.75 paid', 1250.75),
        ('₹ 1,50,000 transferred', 150000.0),
      ];

      for (final (text, expectedAmount) in cases) {
        final parsed = ReceiptParser.parse(text);
        expect(
          parsed.amount,
          equals(expectedAmount),
          reason: 'Failed for input: "$text"',
        );
        expect(
          parsed.amountStatus,
          equals(AmountExtractionStatus.extracted),
          reason: 'Status failed for input: "$text"',
        );
      }
    });
  });

  group('DuplicateDetector Tests', () {
    final existingList = [
      Expense(
        id: 'exp-1',
        title: 'Blue Tokai Coffee Roasters',
        amount: 280.0,
        categoryId: 'food',
        date: DateTime(2026, 10, 24, 20, 30),
        paymentMethod: PaymentMethod.upi,
        notes: 'UTR: 429812345678',
      ),
      Expense(
        id: 'exp-2',
        title: 'Uber to Office',
        amount: 450.0,
        categoryId: 'transport',
        date: DateTime(2026, 10, 20, 9, 15),
        paymentMethod: PaymentMethod.upi,
      ),
    ];

    test(
      '10. Same transaction imported twice by UTR or amount+date+merchant',
      () {
        final duplicateByUtr = ParsedTransaction(
          merchant: 'Blue Tokai',
          amount: 280.0,
          categoryId: 'food',
          referenceId: '429812345678',
          rawText: '...',
        );

        final checkUtr = DuplicateDetector.checkDuplicate(
          duplicateByUtr,
          existingList,
        );
        expect(checkUtr.isDuplicate, isTrue);
        expect(checkUtr.duplicateExpense?.id, equals('exp-1'));

        final duplicateByAmountDate = ParsedTransaction(
          merchant: 'Blue Tokai Coffee',
          amount: 280.0,
          date: DateTime(2026, 10, 24, 20, 30),
          categoryId: 'food',
          rawText: '...',
        );

        final checkFuzzy = DuplicateDetector.checkDuplicate(
          duplicateByAmountDate,
          existingList,
        );
        expect(checkFuzzy.isDuplicate, isTrue);
        expect(checkFuzzy.duplicateExpense?.id, equals('exp-1'));
      },
    );

    test(
      '11. Legitimate same amount but different merchant and date is NOT duplicate',
      () {
        final legitimateOther = ParsedTransaction(
          merchant: 'Starbucks Coffee',
          amount: 280.0, // Same amount as Blue Tokai
          date: DateTime(2026, 10, 25, 11, 00), // Different date
          categoryId: 'food',
          referenceId: '999988887777', // Different UTR
          rawText: '...',
        );

        final check = DuplicateDetector.checkDuplicate(
          legitimateOther,
          existingList,
        );
        expect(check.isDuplicate, isFalse);
        expect(check.duplicateExpense, isNull);
      },
    );

    test('12. Incoming funds do not duplicate a same-value expense', () {
      final incoming = ParsedTransaction(
        merchant: 'Blue Tokai Coffee',
        amount: 280.0,
        isIncome: true,
        date: DateTime(2026, 10, 24, 20, 30),
        categoryId: 'other',
        rawText: 'Payment received',
      );

      final result = DuplicateDetector.checkDuplicate(incoming, existingList);

      expect(result.isDuplicate, isFalse);
    });
  });
}
