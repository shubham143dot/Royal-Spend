import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/services/network/network_status_service.dart';
import 'package:royal_spend/core/services/ocr/parsed_transaction.dart';
import 'package:royal_spend/core/services/ocr/receipt_parser.dart';
import 'package:royal_spend/data/database/database_helper.dart';
import 'package:royal_spend/data/models/expense.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    NetworkStatusService.instance.setMockOnline(null);
  });

  group('1. Indian Receipt Formats & Intelligent Data Extraction', () {
    test('Restaurant Bill with Subtotal, CGST, SGST, Table No, Invoice No and Time', () {
      const receipt = '''
      ROYAL SPICE RESTAURANT & CAFE
      12 Brigade Road, Bangalore - 560001
      GSTIN: 29ABCDE1234F1Z5
      Tax Invoice No: TI/2026/0488
      Date: 16/11/2026 Time: 08:45 PM
      Table No: 07 | Steward: Ramesh

      1 Butter Chicken         350.00
      2 Garlic Naan             90.00
      1 Jeera Rice             120.00
      2 Mineral Water           40.00

      Sub Total: ₹600.00
      CGST @ 2.5%: ₹15.00
      SGST @ 2.5%: ₹15.00
      Total GST: ₹30.00
      --------------------------------
      GRAND TOTAL: ₹630.00
      --------------------------------
      Thank You! Visit Again
      Phone: 9845012345
      ''';

      final parsed = ReceiptParser.parse(receipt);

      expect(parsed.amount, equals(630.0));
      expect(parsed.amountStatus, equals(AmountExtractionStatus.extracted));
      expect(parsed.subtotal, equals(600.0));
      expect(parsed.cgst, equals(15.0));
      expect(parsed.sgst, equals(15.0));
      expect(parsed.gstAmount, equals(30.0));
      expect(parsed.taxPercentage, equals(5.0));
      expect(parsed.invoiceNumber, contains('TI/2026/0488'));
      expect(parsed.categoryId, equals('food'));
      expect(parsed.currencySymbol, equals('₹'));
      expect(parsed.date?.year, equals(2026));
      expect(parsed.date?.month, equals(11));
      expect(parsed.date?.day, equals(16));
      expect(parsed.timeString, isNotNull);

      // Verify safety: phone number, GSTIN, and subtotal were NOT selected as grand total
      expect(parsed.amount, isNot(equals(9845012345)));
      expect(parsed.amount, isNot(equals(600.0)));
      expect(parsed.amount, isNot(equals(30.0)));
    });

    test('Petrol Pump Fuel Slip with Nozzle, Density, Volume, Rate, and Net Total', () {
      const fuelReceipt = '''
      INDIAN OIL CORPORATION LTD
      AUTO CARE CENTRE, INDIRANAGAR
      GSTIN: 29AAACI1681G1ZM
      RECEIPT NO: 88421
      DATE: 14-11-2026  TIME: 10:15 AM
      NOZZLE NO: 02
      FUEL TYPE: XP95 PETROL
      DENSITY: 742.5 KG/M3
      RATE: Rs. 104.50 / LTR
      VOLUME: 15.00 LTR
      --------------------------------
      TOTAL AMOUNT: Rs. 1,567.50
      --------------------------------
      VEHICLE NO: KA01ME1901
      MODE: UPI / CASH
      ''';

      final parsed = ReceiptParser.parse(fuelReceipt);

      expect(parsed.amount, equals(1567.50));
      expect(parsed.amountStatus, equals(AmountExtractionStatus.extracted));
      expect(parsed.invoiceNumber, contains('88421'));
      expect(parsed.categoryId, equals('transport'));
      expect(parsed.date?.day, equals(14));
      expect(parsed.date?.month, equals(11));
      expect(parsed.date?.year, equals(2026));
      expect(parsed.timeString, contains('10:15 AM'));

      // Ensure volume (15.00), rate (104.50), density (742.5), nozzle (2) were not chosen as total
      expect(parsed.amount, isNot(equals(15.0)));
      expect(parsed.amount, isNot(equals(104.50)));
      expect(parsed.amount, isNot(equals(742.5)));
      expect(parsed.amount, isNot(equals(2.0)));
    });

    test('Royal Enfield Service Center Invoice with Spares, Engine Oil, and Job Card', () {
      const reInvoice = '''
      ROYAL ENFIELD AUTHORIZED SERVICE CENTER
      KING MOTORS PVT LTD
      GSTIN: 29AABCK1001N1Z2
      Job Card No: JC-2026-9011
      Retail Invoice No: INV-RE-5542
      Date: 10/11/2026
      Vehicle: Hunter 350 | Reg: KA04EX5512

      1 Liquid Gun Semi-Synthetic Engine Oil    1250.00
      1 Oil Filter Element                      180.00
      1 Chain Clean & Lube Kit                  350.00
      1 General Service Labour Charges          800.00

      Taxable Amount: 2580.00
      CGST @ 9%: 232.20
      SGST @ 9%: 232.20
      Total GST: 464.40
      --------------------------------
      NET PAYABLE: ₹3,044.40
      --------------------------------
      Payment Mode: UPI
      ''';

      final parsed = ReceiptParser.parse(reInvoice);

      expect(parsed.amount, equals(3044.40));
      expect(parsed.subtotal, equals(2580.00));
      expect(parsed.cgst, equals(232.20));
      expect(parsed.sgst, equals(232.20));
      expect(parsed.gstAmount, equals(464.40));
      expect(parsed.taxPercentage, equals(18.0));
      expect(parsed.invoiceNumber, contains('INV-RE-5542'));
      expect(parsed.categoryId, equals('transport'));
      expect(parsed.paymentMethod, equals(PaymentMethod.upi));
    });

    test('Hotel Accommodation Receipt with Room Tariff, Check-In, and IGST', () {
      const hotelBill = '''
      THE GRAND PALACE HOTEL & RESORT
      MALL ROAD, DARJEELING
      GSTIN: 19AAATG2234K1Z8
      Bill No: GPH-2026-110
      Guest Name: Subham Soudeep
      Check-In: 05/11/2026  Check-Out: 08/11/2026
      Room No: 304 (Deluxe Mountain View)

      Room Tariff (3 Nights): ₹12,000.00
      Room Service & Dining:   ₹2,500.00

      Sub Total: ₹14,500.00
      IGST @ 12%: ₹1,740.00
      --------------------------------
      FINAL PAYABLE: ₹16,240.00
      --------------------------------
      Paid via Credit Card
      ''';

      final parsed = ReceiptParser.parse(hotelBill);

      expect(parsed.amount, equals(16240.0));
      expect(parsed.subtotal, equals(14500.0));
      expect(parsed.igst, equals(1740.0));
      expect(parsed.gstAmount, equals(1740.0));
      expect(parsed.taxPercentage, equals(12.0));
      expect(parsed.invoiceNumber, contains('GPH-2026-110'));
      expect(parsed.categoryId, equals('travel'));
      expect(parsed.paymentMethod, equals(PaymentMethod.creditCard));
    });

    test('Medical Store / Pharmacy Bill with DL No, Rx, Subtotal, and Net Amount', () {
      const medicalBill = '''
      APOLLO PHARMACY
      Indiranagar Branch, Bangalore
      DL No: KA-B2-124578  |  GSTIN: 29AABCA8841M1ZN
      Cash Memo No: AP-784512
      Date: 12-11-2026 11:30 AM
      Rx Prescribed by: Dr. Sharma

      1 Dolo 650mg Strip (15 Tab)         32.50
      1 Azithromycin 500mg Strip          115.00
      1 Multivitamin Capsules             240.00
      1 Cough Syrup 100ml                 95.00

      Sub Total: Rs. 482.50
      Discount:  Rs. 32.50
      CGST: Rs. 12.00
      SGST: Rs. 12.00
      --------------------------------
      NET AMOUNT: Rs. 474.00
      --------------------------------
      ''';

      final parsed = ReceiptParser.parse(medicalBill);

      expect(parsed.amount, equals(474.0));
      expect(parsed.subtotal, equals(482.50));
      expect(parsed.cgst, equals(12.0));
      expect(parsed.sgst, equals(12.0));
      expect(parsed.gstAmount, equals(24.0));
      expect(parsed.invoiceNumber, contains('AP-784512'));
      expect(parsed.categoryId, equals('health'));
    });

    test('Supermarket / Grocery D-Mart Receipt', () {
      const dmartReceipt = '''
      DMART - AVENUE SUPERMARTS LTD
      Whitefield, Bengaluru
      Tax Invoice No: DM-881240
      Date: 09/11/2026 17:40:22

      1 Basmati Rice 5kg              450.00
      2 Sunflower Oil 1L              240.00
      1 Aashirvaad Atta 10kg          390.00
      1 Tata Salt 1kg                  24.00

      Item Total: 1,104.00
      Coupon Savings: 54.00
      --------------------------------
      BILL TOTAL: ₹1,050.00
      --------------------------------
      Payment: UPI
      ''';

      final parsed = ReceiptParser.parse(dmartReceipt);

      expect(parsed.amount, equals(1050.0));
      expect(parsed.subtotal, equals(1104.0));
      expect(parsed.invoiceNumber, contains('DM-881240'));
      expect(parsed.categoryId, equals('groceries'));
    });

    test('Online Delivery Swiggy / Blinkit Invoice', () {
      const swiggyReceipt = '''
      SWIGGY INSTAMART
      Bundl Technologies Pvt Ltd
      Order No: #SW-9982410
      Date: 15 Nov 2026, 04:15 PM

      Item Total: ₹340.00
      Delivery Fee: ₹25.00
      Handling Charges: ₹5.00
      GST & Restaurant Charges: ₹18.00
      --------------------------------
      TOTAL PAID: ₹388.00
      --------------------------------
      Paid via UPI
      ''';

      final parsed = ReceiptParser.parse(swiggyReceipt);

      expect(parsed.amount, equals(388.0));
      expect(parsed.subtotal, equals(340.0));
      expect(parsed.invoiceNumber, contains('SW-9982410'));
      expect(parsed.categoryId, equals('groceries'));
      expect(parsed.paymentMethod, equals(PaymentMethod.upi));
    });
  });

  group('2. Offline Expense Persistence & SQLite Sync States', () {
    test('Expense model serialization preserves syncStatus, userId, receiptPath and ocrData', () {
      final now = DateTime.now();
      final ocrData = {
        'merchant': 'Royal Enfield Service',
        'subtotal': 2580.0,
        'gst_amount': 464.4,
        'invoice_number': 'INV-RE-5542',
      };

      final expense = Expense(
        id: 'test-exp-001',
        title: 'Hunter 350 Service',
        amount: 3044.40,
        categoryId: 'transport',
        date: now,
        userId: 'firebase_user_abc123',
        syncStatus: ExpenseSyncStatus.pending,
        receiptPath: '/data/user/0/app/receipts/firebase_user_abc123/test-exp-001.jpg',
        ocrData: ocrData,
      );

      final map = expense.toMap();
      expect(map['id'], equals('test-exp-001'));
      expect(map['user_id'], equals('firebase_user_abc123'));
      expect(map['sync_status'], equals('pending'));
      expect(map['receipt_path'], contains('test-exp-001.jpg'));
      expect(map['ocr_data'], contains('INV-RE-5542'));

      final restored = Expense.fromMap(map);
      expect(restored.id, equals(expense.id));
      expect(restored.amount, equals(3044.40));
      expect(restored.userId, equals('firebase_user_abc123'));
      expect(restored.syncStatus, equals(ExpenseSyncStatus.pending));
      expect(restored.receiptPath, equals(expense.receiptPath));
      expect(restored.ocrData?['invoice_number'], equals('INV-RE-5542'));
    });

    test('DatabaseHelper correctly stores, queries, and updates pending offline expenses', () async {
      final dbHelper = DatabaseHelper.instance;

      final expense1 = Expense(
        id: 'offline-exp-1',
        title: 'Petrol HPCL',
        amount: 500.0,
        categoryId: 'transport',
        date: DateTime.now(),
        userId: 'user_1',
        syncStatus: ExpenseSyncStatus.pending,
        receiptPath: '/local/receipt1.jpg',
      );

      final expense2 = Expense(
        id: 'offline-exp-2',
        title: 'Cafe Coffee Day',
        amount: 250.0,
        categoryId: 'food',
        date: DateTime.now(),
        userId: 'user_1',
        syncStatus: ExpenseSyncStatus.pending,
      );

      final expenseUser2 = Expense(
        id: 'offline-exp-user2',
        title: 'Medicine Medplus',
        amount: 150.0,
        categoryId: 'health',
        date: DateTime.now(),
        userId: 'user_2',
        syncStatus: ExpenseSyncStatus.pending,
      );

      await dbHelper.insertExpense(expense1);
      await dbHelper.insertExpense(expense2);
      await dbHelper.insertExpense(expenseUser2);

      // Account isolation: Query pending expenses for user_1
      final pendingUser1 = await dbHelper.getPendingExpenses(userId: 'user_1');
      expect(pendingUser1.length, equals(2));
      expect(pendingUser1.any((e) => e.id == 'offline-exp-1'), isTrue);
      expect(pendingUser1.any((e) => e.id == 'offline-exp-2'), isTrue);
      expect(pendingUser1.any((e) => e.id == 'offline-exp-user2'), isFalse);

      // Update sync status to synced
      await dbHelper.updateExpenseSyncStatus(
        'offline-exp-1',
        ExpenseSyncStatus.synced,
        cloudImageUrl: 'https://firebasestorage.app/receipt1.jpg',
      );

      final updatedPending = await dbHelper.getPendingExpenses(userId: 'user_1');
      expect(updatedPending.length, equals(1));
      expect(updatedPending.first.id, equals('offline-exp-2'));

      // Clean up test rows
      await dbHelper.deleteExpense('offline-exp-1');
      await dbHelper.deleteExpense('offline-exp-2');
      await dbHelper.deleteExpense('offline-exp-user2');
    });
  });

  group('3. Network Status Service & Offline/Online Transitions', () {
    test('NetworkStatusService provides synchronous reachability notifications', () {
      final network = NetworkStatusService.instance;

      network.setMockOnline(false);
      expect(network.isConnected, isFalse);
      expect(network.isOnline.value, isFalse);

      network.setMockOnline(true);
      expect(network.isConnected, isTrue);
      expect(network.isOnline.value, isTrue);
    });
  });
}
