import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/default_categories.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/transactions_screen.dart';
import 'package:royal_spend/ui/widgets/transaction_detail_modal.dart';
import 'package:royal_spend/ui/widgets/transaction_tile.dart';
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('History Screen & TransactionTile Pixel Overflow Stress Tests', () {
    late SettingsProvider settings;
    late _FakeExpenseRepo fakeExpenseRepo;
    late ExpenseProvider expenseProvider;
    late MockTravelRepository mockTravelRepo;
    late TravelProvider travelProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository();
      settings = SettingsProvider(repository: repo);
      await settings.init();
      fakeExpenseRepo = _FakeExpenseRepo();
      expenseProvider = ExpenseProvider(repository: fakeExpenseRepo);
      mockTravelRepo = MockTravelRepository();
      travelProvider = TravelProvider(repository: mockTravelRepo);
    });

    Widget buildHistoryApp({
      required Widget child,
      Size size = const Size(360, 800),
      double textScaleFactor = 1.0,
      bool isDark = false,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: travelProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('TransactionTile renders without overflow on 320px narrow screen with long titles', (tester) async {
      final trip = Trip(
        id: 'trip_1',
        title: 'Darjeeling Tea Estate Tour',
        destination: 'Darjeeling, West Bengal',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        budget: 200000,
        createdAt: DateTime.now(),
      );
      mockTravelRepo.trips.add(trip);
      await travelProvider.refresh();

      final expense = Expense(
        id: 'exp_stress_1',
        title: 'Extraordinary Himalayan Mountain Biking and Paragliding Expedition',
        amount: 145999.50,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories.first.id,
        paymentMethod: PaymentMethod.bankTransfer,
        tripId: 'trip_1',
      );
      await expenseProvider.addExpense(expense);

      await tester.pumpWidget(
        buildHistoryApp(
          size: const Size(320, 200),
          child: TransactionTile(
            expense: expense,
            currencySymbol: '₹',
            isDark: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero exceptions / zero render overflows
      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionTile), findsOneWidget);
    });

    testWidgets('TransactionTile renders without overflow with large amount and 1.5x font scale', (tester) async {
      final trip = Trip(
        id: 'trip_2',
        title: 'Grand Rajasthan Royal Heritage Tour',
        destination: 'Jaipur & Udaipur',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        budget: 1000000,
        createdAt: DateTime.now(),
      );
      mockTravelRepo.trips.add(trip);
      await travelProvider.refresh();

      final expense = Expense(
        id: 'exp_stress_2',
        title: 'Luxury 5-Star Heritage Palace Suite Booking with All Inclusives',
        amount: 88500000.00,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories[1].id,
        paymentMethod: PaymentMethod.creditCard,
        tripId: 'trip_2',
      );
      await expenseProvider.addExpense(expense);

      await tester.pumpWidget(
        buildHistoryApp(
          size: const Size(340, 250),
          textScaleFactor: 1.5,
          child: TransactionTile(
            expense: expense,
            currencySymbol: '₹',
            isDark: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionTile), findsOneWidget);
    });

    testWidgets('TransactionsScreen renders without overflow on 360px screen with multiple entries & active filters', (tester) async {
      final exp1 = Expense(
        id: 'exp_hist_1',
        title: 'Gourmet Dinner with Wine & Dessert at High-End Fine Dining Bistro',
        amount: 12500.0,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories[0].id,
        paymentMethod: PaymentMethod.creditCard,
      );
      final exp2 = Expense(
        id: 'exp_hist_2',
        title: 'Executive High-Speed Intercity Express Train Ticket & Cab Booking',
        amount: 8400.0,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories[1].id,
        paymentMethod: PaymentMethod.bankTransfer,
        tripId: 'trip_1',
      );
      await expenseProvider.addExpense(exp1);
      await expenseProvider.addExpense(exp2);

      // Active search query triggers Reset button in header
      expenseProvider.setSearchQuery('Dining');

      await tester.pumpWidget(
        buildHistoryApp(
          size: const Size(360, 800),
          child: const TransactionsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Expense History'), findsOneWidget);
      expect(find.text('Total Spend: '), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('TransactionsScreen renders without overflow under 1.4x text scale and narrow width', (tester) async {
      final exp1 = Expense(
        id: 'exp_hist_3',
        title: 'Supermarket Grocery Haul & Household Essentials Purchase',
        amount: 45290.75,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories[2].id,
        paymentMethod: PaymentMethod.upi,
      );
      await expenseProvider.addExpense(exp1);

      await tester.pumpWidget(
        buildHistoryApp(
          size: const Size(340, 750),
          textScaleFactor: 1.4,
          isDark: true,
          child: const TransactionsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Expense History'), findsOneWidget);
      expect(find.text('Total Spend: '), findsOneWidget);
    });

    testWidgets('TransactionDetailModal renders without overflow on compact screen height with long notes', (tester) async {
      final trip = Trip(
        id: 'trip_conf',
        title: 'Global Tech Summit 2026',
        destination: 'Bengaluru Tech Park',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        budget: 150000,
        createdAt: DateTime.now(),
      );
      mockTravelRepo.trips.add(trip);
      await travelProvider.refresh();

      final detailedExpense = Expense(
        id: 'exp_modal_1',
        title: 'Corporate Conference Registration & Accommodation',
        amount: 75000.0,
        date: DateTime.now(),
        categoryId: DefaultCategories.categories[3].id,
        paymentMethod: PaymentMethod.bankTransfer,
        notes: 'Includes keynote ticket, VIP networking dinner access, workshops on AI & Cloud Computing, and 3 nights deluxe hotel stay with complimentary breakfast.',
        tripId: 'trip_conf',
      );
      await expenseProvider.addExpense(detailedExpense);

      await tester.pumpWidget(
        buildHistoryApp(
          size: const Size(360, 500), // Shorter height (e.g. landscape or small phone)
          child: TransactionDetailModal(expense: detailedExpense),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Corporate Conference Registration & Accommodation'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Associated Trip'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });
  });
}
