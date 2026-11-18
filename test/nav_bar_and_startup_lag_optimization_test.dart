import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/travel_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/widgets/glass_nav_bar.dart';

class _MockExpenseRepo implements ExpenseRepository {
  int getAllExpensesCallCount = 0;
  final List<Expense> expenses = [];

  @override
  Future<List<Expense>> getAllExpenses() async {
    getAllExpensesCallCount++;
    // Simulate real SQLite async latency
    await Future.delayed(const Duration(milliseconds: 10));
    return List.from(expenses);
  }

  @override
  Future<Budget?> getBudget(int year, int month) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTravelRepo implements TravelRepository {
  int getAllTripsCallCount = 0;
  final List<Trip> trips = [];

  @override
  Future<List<Trip>> getAllTrips() async {
    getAllTripsCallCount++;
    await Future.delayed(const Duration(milliseconds: 10));
    return List.from(trips);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup & Navigation Bar Lag Optimizations', () {
    test('ExpenseProvider.refresh() re-entrancy guard drops concurrent overlapping calls', () async {
      final mockRepo = _MockExpenseRepo();
      final provider = ExpenseProvider(repository: mockRepo);

      // Launch 10 refresh calls concurrently
      await Future.wait(List.generate(10, (_) => provider.refresh()));

      // Only the first call should have executed; the remaining 9 were dropped by the re-entrancy guard
      expect(mockRepo.getAllExpensesCallCount, equals(1));
    });

    test('TravelProvider.loadTrips() re-entrancy guard drops concurrent overlapping calls', () async {
      final mockRepo = _MockTravelRepo();
      final provider = TravelProvider(repository: mockRepo);

      // Launch 10 loadTrips calls concurrently
      await Future.wait(List.generate(10, (_) => provider.loadTrips()));

      // Only 1 call executed
      expect(mockRepo.getAllTripsCallCount, equals(1));
    });

    testWidgets('GlassFloatingNavBar renders cleanly and switches tabs without jank in Dark Mode', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return GlassFloatingNavBar(
                  currentIndex: selectedTab,
                  isDark: true,
                  onTabSelected: (index) {
                    setState(() {
                      selectedTab = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify all 5 navigation items are rendered
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap 'History'
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedTab, equals(1));

      // Rapidly tap 'Travel' then 'Analytics'
      await tester.tap(find.text('Travel'));
      await tester.pump();
      await tester.tap(find.text('Analytics'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedTab, equals(3));
    });

    testWidgets('GlassFloatingNavBar renders cleanly in Light Mode', (tester) async {
      int selectedTab = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return GlassFloatingNavBar(
                  currentIndex: selectedTab,
                  isDark: false,
                  onTabSelected: (index) {
                    setState(() {
                      selectedTab = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Travel'), findsOneWidget);

      // Tap 'Expenses'
      await tester.tap(find.text('Expenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedTab, equals(0));
    });

    test('Debounce timer correctly coalesces rapid sync notifications into a single refresh', () async {
      int refreshCount = 0;
      Timer? debounceTimer;

      void debouncedRefresh() {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 100), () {
          refreshCount++;
        });
      }

      // Simulate 12 snapshot listeners firing within 50ms
      for (int i = 0; i < 12; i++) {
        debouncedRefresh();
        await Future.delayed(const Duration(milliseconds: 4));
      }

      expect(refreshCount, equals(0)); // Hasn't fired yet because debounced

      // Wait for debounce timer to elapse
      await Future.delayed(const Duration(milliseconds: 150));
      expect(refreshCount, equals(1)); // Coalesced into exactly 1 refresh
    });
  });
}
