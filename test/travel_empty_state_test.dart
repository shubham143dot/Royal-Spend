import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/travel/create_plan_wizard_screen.dart';
import 'package:royal_spend/ui/screens/travel/travel_dashboard_screen.dart';

import 'travel_multi_plan_isolation_test.dart';

class _FakeExpenseRepo extends IExpenseRepository {
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
  Future<void> updateExpense(Expense expense) async {}
}

Widget createTestApp(Widget child, TravelProvider travelProvider,
    SettingsProvider settingsProvider, ExpenseProvider expenseProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TravelProvider>.value(value: travelProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Travel Dashboard - Redesigned Empty State Tests', () {
    late MockTravelRepository mockRepo;
    late TravelProvider travelProvider;
    late SettingsProvider settingsProvider;
    late ExpenseProvider expenseProvider;

    setUp(() {
      mockRepo = MockTravelRepository();
      travelProvider = TravelProvider(repository: mockRepo);
      settingsProvider = SettingsProvider(repository: SettingsRepository());
      expenseProvider = ExpenseProvider(repository: _FakeExpenseRepo());
    });

    testWidgets('Empty travel state renders prestige badge, headline, pillars, and chips',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // trips are empty by default
      await tester.pumpWidget(createTestApp(
        const TravelDashboardScreen(),
        travelProvider,
        settingsProvider,
        expenseProvider,
      ));
      await tester.pumpAndSettle();

      // Verify prestige badge capsule
      expect(find.text('ROYAL EXPEDITIONS'), findsOneWidget);

      // Verify aspirational headline and subtitle
      expect(find.text('Where Will You Wander?'), findsOneWidget);
      expect(
        find.text(
            'Chart your dream journey, allocate budgets with clarity, and organize every day effortlessly.'),
        findsOneWidget,
      );

      // Verify core feature pillars
      expect(find.text('Smart Days'), findsOneWidget);
      expect(find.text('Budgeting'), findsOneWidget);
      expect(find.text('Live Places'), findsOneWidget);

      // Verify popular inspiration chips
      expect(find.text('POPULAR INSPIRATIONS'), findsOneWidget);
      expect(find.text('🏔️ Mountain Trek'), findsOneWidget);
      expect(find.text('🏖️ Coastal Escape'), findsOneWidget);
      expect(find.text('🏛️ Heritage Tour'), findsOneWidget);
      expect(find.text('🌆 City Lights'), findsOneWidget);

      // Verify primary CTA button
      expect(find.text('+ Create Your First Plan'), findsOneWidget);

      // Verify trust reassurance footer
      expect(
          find.text('Offline-First • 100% Private On Device'), findsOneWidget);
    });

    testWidgets('Tapping "+ Create Your First Plan" button opens wizard',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(
        const TravelDashboardScreen(),
        travelProvider,
        settingsProvider,
        expenseProvider,
      ));
      await tester.pumpAndSettle();

      final ctaFinder = find.text('+ Create Your First Plan');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(find.byType(CreatePlanWizardScreen), findsOneWidget);
    });

    testWidgets('Tapping inspiration chip pre-fills the wizard with destination and title',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(
        const TravelDashboardScreen(),
        travelProvider,
        settingsProvider,
        expenseProvider,
      ));
      await tester.pumpAndSettle();

      final chipFinder = find.text('🏖️ Coastal Escape');
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Verify wizard opened
      expect(find.byType(CreatePlanWizardScreen), findsOneWidget);

      // Verify prefilled values
      expect(find.text('Coastal Goa Getaway'), findsOneWidget);
      expect(find.text('Goa, India'), findsOneWidget);
    });
  });
}
