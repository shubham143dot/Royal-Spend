import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';

import 'expense_provider_test.dart';
import 'travel_multi_plan_isolation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & 6: Data Integrity & Safe Deserialization Audit', () {
    test('Expense.fromMap safely parses booleans, numbers, and timestamps across formats', () {
      // 1. Integer-based boolean (SQLite style)
      final sqliteMap = {
        'id': 'exp-1',
        'title': 'Coffee at Darjeeling',
        'amount': 120.0,
        'category_id': 'food',
        'date': 1735689600000,
        'payment_method': 'upi',
        'is_income': 0,
        'trip_id': 'trip-darjeeling',
      };
      final exp1 = Expense.fromMap(sqliteMap);
      expect(exp1.id, 'exp-1');
      expect(exp1.isIncome, false);
      expect(exp1.amount, 120.0);
      expect(exp1.tripId, 'trip-darjeeling');

      // 2. Boolean-based boolean (Firestore style) & string timestamp
      final firestoreMap = {
        'id': 'exp-2',
        'title': 'Salary Credit',
        'amount': 50000,
        'category_id': 'salary',
        'date': '2026-12-10T10:00:00.000Z',
        'payment_method': 'netBanking',
        'is_income': true,
        'trip_id': null,
      };
      final exp2 = Expense.fromMap(firestoreMap);
      expect(exp2.id, 'exp-2');
      expect(exp2.isIncome, true);
      expect(exp2.amount, 50000.0);
      expect(exp2.tripId, isNull);
    });

    test('Trip.fromMap safely parses dates and numerical types', () {
      final tripMap = {
        'id': 'trip-99',
        'title': 'Goa Beach Vacation',
        'destination': 'Goa, India',
        'departure_city': 'Mumbai',
        'start_date': '2026-11-15T00:00:00.000Z',
        'end_date': '2026-11-20T00:00:00.000Z',
        'budget': 35000,
        'transport_budget': 10000,
        'accommodation_budget': 15000,
        'food_budget': 10000,
        'travelers_count': 2,
        'status': 'upcoming',
        'preferences': '["Beach", "Nightlife"]',
      };
      final trip = Trip.fromMap(tripMap);
      expect(trip.id, 'trip-99');
      expect(trip.title, 'Goa Beach Vacation');
      expect(trip.budget, 35000.0);
      expect(trip.travelersCount, 2);
      expect(trip.preferences, contains('Beach'));
      expect(trip.startDate.year, 2026);
    });

    test('ItineraryActivity.fromMap safely parses destination confirmation, duration, and sortOrder', () {
      final actMap = {
        'id': 'act-1',
        'trip_id': 'trip-99',
        'day_id': 'day-1',
        'title': 'Visit Baga Beach',
        'place_name': 'Baga Beach',
        'address': 'North Goa',
        'start_time': '16:00',
        'end_time': '19:00',
        'duration_minutes': 180,
        'category': 'Sightseeing',
        'estimated_cost': 500,
        'booking_status': 'confirmed',
        'is_completed': 0,
        'is_destination_confirmed': 1,
        'sort_order': 3,
      };
      final activity = ItineraryActivity.fromMap(actMap);
      expect(activity.id, 'act-1');
      expect(activity.placeName, 'Baga Beach');
      expect(activity.durationMinutes, 180);
      expect(activity.estimatedCost, 500.0);
      expect(activity.isDestinationConfirmed, true);
      expect(activity.isCompleted, false);
      expect(activity.sortOrder, 3);
    });
  });

  group('Phase 3 & 4: Travel Planner Reordering & Calculations', () {
    late MockTravelRepository mockRepo;
    late TravelProvider travelProvider;

    setUp(() {
      mockRepo = MockTravelRepository();
      travelProvider = TravelProvider(repository: mockRepo);
    });

    test('reorderActivities updates sort order sequentially and notifies listeners', () async {
      final trip = Trip(
        id: 'trip-reorder',
        title: 'Manali Tour',
        destination: 'Manali, Himachal Pradesh',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
      );
      mockRepo.trips.add(trip);

      final day = ItineraryDay(
        id: 'day-reorder-1',
        tripId: 'trip-reorder',
        dayNumber: 1,
        date: DateTime(2026, 12, 1),
      );
      mockRepo.days.add(day);

      final act1 = ItineraryActivity(
        id: 'act-101',
        tripId: 'trip-reorder',
        dayId: 'day-reorder-1',
        title: 'Solang Valley',
        sortOrder: 0,
        estimatedCost: 1500,
      );
      final act2 = ItineraryActivity(
        id: 'act-102',
        tripId: 'trip-reorder',
        dayId: 'day-reorder-1',
        title: 'Hadimba Temple',
        sortOrder: 1,
        estimatedCost: 200,
      );
      final act3 = ItineraryActivity(
        id: 'act-103',
        tripId: 'trip-reorder',
        dayId: 'day-reorder-1',
        title: 'Old Manali Cafe Crawl',
        sortOrder: 2,
        estimatedCost: 800,
      );

      mockRepo.activities.addAll([act1, act2, act3]);
      await travelProvider.selectTrip('trip-reorder');

      // Verify initial order
      final initialActs = travelProvider.activitiesByDay['day-reorder-1'] ?? [];
      expect(initialActs.map((a) => a.id).toList(), ['act-101', 'act-102', 'act-103']);

      // Reorder: Move 'act-103' (index 2) to the top (index 0)
      await travelProvider.reorderActivities('day-reorder-1', 2, 0);

      // Verify updated order & sortOrder in provider
      final updatedActs = travelProvider.activitiesByDay['day-reorder-1'] ?? [];
      expect(updatedActs.first.id, 'act-103');
      expect(updatedActs.first.sortOrder, 0);
      expect(updatedActs[1].id, 'act-101');
      expect(updatedActs[1].sortOrder, 1);
      expect(updatedActs[2].id, 'act-102');
      expect(updatedActs[2].sortOrder, 2);

      // Verify daily estimated cost aggregates all 3 stops
      final dailyTotal = travelProvider.getDailyEstimatedCost('day-reorder-1');
      expect(dailyTotal, 1500 + 200 + 800); // 2500.0
    });

    test('generateDaysForTrip creates exact number of days matching date span', () async {
      final trip = Trip(
        id: 'trip-days-test',
        title: 'Kashmir Expedition',
        destination: 'Srinagar, Kashmir',
        startDate: DateTime(2026, 12, 10),
        endDate: DateTime(2026, 12, 14), // 5 days inclusive
      );
      mockRepo.trips.add(trip);
      await travelProvider.selectTrip('trip-days-test');
      await travelProvider.generateDaysForTrip(trip);

      final days = travelProvider.currentDays;
      expect(days.length, 5);
      expect(days.first.dayNumber, 1);
      expect(days.first.date, DateTime(2026, 12, 10));
      expect(days.last.dayNumber, 5);
      expect(days.last.date, DateTime(2026, 12, 14));
    });
  });

  group('Phase 5: Expense Tracker & Travel Planner Cross-Module Integration', () {
    test('Trip-linked expenses are isolated from unrelated trips and update trip budget rollups', () async {
      final mockTravelRepo = MockTravelRepository();
      final mockExpenseRepo = MockExpenseRepository();
      final travelProvider = TravelProvider(repository: mockTravelRepo);
      final expenseProvider = ExpenseProvider(repository: mockExpenseRepo);

      final tripA = Trip(
        id: 'trip-A',
        title: 'Ladakh Road Trip',
        destination: 'Leh, Ladakh',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 10),
        budget: 50000,
      );
      final tripB = Trip(
        id: 'trip-B',
        title: 'Jaipur Heritage Tour',
        destination: 'Jaipur, Rajasthan',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
        budget: 20000,
      );
      mockTravelRepo.trips.addAll([tripA, tripB]);
      await travelProvider.loadTrips();

      // Record 1 personal expense (no tripId)
      final expPersonal = Expense(
        id: 'exp-p1',
        title: 'Home Electricity Bill',
        amount: 2400,
        categoryId: 'bills',
        date: DateTime(2026, 7, 2),
        paymentMethod: PaymentMethod.bankTransfer,
      );
      await expenseProvider.addExpense(expPersonal);

      // Record 2 expenses for Trip A
      final expTripA1 = Expense(
        id: 'exp-ta1',
        title: 'Bike Rental Leh',
        amount: 8000,
        categoryId: 'transport',
        date: DateTime(2026, 7, 3),
        paymentMethod: PaymentMethod.cash,
        tripId: 'trip-A',
      );
      final expTripA2 = Expense(
        id: 'exp-ta2',
        title: 'Pangong Homestay',
        amount: 4500,
        categoryId: 'travel',
        date: DateTime(2026, 7, 4),
        paymentMethod: PaymentMethod.upi,
        tripId: 'trip-A',
      );
      await expenseProvider.addExpense(expTripA1);
      await expenseProvider.addExpense(expTripA2);

      // Record 1 expense for Trip B
      final expTripB1 = Expense(
        id: 'exp-tb1',
        title: 'Amer Fort Ticket & Guide',
        amount: 1500,
        categoryId: 'entertainment',
        date: DateTime(2026, 8, 2),
        paymentMethod: PaymentMethod.creditCard,
        tripId: 'trip-B',
      );
      await expenseProvider.addExpense(expTripB1);

      // Verify trip isolation
      final tripAExpenses = expenseProvider.allExpenses.where((e) => e.tripId == 'trip-A').toList();
      final tripBExpenses = expenseProvider.allExpenses.where((e) => e.tripId == 'trip-B').toList();
      final personalExpenses = expenseProvider.allExpenses.where((e) => e.tripId == null).toList();

      expect(tripAExpenses.length, 2);
      expect(tripBExpenses.length, 1);
      expect(personalExpenses.length, 1);

      // Total spent for Trip A: 8000 + 4500 = 12500
      final tripATotal = tripAExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(tripATotal, 12500.0);

      // Total spent for Trip B: 1500
      final tripBTotal = tripBExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(tripBTotal, 1500.0);

      // Total all expenses in provider: 2400 + 12500 + 1500 = 16400
      final totalAll = expenseProvider.allExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(totalAll, 16400.0);

      // Deleting a trip expense cleanly updates trip total and overall total
      await expenseProvider.deleteExpense('exp-ta2');
      final updatedTripA = expenseProvider.allExpenses.where((e) => e.tripId == 'trip-A').toList();
      expect(updatedTripA.length, 1);
      expect(updatedTripA.first.amount, 8000.0);

      final updatedTotalAll = expenseProvider.allExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(updatedTotalAll, 11900.0);
    });
  });
}
