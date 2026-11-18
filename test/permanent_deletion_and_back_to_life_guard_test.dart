import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/data/database/database_helper.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/travel_repository.dart';
import 'package:royal_spend/providers/travel_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Back to Life Plan & AppConstants Guard Tests', () {
    test('AppConstants.isBackToLifeTrip accurately detects variants of back to life', () {
      expect(AppConstants.isBackToLifeTrip('Back to life'), isTrue);
      expect(AppConstants.isBackToLifeTrip('back to life'), isTrue);
      expect(AppConstants.isBackToLifeTrip('Back To Life Plan'), isTrue);
      expect(AppConstants.isBackToLifeTrip('My Trip', 'Back to life resort'), isTrue);
      expect(AppConstants.isBackToLifeTrip('  BACK TO LIFE  '), isTrue);

      expect(AppConstants.isBackToLifeTrip('Darjeeling Trip'), isFalse);
      expect(AppConstants.isBackToLifeTrip('Goa Beach Vacation'), isFalse);
      expect(AppConstants.isBackToLifeTrip(null), isFalse);
    });

    test('TravelProvider strictly isolates Back to Life plan to admin account', () async {
      final db = DatabaseHelper.instance;
      await db.clearAllData();

      final now = DateTime.now();
      final adminTrip = Trip(
        id: 'back_to_life_trip_1',
        title: 'Back to life Plan',
        destination: 'Nature Retreat',
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
      );

      final normalTrip = Trip(
        id: 'darjeeling_trip_1',
        title: 'Darjeeling Explorer',
        destination: 'Darjeeling, WB',
        startDate: now,
        endDate: now.add(const Duration(days: 4)),
      );

      final repo = TravelRepository(dbHelper: db);
      await repo.addTrip(adminTrip);
      await repo.addTrip(normalTrip);

      final travelProvider = TravelProvider(repository: repo);

      // Non-admin user test
      travelProvider.setAdminStatus(false);
      await travelProvider.loadTrips();

      // "Back to life" must NOT exist in trips or filteredTrips for non-admin
      expect(travelProvider.trips.any((t) => t.id == 'back_to_life_trip_1'), isFalse);
      expect(travelProvider.filteredTrips.any((t) => t.id == 'back_to_life_trip_1'), isFalse);
      expect(travelProvider.trips.any((t) => t.id == 'darjeeling_trip_1'), isTrue);

      // Admin user test
      await repo.addTrip(adminTrip);
      travelProvider.setAdminStatus(true);
      await travelProvider.loadTrips();

      // "Back to life" MUST be visible for admin
      expect(travelProvider.trips.any((t) => t.id == 'back_to_life_trip_1'), isTrue);
      expect(travelProvider.filteredTrips.any((t) => t.id == 'back_to_life_trip_1'), isTrue);
      expect(travelProvider.trips.any((t) => t.id == 'darjeeling_trip_1'), isTrue);
    });
  });

  group('Permanent Deletion & Tombstone Tests', () {
    test('Deleted expense is recorded in tombstones and cannot be re-inserted', () async {
      final db = DatabaseHelper.instance;
      await db.clearAllData();

      final expense = Expense(
        id: 'test_exp_del_1',
        title: 'Lunch',
        amount: 250.0,
        categoryId: 'food',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insertExpense(expense);
      var all = await db.getAllExpenses();
      expect(all.length, 1);

      // Delete expense
      await db.deleteExpense(expense.id);
      all = await db.getAllExpenses();
      expect(all.isEmpty, isTrue);

      // Verify tombstone
      final isDeleted = await db.isRecordDeleted(expense.id);
      expect(isDeleted, isTrue);

      // Attempting to re-insert the deleted expense (e.g. from cloud pull) must be rejected
      final insertedRows = await db.insertExpense(expense);
      expect(insertedRows, 0);

      all = await db.getAllExpenses();
      expect(all.isEmpty, isTrue);
    });

    test('Deleting a trip marks the trip and all child entities as deleted tombstones', () async {
      final db = DatabaseHelper.instance;
      await db.clearAllData();

      final now = DateTime.now();
      final trip = Trip(
        id: 'trip_to_delete_99',
        title: 'Weekend Escape',
        destination: 'Puri',
        startDate: now,
        endDate: now.add(const Duration(days: 2)),
      );

      final day = ItineraryDay(
        id: 'day_to_delete_99',
        tripId: trip.id,
        dayNumber: 1,
        date: now,
      );

      await db.insertTrip(trip);
      await db.insertItineraryDay(day);

      // Delete trip
      await db.deleteTrip(trip.id);

      // Verify both trip and child day are in tombstones
      expect(await db.isRecordDeleted(trip.id), isTrue);
      expect(await db.isRecordDeleted(day.id), isTrue);

      // Neither can be re-inserted from cloud sync
      expect(await db.insertTrip(trip), 0);
      expect(await db.insertItineraryDay(day), 0);

      final trips = await db.getAllTrips();
      final days = await db.getDaysForTrip(trip.id);
      expect(trips.isEmpty, isTrue);
      expect(days.isEmpty, isTrue);
    });

    test('clearAllData wipes all tables and tombstones cleanly', () async {
      final db = DatabaseHelper.instance;
      await db.clearAllData();

      final deletedIds = await db.getAllDeletedRecordIds();
      expect(deletedIds.isEmpty, isTrue);

      final trips = await db.getAllTrips();
      expect(trips.isEmpty, isTrue);

      final expenses = await db.getAllExpenses();
      expect(expenses.isEmpty, isTrue);
    });
  });
}
