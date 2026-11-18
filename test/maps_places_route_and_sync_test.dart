import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/services/maps/google_routes_service.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/itinerary_day.dart';
import 'package:royal_spend/data/models/saved_place.dart';
import 'package:royal_spend/data/models/travel_accommodation.dart';
import 'package:royal_spend/data/models/travel_checklist_item.dart';
import 'package:royal_spend/data/models/travel_split.dart';
import 'package:royal_spend/data/models/travel_transport.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/travel_repository.dart';
import 'package:royal_spend/providers/travel_provider.dart';

class TestMockTravelRepository implements ITravelRepository {
  final List<Trip> trips = [];
  final List<ItineraryDay> days = [];
  final List<ItineraryActivity> activities = [];
  final List<SavedPlace> places = [];

  @override
  Future<List<Trip>> getAllTrips() async => trips;

  @override
  Future<Trip?> getTrip(String id) async =>
      trips.where((t) => t.id == id).firstOrNull;

  @override
  Future<void> addTrip(Trip trip) async => trips.add(trip);

  @override
  Future<void> updateTrip(Trip trip) async {
    final idx = trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) trips[idx] = trip;
  }

  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async =>
      trips.removeWhere((t) => t.id == id);

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) async =>
      days.where((d) => d.tripId == tripId).toList();

  @override
  Future<void> addDay(ItineraryDay day) async => days.add(day);

  @override
  Future<void> updateDay(ItineraryDay day) async {
    final idx = days.indexWhere((d) => d.id == day.id);
    if (idx != -1) days[idx] = day;
  }

  @override
  Future<void> deleteDay(String id) async => days.removeWhere((d) => d.id == id);

  @override
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) async =>
      activities.where((a) => a.dayId == dayId).toList();

  @override
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) async =>
      activities.where((a) => a.tripId == tripId).toList();

  @override
  Future<void> addActivity(ItineraryActivity activity) async =>
      activities.add(activity);

  @override
  Future<void> updateActivity(ItineraryActivity activity) async {
    final idx = activities.indexWhere((a) => a.id == activity.id);
    if (idx != -1) activities[idx] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async =>
      activities.removeWhere((a) => a.id == id);

  @override
  Future<void> reorderActivities(
      String dayId, List<ItineraryActivity> reorderedActivities) async {
    for (final act in reorderedActivities) {
      await updateActivity(act);
    }
  }

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) async =>
      places.where((p) => p.tripId == tripId).toList();

  @override
  Future<void> addSavedPlace(SavedPlace place) async => places.add(place);

  @override
  Future<void> updateSavedPlace(SavedPlace place) async {
    final idx = places.indexWhere((p) => p.id == place.id);
    if (idx != -1) places[idx] = place;
  }

  @override
  Future<void> deleteSavedPlace(String id) async =>
      places.removeWhere((p) => p.id == id);

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) async => [];
  @override
  Future<void> addTransport(TravelTransport transport) async {}
  @override
  Future<void> updateTransport(TravelTransport transport) async {}
  @override
  Future<void> deleteTransport(String id) async {}

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(
          String tripId) async =>
      [];
  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> deleteAccommodation(String id) async {}

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async =>
      [];
  @override
  Future<void> addChecklistItem(TravelChecklistItem item) async {}
  @override
  Future<void> updateChecklistItem(TravelChecklistItem item) async {}
  @override
  Future<void> deleteChecklistItem(String id) async {}

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) async => [];
  @override
  Future<void> addSplit(TravelSplit split) async {}
  Future<void> updateSplit(TravelSplit split) async {}
  @override
  Future<void> deleteSplit(String id) async {}

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) async => [];
  Future<void> linkExpenseToTrip(String expenseId, String tripId) async {}
  Future<void> unlinkExpenseFromTrip(String expenseId) async {}
}

void main() {
  group('Maps & Places: Route Management & Itinerary Synchronization Tests', () {
    late TestMockTravelRepository mockRepo;
    late TravelProvider provider;
    late Trip testTrip;

    setUp(() async {
      mockRepo = TestMockTravelRepository();
      provider = TravelProvider(repository: mockRepo);

      testTrip = Trip(
        id: 'darjeeling_trip_master',
        title: 'Darjeeling Master Expedition',
        destination: 'Darjeeling, West Bengal',
        startDate: DateTime(2026, 12, 10),
        endDate: DateTime(2026, 12, 15),
      );

      await mockRepo.addTrip(testTrip);
      await provider.selectTrip(testTrip.id);
    });

    test('TEST CASE 1: 5 Sequential Destinations Route & Waypoint Structure', () {
      // Create Day with Starting Point A and Ending Point B, plus 3 intermediate stops
      final origin = const RouteWaypoint(
        title: 'Darjeeling Railway Station',
        latitude: 27.0357,
        longitude: 88.2642,
        stopType: 'start',
      );

      final stop1 = const RouteWaypoint(
        title: 'Batasia Loop',
        latitude: 27.0167,
        longitude: 88.2472,
        stopType: 'stop',
        stopNumber: 1,
        visitDurationMinutes: 60,
      );

      final stop2 = const RouteWaypoint(
        title: 'Ghoom Monastery',
        latitude: 27.0134,
        longitude: 88.2520,
        stopType: 'stop',
        stopNumber: 2,
        visitDurationMinutes: 45,
      );

      final stop3 = const RouteWaypoint(
        title: 'Tiger Hill',
        latitude: 26.9944,
        longitude: 88.2861,
        stopType: 'stop',
        stopNumber: 3,
        visitDurationMinutes: 90,
      );

      final destination = const RouteWaypoint(
        title: 'Darjeeling Mall',
        latitude: 27.0435,
        longitude: 88.2685,
        stopType: 'end',
      );

      final waypoints = [origin, stop1, stop2, stop3, destination];

      // Verify sequence is preserved: START -> 1 -> 2 -> 3 -> FINAL
      expect(waypoints.length, 5);
      expect(waypoints[0].title, 'Darjeeling Railway Station');
      expect(waypoints[0].stopType, 'start');
      expect(waypoints[1].title, 'Batasia Loop');
      expect(waypoints[1].stopNumber, 1);
      expect(waypoints[2].title, 'Ghoom Monastery');
      expect(waypoints[2].stopNumber, 2);
      expect(waypoints[3].title, 'Tiger Hill');
      expect(waypoints[3].stopNumber, 3);
      expect(waypoints[4].title, 'Darjeeling Mall');
      expect(waypoints[4].stopType, 'end');

      // Verify planned visit durations
      expect(stop1.formattedVisitDuration, '1 hr');
      expect(stop2.formattedVisitDuration, '45 min');
      expect(stop3.formattedVisitDuration, '1 hr 30 min');
    });

    test('TEST CASE 2: Automatic Synchronization from Itinerary to Saved Places',
        () async {
      // Initially, currentSavedPlaces is empty
      expect(provider.currentSavedPlaces.length, 0);

      // Add Day 1 to provider
      final day1 = ItineraryDay(
        id: 'day_1',
        tripId: testTrip.id,
        dayNumber: 1,
        date: DateTime(2026, 12, 10),
        startPlaceName: 'Darjeeling Railway Station',
        startAddress: 'Hill Cart Rd, Darjeeling',
        startLatitude: 27.0357,
        startLongitude: 88.2642,
      );
      await provider.updateDay(day1);

      // Verify Starting Point automatically appears in Saved Places
      expect(provider.currentSavedPlaces.length, 1);
      expect(provider.currentSavedPlaces.first.name, 'Darjeeling Railway Station');
      expect(provider.currentSavedPlaces.first.latitude, 27.0357);
      expect(provider.currentSavedPlaces.first.locationNotes,
          contains('Day 1 Starting Point'));

      // Add Activity (Batasia Loop) to Day 1
      final act1 = ItineraryActivity(
        id: 'act_batasia',
        tripId: testTrip.id,
        dayId: 'day_1',
        title: 'Batasia Loop Spiral',
        placeName: 'Batasia Loop',
        address: 'Batasia, Darjeeling',
        latitude: 27.0167,
        longitude: 88.2472,
        category: ActivityCategory.sightseeing,
        durationMinutes: 60,
      );
      await provider.addActivity(act1);

      // Verify Batasia Loop automatically appears in Saved Places
      expect(provider.currentSavedPlaces.length, 2);
      final batasiaPlace =
          provider.currentSavedPlaces.firstWhere((p) => p.name == 'Batasia Loop');
      expect(batasiaPlace.category, 'Tourist Attractions');
      expect(batasiaPlace.latitude, 27.0167);
      expect(batasiaPlace.longitude, 88.2472);
      expect(batasiaPlace.locationNotes, contains('Batasia Loop Spiral'));

      // Add a manual place independently
      final manualPlace = SavedPlace(
        id: 'manual_place_1',
        tripId: testTrip.id,
        name: 'Glenary\'s Bakery & Cafe',
        category: 'Cafes',
        latitude: 27.0425,
        longitude: 88.2660,
      );
      await provider.addSavedPlace(manualPlace);
      expect(provider.currentSavedPlaces.length, 3);

      // Delete the Itinerary Activity (Batasia Loop)
      await provider.deleteActivity(act1.id, 'day_1');

      // Verify that Batasia Loop auto-synced record was cleanly removed
      expect(provider.currentSavedPlaces.any((p) => p.name == 'Batasia Loop'),
          isFalse);

      // Verify that manually saved place was PRESERVED
      expect(provider.currentSavedPlaces.any((p) => p.name == 'Glenary\'s Bakery & Cafe'),
          isTrue);
      // Verify that Starting Point was PRESERVED
      expect(provider.currentSavedPlaces.any((p) => p.name == 'Darjeeling Railway Station'),
          isTrue);
    });

    test('TEST CASE 3: Itinerary Activity Edit Updates Synced Saved Place',
        () async {
      final act = ItineraryActivity(
        id: 'act_ghoom',
        tripId: testTrip.id,
        dayId: 'day_1',
        title: 'Ghoom Monastery',
        placeName: 'Old Ghoom Monastery',
        latitude: 27.0134,
        longitude: 88.2520,
        category: ActivityCategory.sightseeing,
      );
      await provider.addActivity(act);

      expect(provider.currentSavedPlaces.any((p) => p.name == 'Old Ghoom Monastery'),
          isTrue);

      // Update the activity name and coordinates
      final updatedAct = act.copyWith(
        placeName: 'Yiga Choeling Monastery (Ghoom)',
        address: 'Ghoom High Rd, Darjeeling',
      );
      await provider.updateActivity(updatedAct);

      final synced = provider.currentSavedPlaces
          .firstWhere((p) => p.id == 'itinerary_act_${act.id}');
      expect(synced.name, 'Yiga Choeling Monastery (Ghoom)');
      expect(synced.address, 'Ghoom High Rd, Darjeeling');
    });

    test('TEST CASE 4: Route Information Panel Leg Details & Duration Calculation',
        () {
      const leg1 = RouteLegDetail(
        startTitle: 'Darjeeling Railway Station',
        endTitle: 'Batasia Loop',
        distanceMeters: 5200,
        durationSeconds: 1080, // 18 min
        endVisitDurationMinutes: 60, // 1 hr visit
      );

      const leg2 = RouteLegDetail(
        startTitle: 'Batasia Loop',
        endTitle: 'Ghoom Monastery',
        distanceMeters: 3100,
        durationSeconds: 720, // 12 min
        endVisitDurationMinutes: 45, // 45 min visit
      );

      const routeResult = RouteComputationResult(
        polylinePoints: [],
        totalDistanceMeters: 8300,
        totalDurationSeconds: 1800, // 30 min
        legs: [leg1, leg2],
      );

      expect(routeResult.formattedTotalDistance, '8.3 km');
      expect(routeResult.formattedTotalDuration, '30 min');
      expect(leg1.formattedDistance, '5.2 km');
      expect(leg1.formattedDuration, '18 min');
      expect(leg1.formattedVisitDuration, '1 hr');
      expect(leg2.formattedDistance, '3.1 km');
      expect(leg2.formattedDuration, '12 min');
      expect(leg2.formattedVisitDuration, '45 min');
    });
  });
}
