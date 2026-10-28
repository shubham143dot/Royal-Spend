import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';
import 'package:royal_spend/ui/screens/travel/create_plan_wizard_screen.dart';
import 'package:royal_spend/ui/screens/travel/travel_dashboard_screen.dart';
import 'package:royal_spend/ui/screens/travel/trip_workspace_screen.dart';
import 'package:royal_spend/ui/widgets/travel/liquid_add_travel_expense_fab.dart';
import 'package:royal_spend/ui/widgets/travel/quick_travel_expense_sheet.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'travel_multi_plan_isolation_test.dart';

class _FakeExpenseRepo implements IExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<void> addExpense(Expense expense) async => _expenses.add(expense);
  @override
  Future<void> clearAllData() async => _expenses.clear();
  @override
  Future<void> deleteExpense(String id) async =>
      _expenses.removeWhere((e) => e.id == id);
  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_expenses);
  @override
  Future<Budget?> getBudget(int year, int month) async => null;
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async =>
      List.from(_expenses);
  @override
  Future<void> saveBudget(Budget budget) async {}
  @override
  Future<void> seedRealisticSampleData() async {}
  @override
  Future<void> updateExpense(Expense expense) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) _expenses[idx] = expense;
  }
}

void main() {
  group('Travel Planner UI & Interaction Tests', () {
    late MockTravelRepository mockRepo;
    late TravelProvider travelProvider;
    late SettingsProvider settingsProvider;
    late ExpenseProvider expenseProvider;
    late QuickLogProvider quickLogProvider;

    setUp(() async {
      mockRepo = MockTravelRepository();
      travelProvider = TravelProvider(repository: mockRepo);
      settingsProvider = SettingsProvider(repository: SettingsRepository());
      final fakeExpenseRepo = _FakeExpenseRepo();
      expenseProvider = ExpenseProvider(repository: fakeExpenseRepo);
      quickLogProvider = QuickLogProvider();

      // Pre-populate with Darjeeling test plan
      final darjeelingTrip = Trip(
        id: 'trip-darjeeling-ui',
        title: 'Darjeeling Trip',
        destination: 'Darjeeling, West Bengal',
        departureCity: 'Hijli',
        startDate: DateTime(2026, 12, 10),
        endDate: DateTime(2026, 12, 18),
        budget: 25000,
        status: TripStatus.upcoming,
      );
      mockRepo.trips.add(darjeelingTrip);

      final day1 = ItineraryDay(
        id: 'day-1-ui',
        tripId: darjeelingTrip.id,
        dayNumber: 1,
        date: DateTime(2026, 12, 10),
      );
      mockRepo.days.add(day1);

      mockRepo.activities.add(
        ItineraryActivity(
          id: 'act-train-ui',
          tripId: darjeelingTrip.id,
          dayId: day1.id,
          title: 'MAS NJP SF Express Train',
          placeName: 'Hijli Station',
          startTime: '10:50 AM',
          category: ActivityCategory.transport,
          estimatedCost: 1450,
          isOvernight: true,
        ),
      );

      await travelProvider.initialize();
    });

    Widget createTestApp(Widget home) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: quickLogProvider),
          ChangeNotifierProvider.value(value: travelProvider),
        ],
        child: MaterialApp(
          title: AppConstants.appName,
          theme: AppTheme.lightTheme,
          home: home,
        ),
      );
    }

    testWidgets('Tapping Travel in navigation bar opens Travel Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const MainNavigationScreen()));
      await tester.pumpAndSettle();

      // Find Travel nav tab with airplane icon
      final travelNavFinder = find.text('Travel');
      expect(travelNavFinder, findsOneWidget);

      // Tap Travel tab
      await tester.tap(travelNavFinder);
      await tester.pumpAndSettle();

      // Verify Travel dashboard header
      expect(find.text('Your Adventures'), findsOneWidget);
      expect(find.text('Every journey, beautifully planned.'), findsOneWidget);
      expect(find.text('+ Create New Plan'), findsOneWidget);

      // Verify Darjeeling Trip card is displayed
      expect(find.text('Darjeeling Trip'), findsOneWidget);
      expect(find.text('Darjeeling, West Bengal'), findsOneWidget);
    });

    testWidgets('Tapping a trip card opens Trip Workspace screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const TravelDashboardScreen()));
      await tester.pumpAndSettle();

      // Verify trip card is visible
      final cardFinder = find.text('Darjeeling Trip');
      expect(cardFinder, findsOneWidget);

      // Tap card
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Verify Trip Workspace is active
      expect(find.byType(TripWorkspaceScreen), findsOneWidget);
      expect(find.text('Darjeeling Trip'), findsWidgets);

      // Verify tabs inside workspace
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Itinerary'), findsOneWidget);
      expect(find.text('Map & Places'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Checklist'), findsWidgets);
    });

    testWidgets('Create Plan Wizard renders steps and planning methods cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const CreatePlanWizardScreen()));
      await tester.pumpAndSettle();

      // Verify header and initial step
      expect(find.text('Create New Plan'), findsOneWidget);
      expect(find.text('Where are you going?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Expense FAB is on Expenses tab, Travel FAB is on Travel tab, others have none', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const MainNavigationScreen()));
      await tester.pumpAndSettle();

      // On Expenses tab (index 0), expense FAB is present
      final scaffoldExpenses = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffoldExpenses.floatingActionButton, isNotNull);

      // Switch to Travel tab (index 2): travel FAB is present
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      final scaffoldTravel = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffoldTravel.floatingActionButton, isA<LiquidAddTravelExpenseFab>());

      // Switch to History tab (index 1): FAB is null
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      final scaffoldHistory = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffoldHistory.floatingActionButton, isNull);

      // Switch to Analytics tab (index 3): FAB is null
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      final scaffoldAnalytics = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffoldAnalytics.floatingActionButton, isNull);
    });

    testWidgets('QuickTravelExpenseSheet supports multiple trips and records expense correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Add a second trip to test multi-trip selection
      final tripGoa = Trip(
        id: 'trip-goa-ui',
        title: 'Goa Getaway',
        destination: 'Goa, India',
        departureCity: 'Mumbai',
        startDate: DateTime(2027, 1, 15),
        endDate: DateTime(2027, 1, 20),
        budget: 18000,
        status: TripStatus.upcoming,
      );
      mockRepo.trips.add(tripGoa);
      await travelProvider.loadTrips();

      await tester.pumpWidget(createTestApp(
        const Scaffold(
          body: QuickTravelExpenseSheet(initialTripId: 'trip-darjeeling-ui'),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify sheet is rendered with Darjeeling Trip pre-selected
      expect(find.text('Quick Travel Expense'), findsOneWidget);
      expect(find.text('Darjeeling Trip'), findsOneWidget);

      // Tap Change button to open trip picker modal
      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      // Verify trip picker shows both trips
      expect(find.text('Select Target Trip'), findsOneWidget);
      expect(find.text('Goa Getaway'), findsOneWidget);

      // Tap Goa Getaway
      await tester.tap(find.text('Goa Getaway'));
      await tester.pumpAndSettle();

      // Target trip is now Goa Getaway
      expect(find.text('Goa Getaway'), findsOneWidget);

      // Enter amount
      await tester.enterText(find.byKey(const Key('quick_travel_amount_field')), '650');
      await tester.pumpAndSettle();

      // Tap a quick suggestion chip e.g. 'Food & Drinks'
      await tester.tap(find.text('Food & Drinks'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Record Travel Expense'));
      await tester.pumpAndSettle();

      // Verify expense was recorded in ExpenseProvider with tripId
      expect(expenseProvider.allExpenses.any((e) => e.tripId == 'trip-goa-ui' && e.amount == 650.0), isTrue);
    });

    testWidgets('Itinerary tab renders day selector cleanly without bottom overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const TripWorkspaceScreen(tripId: 'trip-darjeeling-ui')));
      await tester.pumpAndSettle();

      // Tap Itinerary tab
      await tester.tap(find.text('Itinerary'));
      await tester.pumpAndSettle();

      // Verify Day 1 selector card is rendered
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('10 Dec'), findsOneWidget);

      // Verify no RenderFlex overflow exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });
}
