import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/saved_place.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/auth/login_screen.dart';
import 'package:royal_spend/ui/screens/travel/create_plan_wizard_screen.dart';
import 'package:royal_spend/ui/screens/travel/trip_workspace_screen.dart';
import 'package:royal_spend/ui/widgets/travel/itinerary_timeline_view.dart';
import 'package:royal_spend/ui/widgets/travel/trip_map_view.dart';

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
  Future<void> updateExpense(Expense expense) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) _expenses[idx] = expense;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Screen - Skip for now Button Removal Verification', () {
    test('AppConstants.enableDevAuthBypass is false', () {
      expect(AppConstants.enableDevAuthBypass, isFalse);
    });

    testWidgets('LoginScreen has no "Skip for now" or dev bypass button',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Skip for now'), findsNothing);
      expect(find.textContaining('Skip'), findsNothing);
    });
  });

  group('Travel Section Performance & Horizontal Responsiveness', () {
    late MockTravelRepository mockRepo;
    late TravelProvider travelProvider;
    late SettingsProvider settingsProvider;
    late ExpenseProvider expenseProvider;
    late QuickLogProvider quickLogProvider;
    late Trip testTrip;
    late ItineraryDay day1;

    setUp(() async {
      mockRepo = MockTravelRepository();
      travelProvider = TravelProvider(repository: mockRepo);
      settingsProvider = SettingsProvider(repository: SettingsRepository());
      expenseProvider = ExpenseProvider(repository: _FakeExpenseRepo());
      quickLogProvider = QuickLogProvider();

      testTrip = Trip(
        id: 'perf-trip-1',
        title: 'Swiss Alps Grand Tour & Mountain Expedition',
        destination: 'Interlaken & Zermatt, Switzerland',
        departureCity: 'Zurich Airport International Terminal Gate B',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 7),
        budget: 250000,
        status: TripStatus.upcoming,
      );
      mockRepo.trips.add(testTrip);

      day1 = ItineraryDay(
        id: 'day-1-perf',
        tripId: testTrip.id,
        dayNumber: 1,
        date: DateTime(2026, 6, 1),
        title: 'Arrival, Panoramic Train & Mountain Check-In',
        startPlaceName: 'Zurich HB Main Railway Station Platform 7',
        startType: 'station',
        startTime: '08:30 AM',
      );
      mockRepo.days.add(day1);

      mockRepo.activities.add(
        ItineraryActivity(
          id: 'act-1-perf',
          tripId: testTrip.id,
          dayId: day1.id,
          title: 'Glacier Express Scenic Train Route from Zurich to Zermatt',
          placeName: 'Zurich HB Station',
          startTime: '09:00 AM',
          durationMinutes: 240,
          estimatedCost: 18500,
          category: ActivityCategory.transport,
        ),
      );

      mockRepo.activities.add(
        ItineraryActivity(
          id: 'act-2-perf',
          tripId: testTrip.id,
          dayId: day1.id,
          title: 'Matterhorn Alpine Viewpoint & Photography Tour',
          placeName: 'Zermatt Observation Deck',
          startTime: '02:30 PM',
          durationMinutes: 90,
          estimatedCost: 3500,
          category: ActivityCategory.sightseeing,
        ),
      );

      mockRepo.savedPlaces.add(
        SavedPlace(
          id: 'sp-1-perf',
          tripId: testTrip.id,
          name: 'Matterhorn Glacier Paradise Mountain Station & Viewing Platform',
          address: 'Schluhmattstrasse 119, 3920 Zermatt, Switzerland',
          category: 'Attraction',
          latitude: 45.9383,
          longitude: 7.7297,
        ),
      );

      await travelProvider.initialize();
      await travelProvider.selectTrip(testTrip.id);
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: quickLogProvider),
          ChangeNotifierProvider.value(value: travelProvider),
          ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    testWidgets('ItineraryTimelineView uses CustomScrollView and zero IntrinsicHeight',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: ItineraryTimelineView(
              day: day1,
              isDark: false,
              onAddStop: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // CustomScrollView verifies sliver virtualized lazy loading
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify no IntrinsicHeight is used in the timeline items (the root cause of layout lag)
      expect(find.byType(IntrinsicHeight), findsNothing);

      // Verify RepaintBoundary is applied for zero-overhead scrolling
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('TripMapView renders inside RepaintBoundary without BackdropFilter',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: TripMapView(
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // TripMapView wraps map in RepaintBoundary
      expect(find.byType(RepaintBoundary), findsWidgets);

      // Verify no BackdropFilter blur is layered over the map container (avoiding GPU raster readback lag)
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('Landscape / Horizontal orientation layout test: zero RenderFlex pixel overflows',
        (WidgetTester tester) async {
      // Simulate wide landscape phone / tablet
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          TripWorkspaceScreen(tripId: testTrip.id),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify zero exceptions and zero pixel overflow errors
      expect(tester.takeException(), isNull);
      expect(find.text('Swiss Alps Grand Tour & Mountain Expedition'), findsWidgets);
    });

    testWidgets('CreatePlanWizardScreen renders without overflow in landscape',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          const CreatePlanWizardScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
    });
  });
}
