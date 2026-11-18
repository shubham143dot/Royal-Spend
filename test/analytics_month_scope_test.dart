import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/analytics_screen.dart';
import 'travel_multi_plan_isolation_test.dart';

class _FakeExpenseRepo extends IExpenseRepository {
  final List<Expense> expenses = [];

  @override
  Future<void> addExpense(Expense expense) async => expenses.add(expense);
  @override
  Future<void> clearAllData() async => expenses.clear();
  @override
  Future<void> deleteExpense(String id) async =>
      expenses.removeWhere((e) => e.id == id);
  @override
  Future<List<Expense>> getAllExpenses() async => List.from(expenses);
  @override
  Future<Budget?> getBudget(int year, int month) async => null;
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async =>
      List.from(expenses);
  @override
  Future<void> saveBudget(Budget budget) async {}
  @override
  Future<void> seedRealisticSampleData() async {}
  @override
  Future<void> updateExpense(Expense expense) async {
    final idx = expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) expenses[idx] = expense;
  }
}

void main() {
  group('Analytics Screen - Month Selection & Personal <-> Travel Switcher Tests', () {
    late _FakeExpenseRepo fakeExpenseRepo;
    late MockTravelRepository mockTravelRepo;
    late ExpenseProvider expenseProvider;
    late TravelProvider travelProvider;
    late SettingsProvider settingsProvider;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 5);
    final prevMonthDate = DateTime(now.year, now.month - 1, 10);

    setUp(() async {
      fakeExpenseRepo = _FakeExpenseRepo();
      mockTravelRepo = MockTravelRepository();
      expenseProvider = ExpenseProvider(repository: fakeExpenseRepo);
      travelProvider = TravelProvider(repository: mockTravelRepo);
      settingsProvider = SettingsProvider(repository: SettingsRepository());

      // Add a Personal expense in current month
      fakeExpenseRepo.expenses.add(
        Expense(
          id: 'exp-personal-01',
          title: 'Groceries at Supermarket',
          amount: 2450.0,
          categoryId: 'food',
          date: currentMonthStart,
          paymentMethod: PaymentMethod.upi,
          tripId: null, // Personal
        ),
      );

      // Add a Travel expense in current month
      fakeExpenseRepo.expenses.add(
        Expense(
          id: 'exp-travel-01',
          title: 'Mountain Sightseeing Taxi',
          amount: 1800.0,
          categoryId: 'transport',
          date: currentMonthStart,
          paymentMethod: PaymentMethod.cash,
          tripId: 'trip-darjeeling-01', // Travel
        ),
      );

      // Add a Travel expense in previous month
      fakeExpenseRepo.expenses.add(
        Expense(
          id: 'exp-travel-prev',
          title: 'Advance Hotel Booking',
          amount: 5000.0,
          categoryId: 'entertainment',
          date: prevMonthDate,
          paymentMethod: PaymentMethod.creditCard,
          tripId: 'trip-darjeeling-01',
        ),
      );

      // Add corresponding trip
      mockTravelRepo.trips.add(
        Trip(
          id: 'trip-darjeeling-01',
          title: 'Darjeeling Autumn Tour',
          destination: 'Darjeeling, WB',
          departureCity: 'Kolkata',
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month, 15),
          budget: 20000.0,
          status: TripStatus.inProgress,
        ),
      );

      await expenseProvider.init();
      await travelProvider.initialize();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: travelProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AnalyticsScreen(),
          ),
        ),
      );
    }

    testWidgets('Renders Spending Insights header, month capsule, and scope segmented control',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Spending Insights'), findsOneWidget);

      // Check scope segmented control (Personal and Travel buttons)
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);

      // Check current month formatted text
      final currentMonthText = DateFormat('MMMM yyyy').format(now);
      expect(find.text(currentMonthText), findsOneWidget);

      // In personal mode, personal expense category (Food & Dining) is visible
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('₹2,450'), findsWidgets);

      // Travel expense (Transportation ₹1,800) should NOT be in personal view
      expect(find.text('₹1,800'), findsNothing);
    });

    testWidgets('Tapping Travel switches to Travel scope smoothly without exceptions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Travel segment
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      // Subtitle updates to Travel analysis
      expect(find.text('Monthly Travel & Vacation Analysis'), findsOneWidget);

      // Travel expense (₹1,800) is now visible
      expect(find.text('₹1,800'), findsWidgets);

      // Active trip card displays Darjeeling Autumn Tour
      expect(find.text('Darjeeling Autumn Tour'), findsOneWidget);

      // Personal expense (Food & Dining ₹2,450) is NOT in travel view
      expect(find.text('₹2,450'), findsNothing);
    });

    testWidgets('Switching back from Travel to Personal works cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Travel
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
      expect(find.text('₹1,800'), findsWidgets);

      // Switch back to Personal
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      // Personal items restored
      expect(find.text('Monthly Personal Spending & Trends'), findsOneWidget);
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('₹2,450'), findsWidgets);
      expect(find.text('₹1,800'), findsNothing);
    });

    testWidgets('Navigating previous month updates data and shows Current button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Travel mode
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      // Tap previous month via the left chevron button next to the month pill
      await tester.tap(find.byIcon(CupertinoIcons.chevron_left).first);
      await tester.pumpAndSettle();

      // Month has changed: Current month shortcut button is now visible
      expect(find.text('Current'), findsOneWidget);

      // Previous month travel expense (₹5,000) is now displayed
      expect(find.text('₹5,000'), findsWidgets);

      // Tap Current shortcut button to return to current month
      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();

      // Returned to current month
      final currentMonthText = DateFormat('MMMM yyyy').format(now);
      expect(find.text(currentMonthText), findsOneWidget);
      expect(find.text('Current'), findsNothing);
    });

    testWidgets('Tapping month pill opens Month Picker bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap month title pill
      final currentMonthText = DateFormat('MMMM yyyy').format(now);
      await tester.tap(find.text(currentMonthText));
      await tester.pumpAndSettle();

      // Month picker modal is open
      expect(find.text('Select Month & Year'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
      await tester.pumpAndSettle();

      expect(find.text('Select Month & Year'), findsNothing);
    });
  });
}
