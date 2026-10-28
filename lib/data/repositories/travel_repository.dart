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

  TravelRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Trip>> getAllTrips() => _dbHelper.getAllTrips();

  @override
  Future<Trip?> getTrip(String id) => _dbHelper.getTrip(id);

  @override
  Future<void> addTrip(Trip trip) async {
    await _dbHelper.insertTrip(trip);
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    await _dbHelper.updateTrip(trip);
  }

  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async {
    await _dbHelper.deleteTrip(id, deleteExpenses: deleteExpenses);
  }

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) =>
      _dbHelper.getDaysForTrip(tripId);

  @override
  Future<void> addDay(ItineraryDay day) async {
    await _dbHelper.insertItineraryDay(day);
  }

  @override
  Future<void> updateDay(ItineraryDay day) async {
    await _dbHelper.updateItineraryDay(day);
  }

  @override
  Future<void> deleteDay(String id) async {
    await _dbHelper.deleteItineraryDay(id);
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
  }

  @override
  Future<void> updateActivity(ItineraryActivity activity) async {
    await _dbHelper.updateActivity(activity);
  }

  @override
  Future<void> deleteActivity(String id) async {
    await _dbHelper.deleteActivity(id);
  }

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) =>
      _dbHelper.getSavedPlacesForTrip(tripId);

  @override
  Future<void> addSavedPlace(SavedPlace place) async {
    await _dbHelper.insertSavedPlace(place);
  }

  @override
  Future<void> updateSavedPlace(SavedPlace place) async {
    await _dbHelper.updateSavedPlace(place);
  }

  @override
  Future<void> deleteSavedPlace(String id) async {
    await _dbHelper.deleteSavedPlace(id);
  }

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) =>
      _dbHelper.getTransportsForTrip(tripId);

  @override
  Future<void> addTransport(TravelTransport transport) async {
    await _dbHelper.insertTransport(transport);
  }

  @override
  Future<void> updateTransport(TravelTransport transport) async {
    await _dbHelper.updateTransport(transport);
  }

  @override
  Future<void> deleteTransport(String id) async {
    await _dbHelper.deleteTransport(id);
  }

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId) =>
      _dbHelper.getAccommodationsForTrip(tripId);

  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {
    await _dbHelper.insertAccommodation(accommodation);
  }

  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {
    await _dbHelper.updateAccommodation(accommodation);
  }

  @override
  Future<void> deleteAccommodation(String id) async {
    await _dbHelper.deleteAccommodation(id);
  }

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) =>
      _dbHelper.getChecklistForTrip(tripId);

  @override
  Future<void> addChecklistItem(TravelChecklistItem item) async {
    await _dbHelper.insertChecklistItem(item);
  }

  @override
  Future<void> updateChecklistItem(TravelChecklistItem item) async {
    await _dbHelper.updateChecklistItem(item);
  }

  @override
  Future<void> deleteChecklistItem(String id) async {
    await _dbHelper.deleteChecklistItem(id);
  }

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) =>
      _dbHelper.getSplitsForTrip(tripId);

  @override
  Future<void> addSplit(TravelSplit split) async {
    await _dbHelper.insertSplit(split);
  }

  @override
  Future<void> deleteSplit(String id) async {
    await _dbHelper.deleteSplit(id);
  }

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) =>
      _dbHelper.getExpensesForTrip(tripId);
}
