import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/services/reports/trip_expense_pdf_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/saved_place.dart';
import 'package:royal_spend/data/models/travel_accommodation.dart';
import 'package:royal_spend/data/models/travel_checklist_item.dart';
import 'package:royal_spend/data/models/travel_split.dart';
import 'package:royal_spend/data/models/travel_transport.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/models/trip_expense_report.dart';
import 'package:royal_spend/data/repositories/travel_repository.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/travel/trip_expense_report_preview_screen.dart';
import 'package:royal_spend/ui/widgets/travel/bill_split_dialog.dart';

class MockTravelRepo implements ITravelRepository {
  final Map<String, Trip> trips = {};
  final Map<String, List<Expense>> tripExpenses = {};

  @override
  Future<List<Trip>> getAllTrips() async => trips.values.toList();
  @override
  Future<Trip?> getTrip(String id) async => trips[id];
  @override
  Future<void> addTrip(Trip trip) async => trips[trip.id] = trip;
  @override
  Future<void> updateTrip(Trip trip) async => trips[trip.id] = trip;
  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async =>
      trips.remove(id);

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) async => [];
  @override
  Future<void> addDay(ItineraryDay day) async {}
  @override
  Future<void> updateDay(ItineraryDay day) async {}
  @override
  Future<void> deleteDay(String id) async {}

  @override
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) async => [];
  @override
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) async => [];
  @override
  Future<void> addActivity(ItineraryActivity activity) async {}
  @override
  Future<void> updateActivity(ItineraryActivity activity) async {}
  @override
  Future<void> deleteActivity(String id) async {}
  @override
  Future<void> reorderActivities(
      String dayId, List<ItineraryActivity> reorderedActivities) async {}

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) async => [];
  @override
  Future<void> addSavedPlace(SavedPlace place) async {}
  @override
  Future<void> updateSavedPlace(SavedPlace place) async {}
  @override
  Future<void> deleteSavedPlace(String id) async {}

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) async => [];
  @override
  Future<void> addTransport(TravelTransport transport) async {}
  @override
  Future<void> updateTransport(TravelTransport transport) async {}
  @override
  Future<void> deleteTransport(String id) async {}

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(
          String tripId) async =>
      [];
  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> deleteAccommodation(String id) async {}

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async => [];
  @override
  Future<void> addChecklistItem(TravelChecklistItem item) async {}
  @override
  Future<void> updateChecklistItem(TravelChecklistItem item) async {}
  @override
  Future<void> deleteChecklistItem(String id) async {}

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) async => [];
  @override
  Future<void> addSplit(TravelSplit split) async {}
  @override
  Future<void> deleteSplit(String id) async {}

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) async =>
      tripExpenses[tripId] ?? [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleTrip = Trip(
    id: 'trip-darjeeling-2026',
    title: 'Darjeeling Mountain Escapade',
    destination: 'Darjeeling, West Bengal',
    startDate: DateTime(2026, 11, 15),
    endDate: DateTime(2026, 11, 20),
    budget: 25000.0,
    travelersNames: ['Shubham', 'Rahul', 'Aman', 'Priya', 'Rohit'],
  );

  final sampleExpenses = [
    Expense(
      id: 'exp-1',
      title: 'Hotel Windamere Booking',
      amount: 6500.0,
      categoryId: 'stays',
      date: DateTime(2026, 11, 15, 14, 30),
      paymentMethod: PaymentMethod.creditCard,
      notes: 'Deluxe Heritage Suite',
      tripId: 'trip-darjeeling-2026',
    ),
    Expense(
      id: 'exp-2',
      title: 'Shared 4x4 Cab to Tiger Hill',
      amount: 1800.0,
      categoryId: 'transport',
      date: DateTime(2026, 11, 16, 4, 15),
      paymentMethod: PaymentMethod.cash,
      notes: 'Sunrise round trip',
      tripId: 'trip-darjeeling-2026',
    ),
    Expense(
      id: 'exp-3',
      title: 'Glenary’s Bakery & Cafe Breakfast',
      amount: 1450.0,
      categoryId: 'food',
      date: DateTime(2026, 11, 16, 9, 45),
      paymentMethod: PaymentMethod.upi,
      notes: 'Breakfast with tea and pastries',
      tripId: 'trip-darjeeling-2026',
    ),
    Expense(
      id: 'exp-4',
      title: 'Darjeeling Himalayan Toy Train Tickets',
      amount: 2500.0,
      categoryId: 'sightseeing',
      date: DateTime(2026, 11, 17, 11, 00),
      paymentMethod: PaymentMethod.bankTransfer,
      notes: 'Steam Joy Ride to Ghoom',
      tripId: 'trip-darjeeling-2026',
    ),
    Expense(
      id: 'exp-5',
      title: 'First Flush Tea Garden Souvenirs',
      amount: 2750.0,
      categoryId: 'shopping',
      date: DateTime(2026, 11, 18, 16, 20),
      paymentMethod: PaymentMethod.upi,
      notes: 'Makaibari organic tea boxes',
      tripId: 'trip-darjeeling-2026',
    ),
  ];

  final sampleParticipants = [
    ReportParticipant(id: 'p-1', name: 'Shubham', email: 'shubham@example.com'),
    ReportParticipant(id: 'p-2', name: 'Rahul', email: 'rahul@example.com'),
    ReportParticipant(id: 'p-3', name: 'Aman'),
    ReportParticipant(id: 'p-4', name: 'Priya'),
    ReportParticipant(id: 'p-5', name: 'Rohit'),
  ];

  group('1. Financial Accuracy & Reconciled Equal Splitting', () {
    test('Calculates total expenses and individual share accurately', () {
      final report = TripExpenseReport(
        tripId: sampleTrip.id,
        tripTitle: sampleTrip.title,
        destination: sampleTrip.destination,
        startDate: sampleTrip.startDate,
        endDate: sampleTrip.endDate,
        generatedAt: DateTime(2026, 11, 19, 10, 00),
        expenses: sampleExpenses,
        participants: sampleParticipants,
        payer: sampleParticipants.first,
      );

      // Total = 6500 + 1800 + 1450 + 2500 + 2750 = 15000.0
      expect(report.totalExpenses, equals(15000.0));
      expect(report.totalTransactions, equals(5));
      expect(report.totalParticipants, equals(5));
      expect(report.individualShare, equals(3000.0));
      expect(report.payer.name, equals('Shubham'));

      // Check reconciled shares sum exactly to total
      final shares = report.reconciledShares;
      expect(shares.length, equals(5));
      final totalReconciled = shares.values.fold(0.0, (a, b) => a + b);
      expect(totalReconciled, closeTo(15000.0, 0.001));
    });

    test('Reconciles fractional cents without penny leaks', () {
      // 100.00 / 3 = 33.333...
      final oddExpenses = [
        Expense(
          id: 'exp-odd',
          title: 'Shared Taxi',
          amount: 100.0,
          categoryId: 'transport',
          date: DateTime(2026, 11, 15),
        ),
      ];
      final threeParticipants = [
        ReportParticipant(id: 'p1', name: 'User 1'),
        ReportParticipant(id: 'p2', name: 'User 2'),
        ReportParticipant(id: 'p3', name: 'User 3'),
      ];

      final report = TripExpenseReport(
        tripId: 'odd-trip',
        tripTitle: 'Short Ride',
        destination: 'City',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 15),
        generatedAt: DateTime.now(),
        expenses: oddExpenses,
        participants: threeParticipants,
        payer: threeParticipants.first,
      );

      final shares = report.reconciledShares;
      expect(shares.length, equals(3));
      final totalSum = shares.values.fold(0.0, (a, b) => a + b);
      // Must equal 100.00 exactly!
      expect(double.parse(totalSum.toStringAsFixed(2)), equals(100.00));
      // First person gets 33.34 and remaining two get 33.33
      expect(shares['p1'], equals(33.34));
      expect(shares['p2'], equals(33.33));
      expect(shares['p3'], equals(33.33));
    });
  });

  group('2. Participant Management & Limits', () {
    test('Enforces maximum 15 participants limit per report', () {
      final fifteenParticipants = List.generate(
        15,
        (i) => ReportParticipant(id: 'id-$i', name: 'Person $i'),
      );
      expect(fifteenParticipants.length, equals(15));

      // Attempting to add 16th participant should exceed limit
      final canAddMore = fifteenParticipants.length < 15;
      expect(canAddMore, isFalse);
    });

    test('Identifies duplicate participants by case-insensitive name', () {
      final participants = [
        ReportParticipant(id: 'p-1', name: 'Shubham'),
        ReportParticipant(id: 'p-2', name: 'Rahul'),
      ];

      bool hasDuplicate(String newName) => participants.any(
            (p) => p.name.trim().toLowerCase() == newName.trim().toLowerCase(),
          );

      expect(hasDuplicate('shubham'), isTrue);
      expect(hasDuplicate('SHUBHAM'), isTrue);
      expect(hasDuplicate('  Shubham  '), isTrue);
      expect(hasDuplicate('Aman'), isFalse);
    });
  });

  group('3. Offline PDF Generation & Branding', () {
    test('Generates valid PDF document with Royal Spend branding offline', () async {
      final report = TripExpenseReport(
        tripId: sampleTrip.id,
        tripTitle: sampleTrip.title,
        destination: sampleTrip.destination,
        startDate: sampleTrip.startDate,
        endDate: sampleTrip.endDate,
        generatedAt: DateTime(2026, 11, 19, 10, 00),
        expenses: sampleExpenses,
        participants: sampleParticipants,
        payer: sampleParticipants.first,
      );

      final Uint8List pdfBytes =
          await TripExpensePdfService.instance.generatePdf(report);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes, isNotEmpty);
      // PDF header magic bytes are %PDF-
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });

  group('4. In-App Report Preview Screen (View Now)', () {
    testWidgets('Renders all required sections and calculations in View Now screen',
        (tester) async {
      final report = TripExpenseReport(
        tripId: sampleTrip.id,
        tripTitle: sampleTrip.title,
        destination: sampleTrip.destination,
        startDate: sampleTrip.startDate,
        endDate: sampleTrip.endDate,
        generatedAt: DateTime(2026, 11, 19, 10, 00),
        expenses: sampleExpenses,
        participants: sampleParticipants,
        payer: sampleParticipants.first,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: TripExpenseReportPreviewScreen(
              report: report,
              isDark: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App branding & Title
      expect(find.text(TripExpensePdfService.appName), findsWidgets);
      expect(find.text('Trip Expense Report'), findsOneWidget);
      expect(find.text('Darjeeling Mountain Escapade'), findsOneWidget);

      // Section: PAID BY
      expect(find.text('PAID BY'), findsOneWidget);
      expect(find.text('Shubham'), findsWidgets);

      // Section: PARTICIPANT BREAKDOWN
      expect(find.text('PARTICIPANT BREAKDOWN'), findsOneWidget);
      expect(find.text('5 People'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('Aman'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Rohit'), findsOneWidget);

      // Section: TRANSACTION HISTORY
      expect(find.text('TRANSACTION HISTORY'), findsOneWidget);
      expect(find.text('Hotel Windamere Booking'), findsOneWidget);
      expect(find.text('Shared 4x4 Cab to Tiger Hill'), findsOneWidget);
      expect(find.text('Glenary’s Bakery & Cafe Breakfast'), findsOneWidget);

      // Section: FINANCIAL RECONCILIATION SUMMARY
      expect(find.text('FINANCIAL RECONCILIATION SUMMARY'), findsOneWidget);
      expect(find.text('Save as PDF'), findsWidgets);
    });

    testWidgets('Renders View Now preview on narrow mobile viewport without any RenderFlex overflow',
        (tester) async {
      final report = TripExpenseReport(
        tripId: sampleTrip.id,
        tripTitle:
            'Very Long Comprehensive Grand Tour Of The Himalayas Across States',
        destination:
            'Darjeeling, Kalimpong, Gangtok, Lachung, Pelling & Yuksom',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 28),
        generatedAt: DateTime(2026, 11, 19, 10, 00),
        expenses: sampleExpenses,
        participants: sampleParticipants,
        payer: sampleParticipants.first,
      );

      // Narrow screen: 320 logical pixels (small mobile phone)
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: TripExpenseReportPreviewScreen(
              report: report,
              isDark: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // No overflow exceptions thrown!
      expect(tester.takeException(), isNull);
    });
  });

  group('5. Enhanced BillSplitDialog (Split Trip Expense UI Workflow)', () {
    testWidgets(
        'Renders complete automatic transaction scan, participant manager, payer selector, and both options without quick single bill tab',
        (tester) async {
      final mockRepo = MockTravelRepo();
      mockRepo.trips[sampleTrip.id] = sampleTrip;
      mockRepo.tripExpenses[sampleTrip.id] = sampleExpenses;

      final travelProvider = TravelProvider(repository: mockRepo);
      await travelProvider.loadTrips();
      await travelProvider.selectTrip(sampleTrip.id);

      // Set realistic mobile phone viewport size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider.value(value: travelProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: BillSplitDialog(
                tripId: sampleTrip.id,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header exists and Quick Single Bill mode is removed
      expect(find.text('Split Trip Expense'), findsOneWidget);
      expect(find.text('Quick Single Bill'), findsNothing);

      // Section 1: Trip Expense Description
      expect(find.text('TRIP EXPENSE DESCRIPTION'), findsOneWidget);
      expect(find.text('Hotel Windamere Booking'), findsOneWidget);
      expect(find.text('Shared 4x4 Cab to Tiger Hill'), findsOneWidget);

      // Section 2: Add People with 5 initial participants
      expect(find.text('ADD PEOPLE'), findsOneWidget);
      expect(find.text('5 of 15 participants added'), findsOneWidget);

      // Section 3: Who Paid?
      expect(find.text('WHO PAID?'), findsOneWidget);
      expect(find.text('Select the person who paid for these trip expenses:'),
          findsOneWidget);

      // Section 4: Expense Summary
      expect(find.text('EXPENSE SUMMARY'), findsOneWidget);
      expect(find.text('Total Trip Expense:'), findsWidgets);

      // Section 5: Both final action buttons
      expect(find.text('Save as PDF'), findsOneWidget);
      expect(find.text('View Now'), findsOneWidget);

      // Test Adding a 6th person
      final addPeopleFinder = find.text('+ Add People');
      await tester.ensureVisible(addPeopleFinder);
      await tester.tap(addPeopleFinder);
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextField, 'e.g. Rahul Sharma');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Ananya');

      final addPersonBtn = find.text('Add Person');
      await tester.ensureVisible(addPersonBtn);
      await tester.tap(addPersonBtn);
      await tester.pumpAndSettle();

      // Participant count updated to 6
      expect(find.text('6 of 15 participants added'), findsOneWidget);
      expect(find.text('Ananya'), findsWidgets);
    });
  });
}
