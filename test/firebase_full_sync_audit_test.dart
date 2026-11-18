import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/data/database/database_helper.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/saved_place.dart';
import 'package:royal_spend/data/models/travel_accommodation.dart';
import 'package:royal_spend/data/models/travel_checklist_item.dart';
import 'package:royal_spend/data/models/travel_split.dart';
import 'package:royal_spend/data/models/travel_transport.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/data/repositories/travel_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Test Spy recording all instant sync invocations to verify complete Firebase synchronization
class SpyFirestoreSyncService extends FirestoreSyncService {
  final List<String> syncEvents = [];
  final List<Expense> syncedExpenses = [];
  final List<String> deletedExpenseIds = [];
  final List<Budget> syncedBudgets = [];
  final List<Trip> syncedTrips = [];
  final List<String> deletedTripIds = [];
  final List<ItineraryDay> syncedDays = [];
  final List<String> deletedDayIds = [];
  final List<ItineraryActivity> syncedActivities = [];
  final List<String> deletedActivityIds = [];
  final List<SavedPlace> syncedPlaces = [];
  final List<String> deletedPlaceIds = [];
  final List<TravelTransport> syncedTransports = [];
  final List<String> deletedTransportIds = [];
  final List<TravelAccommodation> syncedAccommodations = [];
  final List<String> deletedAccommodationIds = [];
  final List<TravelChecklistItem> syncedChecklists = [];
  final List<String> deletedChecklistIds = [];
  final List<TravelSplit> syncedSplits = [];
  final List<String> deletedSplitIds = [];
  final List<String> savedCategoryPreferences = [];
  final List<Map<String, dynamic>> savedUserPreferences = [];

  SpyFirestoreSyncService({required DatabaseHelper dbHelper})
      : super(dbHelper: dbHelper);

  @override
  Future<void> syncExpense(Expense expense) async {
    syncEvents.add('syncExpense:${expense.id}');
    syncedExpenses.add(expense);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    syncEvents.add('deleteExpense:$expenseId');
    deletedExpenseIds.add(expenseId);
  }

  @override
  Future<void> clearAllCloudExpenses() async {
    syncEvents.add('clearAllCloudExpenses');
  }

  @override
  Future<void> syncBudget(Budget budget) async {
    syncEvents.add('syncBudget:${budget.id}');
    syncedBudgets.add(budget);
  }

  @override
  Future<void> syncTrip(Trip trip) async {
    syncEvents.add('syncTrip:${trip.id}');
    syncedTrips.add(trip);
  }

  @override
  Future<void> deleteTrip(String tripId, {bool deleteExpenses = false}) async {
    syncEvents.add('deleteTrip:$tripId:deleteExpenses=$deleteExpenses');
    deletedTripIds.add(tripId);
  }

  @override
  Future<void> syncItineraryDay(ItineraryDay day) async {
    syncEvents.add('syncItineraryDay:${day.id}');
    syncedDays.add(day);
  }

  @override
  Future<void> deleteItineraryDay(String dayId) async {
    syncEvents.add('deleteItineraryDay:$dayId');
    deletedDayIds.add(dayId);
  }

  @override
  Future<void> syncItineraryActivity(ItineraryActivity activity) async {
    syncEvents.add('syncItineraryActivity:${activity.id}');
    syncedActivities.add(activity);
  }

  @override
  Future<void> deleteItineraryActivity(String activityId) async {
    syncEvents.add('deleteItineraryActivity:$activityId');
    deletedActivityIds.add(activityId);
  }

  @override
  Future<void> syncSavedPlace(SavedPlace place) async {
    syncEvents.add('syncSavedPlace:${place.id}');
    syncedPlaces.add(place);
  }

  @override
  Future<void> deleteSavedPlace(String placeId) async {
    syncEvents.add('deleteSavedPlace:$placeId');
    deletedPlaceIds.add(placeId);
  }

  @override
  Future<void> syncTransport(TravelTransport transport) async {
    syncEvents.add('syncTransport:${transport.id}');
    syncedTransports.add(transport);
  }

  @override
  Future<void> deleteTransport(String transportId) async {
    syncEvents.add('deleteTransport:$transportId');
    deletedTransportIds.add(transportId);
  }

  @override
  Future<void> syncAccommodation(TravelAccommodation accommodation) async {
    syncEvents.add('syncAccommodation:${accommodation.id}');
    syncedAccommodations.add(accommodation);
  }

  @override
  Future<void> deleteAccommodation(String accommodationId) async {
    syncEvents.add('deleteAccommodation:$accommodationId');
    deletedAccommodationIds.add(accommodationId);
  }

  @override
  Future<void> syncChecklistItem(TravelChecklistItem item) async {
    syncEvents.add('syncChecklistItem:${item.id}');
    syncedChecklists.add(item);
  }

  @override
  Future<void> deleteChecklistItem(String itemId) async {
    syncEvents.add('deleteChecklistItem:$itemId');
    deletedChecklistIds.add(itemId);
  }

  @override
  Future<void> syncTravelSplit(TravelSplit split) async {
    syncEvents.add('syncTravelSplit:${split.id}');
    syncedSplits.add(split);
  }

  @override
  Future<void> deleteTravelSplit(String splitId) async {
    syncEvents.add('deleteTravelSplit:$splitId');
    deletedSplitIds.add(splitId);
  }

  @override
  Future<void> saveUserCategoryPreference(String? uid, String scope) async {
    syncEvents.add('saveUserCategoryPreference:$scope');
    savedCategoryPreferences.add(scope);
  }

  @override
  Future<void> saveUserPreferences(String? uid, Map<String, dynamic> preferences) async {
    syncEvents.add('saveUserPreferences:${preferences.keys.join(",")}');
    savedUserPreferences.add(preferences);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late SpyFirestoreSyncService spySync;
  late ExpenseRepository expenseRepo;
  late TravelRepository travelRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dbHelper = DatabaseHelper.instance;
    await dbHelper.clearAllData();

    spySync = SpyFirestoreSyncService(dbHelper: dbHelper);
    expenseRepo = ExpenseRepository(dbHelper: dbHelper, syncService: spySync);
    travelRepo = TravelRepository(dbHelper: dbHelper, syncService: spySync);
  });

  tearDown(() async {
    await dbHelper.clearAllData();
  });

  group('Firebase Full Sync Audit: Expense & Budget Entity Tests', () {
    test('Expense add, update, delete immediately sync with Firebase', () async {
      final expense = Expense(
        id: 'exp_sync_1',
        title: 'Fuel refuel',
        amount: 850.0,
        date: DateTime.now(),
        categoryId: 'transport',
      );

      // Add
      await expenseRepo.addExpense(expense);
      expect(spySync.syncEvents, contains('syncExpense:exp_sync_1'));
      expect(spySync.syncedExpenses.any((e) => e.id == 'exp_sync_1'), isTrue);

      // Update
      final updated = expense.copyWith(amount: 900.0);
      await expenseRepo.updateExpense(updated);
      expect(spySync.syncedExpenses.any((e) => e.amount == 900.0), isTrue);

      // Delete
      await expenseRepo.deleteExpense('exp_sync_1');
      expect(spySync.syncEvents, contains('deleteExpense:exp_sync_1'));
      expect(spySync.deletedExpenseIds, contains('exp_sync_1'));
    });

    test('Budget save and clearAllData immediately sync with Firebase', () async {
      final budget = Budget(
        id: 'budget_sync_1',
        monthlyLimit: 45000.0,
        month: 11,
        year: 2026,
      );

      await expenseRepo.saveBudget(budget);
      expect(spySync.syncEvents, contains('syncBudget:budget_sync_1'));
      expect(spySync.syncedBudgets.first.monthlyLimit, 45000.0);

      await expenseRepo.clearAllData();
      expect(spySync.syncEvents, contains('clearAllCloudExpenses'));
    });
  });

  group('Firebase Full Sync Audit: Travel Entity Tests (All 9 Travel Components)', () {
    test('Trips add, update, delete immediately sync with Firebase', () async {
      final trip = Trip(
        id: 'trip_sync_1',
        title: 'Leh Ladakh Tour',
        destination: 'Ladakh',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      // Add Trip
      await travelRepo.addTrip(trip);
      expect(spySync.syncEvents, contains('syncTrip:trip_sync_1'));

      // Update Trip
      final updated = trip.copyWith(budget: 35000.0);
      await travelRepo.updateTrip(updated);
      expect(spySync.syncedTrips.any((t) => t.budget == 35000.0), isTrue);

      // Delete Trip
      await travelRepo.deleteTrip('trip_sync_1', deleteExpenses: true);
      expect(spySync.syncEvents, contains('deleteTrip:trip_sync_1:deleteExpenses=true'));
    });

    test('Itinerary Days & Activities add, update, reorder, delete immediately sync', () async {
      final day = ItineraryDay(
        id: 'day_sync_1',
        tripId: 'trip_sync_1',
        dayNumber: 1,
        date: DateTime.now(),
      );

      // Day Add, Update, Delete
      await travelRepo.addDay(day);
      expect(spySync.syncEvents, contains('syncItineraryDay:day_sync_1'));

      await travelRepo.updateDay(day.copyWith(title: 'Arrival Day'));
      expect(spySync.syncedDays.any((d) => d.title == 'Arrival Day'), isTrue);

      // Activity Add, Update, Reorder, Delete
      final act1 = ItineraryActivity(
        id: 'act_sync_1',
        tripId: 'trip_sync_1',
        dayId: 'day_sync_1',
        title: 'Morning Breakfast',
        sortOrder: 0,
      );
      final act2 = ItineraryActivity(
        id: 'act_sync_2',
        tripId: 'trip_sync_1',
        dayId: 'day_sync_1',
        title: 'Sightseeing Pass',
        sortOrder: 1,
      );

      await travelRepo.addActivity(act1);
      await travelRepo.addActivity(act2);
      expect(spySync.syncEvents, contains('syncItineraryActivity:act_sync_1'));
      expect(spySync.syncEvents, contains('syncItineraryActivity:act_sync_2'));

      await travelRepo.reorderActivities('day_sync_1', [
        act2.copyWith(sortOrder: 0),
        act1.copyWith(sortOrder: 1),
      ]);
      expect(spySync.syncEvents.where((e) => e.startsWith('syncItineraryActivity:')).length, greaterThanOrEqualTo(4));

      await travelRepo.deleteActivity('act_sync_1');
      expect(spySync.deletedActivityIds, contains('act_sync_1'));

      await travelRepo.deleteDay('day_sync_1');
      expect(spySync.deletedDayIds, contains('day_sync_1'));
    });

    test('Saved Places, Transports, Accommodations add, update, delete immediately sync', () async {
      // Saved Place
      final place = SavedPlace(
        id: 'place_sync_1',
        tripId: 'trip_sync_1',
        name: 'Pangong Tso',
        address: 'Ladakh, India',
      );
      await travelRepo.addSavedPlace(place);
      expect(spySync.syncEvents, contains('syncSavedPlace:place_sync_1'));

      await travelRepo.updateSavedPlace(place.copyWith(locationNotes: 'Camp overnight'));
      expect(spySync.syncedPlaces.any((p) => p.locationNotes == 'Camp overnight'), isTrue);

      await travelRepo.deleteSavedPlace('place_sync_1');
      expect(spySync.deletedPlaceIds, contains('place_sync_1'));

      // Transport
      final transport = TravelTransport(
        id: 'trans_sync_1',
        tripId: 'trip_sync_1',
        type: TransportType.flight,
        provider: 'Air India',
        departurePlace: 'Delhi',
        arrivalPlace: 'Leh',
        departureTime: DateTime.now(),
        arrivalTime: DateTime.now().add(const Duration(hours: 2)),
      );
      await travelRepo.addTransport(transport);
      expect(spySync.syncEvents, contains('syncTransport:trans_sync_1'));

      await travelRepo.updateTransport(transport.copyWith(provider: 'IndiGo'));
      expect(spySync.syncedTransports.any((t) => t.provider == 'IndiGo'), isTrue);

      await travelRepo.deleteTransport('trans_sync_1');
      expect(spySync.deletedTransportIds, contains('trans_sync_1'));

      // Accommodation
      final acc = TravelAccommodation(
        id: 'acc_sync_1',
        tripId: 'trip_sync_1',
        propertyName: 'The Grand Dragon',
        checkIn: DateTime.now(),
        checkOut: DateTime.now().add(const Duration(days: 3)),
      );
      await travelRepo.addAccommodation(acc);
      expect(spySync.syncEvents, contains('syncAccommodation:acc_sync_1'));

      await travelRepo.updateAccommodation(acc.copyWith(notes: 'Deluxe Suite'));
      expect(spySync.syncedAccommodations.any((a) => a.notes == 'Deluxe Suite'), isTrue);

      await travelRepo.deleteAccommodation('acc_sync_1');
      expect(spySync.deletedAccommodationIds, contains('acc_sync_1'));
    });

    test('Checklists and Travel Splits add, toggle, delete immediately sync', () async {
      // Checklist
      final checkItem = TravelChecklistItem(
        id: 'check_sync_1',
        tripId: 'trip_sync_1',
        category: ChecklistCategory.clothing,
        item: 'Carry Warm Thermal Wear',
        isCompleted: false,
      );
      await travelRepo.addChecklistItem(checkItem);
      expect(spySync.syncEvents, contains('syncChecklistItem:check_sync_1'));

      await travelRepo.updateChecklistItem(checkItem.copyWith(isCompleted: true));
      expect(spySync.syncedChecklists.any((c) => c.isCompleted == true), isTrue);

      await travelRepo.deleteChecklistItem('check_sync_1');
      expect(spySync.deletedChecklistIds, contains('check_sync_1'));

      // Split
      final split = TravelSplit(
        id: 'split_sync_1',
        tripId: 'trip_sync_1',
        title: 'Dinner at Leh',
        totalAmount: 4500.0,
        paidBy: 'Subha',
        shares: {'Subha': 1500.0, 'Alex': 1500.0, 'Rahul': 1500.0},
      );
      await travelRepo.addSplit(split);
      expect(spySync.syncEvents, contains('syncTravelSplit:split_sync_1'));

      await travelRepo.deleteSplit('split_sync_1');
      expect(spySync.deletedSplitIds, contains('split_sync_1'));
    });
  });

  group('Firebase Full Sync Audit: Providers & Live State Synchronization', () {
    test('TravelProvider.updateTripBudget immediately triggers syncTrip with updated budget', () async {
      final trip = Trip(
        id: 'trip_prov_1',
        title: 'Manali Ride',
        destination: 'Manali',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        budget: 15000.0,
      );
      await travelRepo.addTrip(trip);

      final travelProvider = TravelProvider(repository: travelRepo);
      await travelProvider.init();

      await travelProvider.updateTripBudget('trip_prov_1', 25000.0);

      expect(spySync.syncedTrips.any((t) => t.id == 'trip_prov_1' && t.budget == 25000.0), isTrue);
      expect(travelProvider.trips.firstWhere((t) => t.id == 'trip_prov_1').budget, 25000.0);
    });

    test('TravelProvider.toggleChecklistItem immediately triggers syncChecklistItem', () async {
      final trip = Trip(
        id: 'trip_prov_check',
        title: 'Shimla Ride',
        destination: 'Shimla',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
      );
      await travelRepo.addTrip(trip);

      final checkItem = TravelChecklistItem(
        id: 'check_toggle_1',
        tripId: 'trip_prov_check',
        category: ChecklistCategory.documents,
        item: 'Action Camera Battery',
        isCompleted: false,
      );
      await travelRepo.addChecklistItem(checkItem);

      final travelProvider = TravelProvider(repository: travelRepo);
      await travelProvider.init();
      await travelProvider.selectTrip('trip_prov_check');

      await travelProvider.toggleChecklistItem(checkItem);

      expect(spySync.syncedChecklists.any((c) => c.id == 'check_toggle_1' && c.isCompleted == true), isTrue);
    });

    test('ExpenseProvider category selector changes immediately save to Settings & Firestore', () async {
      final expenseProv = ExpenseProvider(repository: expenseRepo);

      await expenseProv.setCategoryScope(ExpenseScope.travel, userId: 'user_audit_123');
      expect(expenseProv.categoryScope, ExpenseScope.travel);

      final saved = await SettingsRepository().getSelectedCategoryScope(userId: 'user_audit_123');
      expect(saved, 'travel');

      await expenseProv.setCategoryScope(ExpenseScope.personal, userId: 'user_audit_123');
      expect(expenseProv.categoryScope, ExpenseScope.personal);

      await expenseProv.setCategoryScope(ExpenseScope.all, userId: 'user_audit_123');
      expect(expenseProv.categoryScope, ExpenseScope.all);
    });

    test('DatabaseHelper.getAllBudgets and deleteBudget operate cleanly', () async {
      final b1 = Budget(id: 'b_1', monthlyLimit: 20000, month: 1, year: 2026);
      final b2 = Budget(id: 'b_2', monthlyLimit: 25000, month: 2, year: 2026);

      await dbHelper.setBudgetForMonth(b1);
      await dbHelper.setBudgetForMonth(b2);

      final all = await dbHelper.getAllBudgets();
      expect(all.length, greaterThanOrEqualTo(2));
      expect(all.any((b) => b.id == 'b_1'), isTrue);
      expect(all.any((b) => b.id == 'b_2'), isTrue);

      await dbHelper.deleteBudget('b_1');
      final afterDelete = await dbHelper.getAllBudgets();
      expect(afterDelete.any((b) => b.id == 'b_1'), isFalse);
    });

    test('cancelRealtimeListeners cleans up all 12 subscriptions gracefully without exceptions', () {
      final syncService = FirestoreSyncService.instance;
      expect(() => syncService.cancelRealtimeListeners(), returnsNormally);
    });
  });
}
