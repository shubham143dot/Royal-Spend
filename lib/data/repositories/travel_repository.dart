import 'dart:async';
import '../../core/services/firestore/firestore_sync_service.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/itinerary_activity.dart';
import '../models/itinerary_day.dart';
import '../models/saved_place.dart';
import '../models/travel_accommodation.dart';
import '../models/travel_checklist_item.dart';
import '../models/travel_split.dart';
import '../models/travel_transport.dart';
import '../models/trip.dart';

abstract class ITravelRepository {
  // Trips
  Future<List<Trip>> getAllTrips();
  Future<Trip?> getTrip(String id);
  Future<void> addTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String id, {bool deleteExpenses = false});

  // Days
  Future<List<ItineraryDay>> getDaysForTrip(String tripId);
  Future<void> addDay(ItineraryDay day);
  Future<void> updateDay(ItineraryDay day);
  Future<void> deleteDay(String id);

  // Activities
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId);
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId);
  Future<void> addActivity(ItineraryActivity activity);
  Future<void> updateActivity(ItineraryActivity activity);
  Future<void> deleteActivity(String id);
  Future<void> reorderActivities(String dayId, List<ItineraryActivity> reorderedActivities);

  // Saved Places
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId);
  Future<void> addSavedPlace(SavedPlace place);
  Future<void> updateSavedPlace(SavedPlace place);
  Future<void> deleteSavedPlace(String id);

  // Transports
  Future<List<TravelTransport>> getTransportsForTrip(String tripId);
  Future<void> addTransport(TravelTransport transport);
  Future<void> updateTransport(TravelTransport transport);
  Future<void> deleteTransport(String id);

  // Accommodations
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId);
  Future<void> addAccommodation(TravelAccommodation accommodation);
  Future<void> updateAccommodation(TravelAccommodation accommodation);
  Future<void> deleteAccommodation(String id);

  // Checklists
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId);
  Future<void> addChecklistItem(TravelChecklistItem item);
  Future<void> updateChecklistItem(TravelChecklistItem item);
  Future<void> deleteChecklistItem(String id);

  // Splits
  Future<List<TravelSplit>> getSplitsForTrip(String tripId);
  Future<void> addSplit(TravelSplit split);
  Future<void> deleteSplit(String id);

  // Linked Expenses
  Future<List<Expense>> getExpensesForTrip(String tripId);
}

class TravelRepository implements ITravelRepository {
  final DatabaseHelper _dbHelper;
  final FirestoreSyncService _syncService;

  TravelRepository({
    DatabaseHelper? dbHelper,
    FirestoreSyncService? syncService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _syncService = syncService ?? FirestoreSyncService.instance;

  @override
  Future<List<Trip>> getAllTrips() => _dbHelper.getAllTrips();

  @override
  Future<Trip?> getTrip(String id) => _dbHelper.getTrip(id);

  @override
  Future<void> addTrip(Trip trip) async {
    await _dbHelper.insertTrip(trip);
    unawaited(_syncService.syncTrip(trip).catchError((_) {}));
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    await _dbHelper.updateTrip(trip);
    unawaited(_syncService.syncTrip(trip).catchError((_) {}));
  }

  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async {
    await _dbHelper.deleteTrip(id, deleteExpenses: deleteExpenses);
    unawaited(_syncService.deleteTrip(id).catchError((_) {}));
  }

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) =>
      _dbHelper.getDaysForTrip(tripId);

  @override
  Future<void> addDay(ItineraryDay day) async {
    await _dbHelper.insertItineraryDay(day);
    unawaited(_syncService.syncItineraryDay(day).catchError((_) {}));
  }

  @override
  Future<void> updateDay(ItineraryDay day) async {
    await _dbHelper.updateItineraryDay(day);
    unawaited(_syncService.syncItineraryDay(day).catchError((_) {}));
  }

  @override
  Future<void> deleteDay(String id) async {
    await _dbHelper.deleteItineraryDay(id);
    unawaited(_syncService.deleteItineraryDay(id).catchError((_) {}));
  }

  @override
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) =>
      _dbHelper.getActivitiesForDay(dayId);

  @override
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) =>
      _dbHelper.getActivitiesForTrip(tripId);

  @override
  Future<void> addActivity(ItineraryActivity activity) async {
    await _dbHelper.insertActivity(activity);
    unawaited(_syncService.syncItineraryActivity(activity).catchError((_) {}));
  }

  @override
  Future<void> updateActivity(ItineraryActivity activity) async {
    await _dbHelper.updateActivity(activity);
    unawaited(_syncService.syncItineraryActivity(activity).catchError((_) {}));
  }

  @override
  Future<void> deleteActivity(String id) async {
    await _dbHelper.deleteActivity(id);
    unawaited(_syncService.deleteItineraryActivity(id).catchError((_) {}));
  }

  @override
  Future<void> reorderActivities(String dayId, List<ItineraryActivity> reorderedActivities) async {
    await _dbHelper.updateActivitiesSortOrder(reorderedActivities);
    for (final act in reorderedActivities) {
      unawaited(_syncService.syncItineraryActivity(act).catchError((_) {}));
    }
  }

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) =>
      _dbHelper.getSavedPlacesForTrip(tripId);

  @override
  Future<void> addSavedPlace(SavedPlace place) async {
    await _dbHelper.insertSavedPlace(place);
    unawaited(_syncService.syncSavedPlace(place).catchError((_) {}));
  }

  @override
  Future<void> updateSavedPlace(SavedPlace place) async {
    await _dbHelper.updateSavedPlace(place);
    unawaited(_syncService.syncSavedPlace(place).catchError((_) {}));
  }

  @override
  Future<void> deleteSavedPlace(String id) async {
    await _dbHelper.deleteSavedPlace(id);
    unawaited(_syncService.deleteSavedPlace(id).catchError((_) {}));
  }

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) =>
      _dbHelper.getTransportsForTrip(tripId);

  @override
  Future<void> addTransport(TravelTransport transport) async {
    await _dbHelper.insertTransport(transport);
    unawaited(_syncService.syncTransport(transport).catchError((_) {}));
  }

  @override
  Future<void> updateTransport(TravelTransport transport) async {
    await _dbHelper.updateTransport(transport);
    unawaited(_syncService.syncTransport(transport).catchError((_) {}));
  }

  @override
  Future<void> deleteTransport(String id) async {
    await _dbHelper.deleteTransport(id);
    unawaited(_syncService.deleteTransport(id).catchError((_) {}));
  }

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId) =>
      _dbHelper.getAccommodationsForTrip(tripId);

  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {
    await _dbHelper.insertAccommodation(accommodation);
    unawaited(_syncService.syncAccommodation(accommodation).catchError((_) {}));
  }

  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {
    await _dbHelper.updateAccommodation(accommodation);
    unawaited(_syncService.syncAccommodation(accommodation).catchError((_) {}));
  }

  @override
  Future<void> deleteAccommodation(String id) async {
    await _dbHelper.deleteAccommodation(id);
    unawaited(_syncService.deleteAccommodation(id).catchError((_) {}));
  }

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) =>
      _dbHelper.getChecklistForTrip(tripId);

  @override
  Future<void> addChecklistItem(TravelChecklistItem item) async {
    await _dbHelper.insertChecklistItem(item);
    unawaited(_syncService.syncChecklistItem(item).catchError((_) {}));
  }

  @override
  Future<void> updateChecklistItem(TravelChecklistItem item) async {
    await _dbHelper.updateChecklistItem(item);
    unawaited(_syncService.syncChecklistItem(item).catchError((_) {}));
  }

  @override
  Future<void> deleteChecklistItem(String id) async {
    await _dbHelper.deleteChecklistItem(id);
    unawaited(_syncService.deleteChecklistItem(id).catchError((_) {}));
  }

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) =>
      _dbHelper.getSplitsForTrip(tripId);

  @override
  Future<void> addSplit(TravelSplit split) async {
    await _dbHelper.insertSplit(split);
    unawaited(_syncService.syncTravelSplit(split).catchError((_) {}));
  }

  @override
  Future<void> deleteSplit(String id) async {
    await _dbHelper.deleteSplit(id);
    unawaited(_syncService.deleteTravelSplit(id).catchError((_) {}));
  }

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) =>
      _dbHelper.getExpensesForTrip(tripId);
}
