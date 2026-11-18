import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:royal_spend/core/config/google_maps_config.dart';
import 'package:royal_spend/core/services/maps/google_places_service.dart';
import 'package:royal_spend/core/services/maps/google_routes_service.dart';
import 'package:royal_spend/core/utils/map_marker_generator.dart';
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
import 'package:royal_spend/ui/widgets/maps/places_autocomplete_dialog.dart';
import 'package:royal_spend/ui/widgets/travel/trip_map_view.dart';

// In-memory fake repository for widget tests
class FakeTravelRepository implements ITravelRepository {
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
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId) async => [];

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async => [];

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) async => [];

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Maps & Places Config and Utilities Tests', () {
    test('GoogleMapsConfig provides valid bundled key', () {
      expect(GoogleMapsConfig.hasValidKey, isTrue);
      expect(GoogleMapsConfig.apiKey, isNotEmpty);
      expect(GoogleMapsConfig.apiKey.startsWith('AIza'), isTrue);
    });

    test('Places API (New) PlaceDetails parses JSON and resolves categories accurately', () {
      final json = {
        'id': 'places/ChIJw2w2iV2R5TkRZvV_pI1VwV0',
        'displayName': {'text': 'Glenary\'s Bakery, Restaurant & Pub'},
        'formattedAddress': 'Nehru Rd, Chauk Bazaar, Darjeeling, West Bengal 734101',
        'location': {'latitude': 27.0428, 'longitude': 88.2662},
        'types': ['restaurant', 'bakery', 'food', 'point_of_interest']
      };

      final details = PlaceDetails.fromJson(json);
      expect(details.id, equals('ChIJw2w2iV2R5TkRZvV_pI1VwV0'));
      expect(details.name, equals('Glenary\'s Bakery, Restaurant & Pub'));
      expect(details.latitude, equals(27.0428));
      expect(details.longitude, equals(88.2662));
      expect(details.bestCategory, equals('Restaurants'));

      final hotelJson = {
        'id': 'ChIJhotel123',
        'displayName': {'text': 'Windamere Hotel'},
        'formattedAddress': 'Observatory Hill, Darjeeling',
        'location': {'latitude': 27.0450, 'longitude': 88.2680},
        'types': ['lodging', 'hotel']
      };
      expect(PlaceDetails.fromJson(hotelJson).bestCategory, equals('Hotels'));

      final sightJson = {
        'id': 'ChIJsight123',
        'displayName': {'text': 'Tiger Hill'},
        'formattedAddress': 'Senchal, Darjeeling',
        'location': {'latitude': 26.9961, 'longitude': 88.2858},
        'types': ['tourist_attraction', 'natural_feature']
      };
      expect(PlaceDetails.fromJson(sightJson).bestCategory, equals('Tourist Attractions'));
    });

    test('GoogleRoutesService polyline decoder decodes standard encoded polyline', () {
      // Standard Google polyline test vector: (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = GoogleRoutesService.decodePolyline(encoded);

      expect(points.length, equals(3));
      expect(points[0].latitude, closeTo(38.5, 0.001));
      expect(points[0].longitude, closeTo(-120.2, 0.001));
      expect(points[1].latitude, closeTo(40.7, 0.001));
      expect(points[1].longitude, closeTo(-120.95, 0.001));
      expect(points[2].latitude, closeTo(43.252, 0.001));
      expect(points[2].longitude, closeTo(-126.453, 0.001));
    });

    test('RouteComputationResult formats distance and duration correctly', () {
      final res = RouteComputationResult(
        polylinePoints: const [LatLng(27.0, 88.0), LatLng(27.1, 88.1)],
        totalDistanceMeters: 145250,
        totalDurationSeconds: 13500, // 3h 45m
        legs: const [
          RouteLegDetail(
            startTitle: 'Jamshedpur',
            endTitle: 'Ranchi',
            distanceMeters: 130000,
            durationSeconds: 10800,
          ),
        ],
      );

      expect(res.formattedTotalDistance, equals('145.3 km'));
      expect(res.formattedTotalDuration, equals('3 hrs 45 min'));
      expect(res.legs.first.formattedDistance, equals('130.0 km'));
      expect(res.legs.first.formattedDuration, equals('3 hrs 0 min'));
    });

    test('SavedPlace model retains address, placeId, and coordinates', () {
      final place = SavedPlace(
        id: 'place_1',
        tripId: 'trip_1',
        name: 'Batasia Loop',
        address: 'Ghoom, Darjeeling, West Bengal',
        latitude: 27.0167,
        longitude: 88.2467,
        placeId: 'ChIJbatasia',
        category: 'Tourist Attractions',
      );

      final map = place.toMap();
      expect(map['address'], equals('Ghoom, Darjeeling, West Bengal'));
      expect(map['place_id'], equals('ChIJbatasia'));
      expect(map['latitude'], equals(27.0167));
      expect(map['longitude'], equals(88.2467));

      final restored = SavedPlace.fromMap(map);
      expect(restored.address, equals(place.address));
      expect(restored.placeId, equals(place.placeId));
      expect(restored.latitude, equals(place.latitude));
      expect(restored.longitude, equals(place.longitude));
    });

    test('ItineraryDay model retains start & end GPS coordinates and place IDs', () {
      final day = ItineraryDay(
        id: 'day_1',
        tripId: 'trip_1',
        dayNumber: 1,
        date: DateTime(2026, 11, 20),
        startPlaceName: 'Siliguri Junction',
        startAddress: 'Hill Cart Road, Siliguri',
        startLatitude: 26.7271,
        startLongitude: 88.4312,
        startPlaceId: 'ChIJsiliguri',
        endPlaceName: 'Darjeeling Mall',
        endAddress: 'Mall Road, Darjeeling',
        endLatitude: 27.0428,
        endLongitude: 88.2662,
        endPlaceId: 'ChIJdarjeeling',
      );

      expect(day.hasStartingCoordinates, isTrue);
      expect(day.hasEndCoordinates, isTrue);

      final map = day.toMap();
      expect(map['start_latitude'], equals(26.7271));
      expect(map['start_longitude'], equals(88.4312));
      expect(map['start_place_id'], equals('ChIJsiliguri'));
      expect(map['end_latitude'], equals(27.0428));
      expect(map['end_longitude'], equals(88.2662));
      expect(map['end_place_id'], equals('ChIJdarjeeling'));

      final restored = ItineraryDay.fromMap(map);
      expect(restored.startLatitude, equals(26.7271));
      expect(restored.startLongitude, equals(88.4312));
      expect(restored.startPlaceId, equals('ChIJsiliguri'));
      expect(restored.endLatitude, equals(27.0428));
      expect(restored.endLongitude, equals(88.2662));
      expect(restored.endPlaceId, equals('ChIJdarjeeling'));
    });

    test('ItineraryActivity model retains placeId and coordinates', () {
      final act = ItineraryActivity(
        id: 'act_1',
        tripId: 'trip_1',
        dayId: 'day_1',
        title: 'Peace Pagoda',
        placeName: 'Japanese Peace Pagoda',
        address: 'Jalapahar, Darjeeling',
        latitude: 27.0305,
        longitude: 88.2570,
        placeId: 'ChIJpeacepagoda',
      );

      final map = act.toMap();
      expect(map['place_id'], equals('ChIJpeacepagoda'));
      expect(map['latitude'], equals(27.0305));
      expect(map['longitude'], equals(88.2570));

      final restored = ItineraryActivity.fromMap(map);
      expect(restored.placeId, equals('ChIJpeacepagoda'));
      expect(restored.latitude, equals(27.0305));
      expect(restored.longitude, equals(88.2570));
    });

    test('MapMarkerGenerator creates numbered custom markers', () async {
      final markerA = await MapMarkerGenerator.createNumberedMarker(
        label: 'A',
        backgroundColor: Colors.green,
      );
      expect(markerA, isNotNull);

      final marker1 = await MapMarkerGenerator.createNumberedMarker(
        label: '1',
        backgroundColor: Colors.blue,
      );
      expect(marker1, isNotNull);

      final catMarker = await MapMarkerGenerator.createCategoryMarker(
        category: 'Restaurants',
      );
      expect(catMarker, isNotNull);
    });
  });

  group('TripMapView Option A & Option B Segmented Navigation Widget Tests', () {
    late FakeTravelRepository fakeRepo;
    late TravelProvider travelProvider;
    late Trip testTrip;

    setUp(() async {
      fakeRepo = FakeTravelRepository();
      travelProvider = TravelProvider(repository: fakeRepo);

      testTrip = Trip(
        id: 'trip_darjeeling',
        title: 'Darjeeling Explorer',
        destination: 'Darjeeling, West Bengal',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
      );

      await fakeRepo.addTrip(testTrip);
      await travelProvider.selectTrip(testTrip.id);
    });

    testWidgets('TripMapView renders Saved Places and Itinerary Route segmented tabs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TravelProvider>.value(
              value: travelProvider,
              child: const TripMapView(isDark: true),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify Saved Places (Default) and Itinerary Route segment buttons exist
      expect(find.text('Saved Places'), findsOneWidget);
      expect(find.text('Itinerary Route'), findsOneWidget);

      // Initially on Saved Places mode with category chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Tourist Attractions'), findsOneWidget);

      // Verify "Add Place" button is REMOVED from Maps & Places
      expect(find.text('Add Place'), findsNothing);

      // Tap on Itinerary Route
      await tester.tap(find.text('Itinerary Route'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Itinerary Route overview is displayed
      expect(find.text('Journey Route Overview'), findsOneWidget);

      // Tap back to Saved Places
      await tester.tap(find.text('Saved Places'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved Places'), findsOneWidget);
    });

    testWidgets('PlacesAutocompleteDialog displays search input and suggestions container',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteDialog(
              title: 'Select Itinerary Stop',
              hintText: 'Search city or landmark...',
              isDark: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select Itinerary Stop'), findsOneWidget);
      expect(find.text('Search city or landmark...'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    });
  });
}
