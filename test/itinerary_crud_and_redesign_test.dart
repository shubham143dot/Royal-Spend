import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
import 'package:royal_spend/ui/widgets/travel/add_edit_activity_sheet.dart';
import 'package:royal_spend/ui/widgets/travel/add_edit_day_sheet.dart';
import 'package:royal_spend/ui/widgets/travel/itinerary_timeline_view.dart';

class MockTravelRepository implements ITravelRepository {
  final Map<String, Trip> trips = {};
  final Map<String, ItineraryDay> days = {};
  final Map<String, ItineraryActivity> activities = {};

  @override
  Future<List<Trip>> getAllTrips() async => trips.values.toList();

  @override
  Future<Trip?> getTrip(String id) async => trips[id];

  @override
  Future<void> addTrip(Trip trip) async => trips[trip.id] = trip;

  @override
  Future<void> updateTrip(Trip trip) async => trips[trip.id] = trip;

  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async {
    trips.remove(id);
    days.removeWhere((_, d) => d.tripId == id);
    activities.removeWhere((_, a) => a.tripId == id);
  }

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) async {
    final list = days.values.where((d) => d.tripId == tripId).toList();
    list.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return list;
  }

  @override
  Future<void> addDay(ItineraryDay day) async => days[day.id] = day;

  @override
  Future<void> updateDay(ItineraryDay day) async => days[day.id] = day;

  @override
  Future<void> deleteDay(String id) async {
    days.remove(id);
    activities.removeWhere((_, a) => a.dayId == id);
  }

  @override
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) async {
    final list = activities.values.where((a) => a.dayId == dayId).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) async {
    final list = activities.values.where((a) => a.tripId == tripId).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<void> addActivity(ItineraryActivity activity) async =>
      activities[activity.id] = activity;

  @override
  Future<void> updateActivity(ItineraryActivity activity) async =>
      activities[activity.id] = activity;

  @override
  Future<void> deleteActivity(String id) async => activities.remove(id);

  @override
  Future<void> reorderActivities(
      String dayId, List<ItineraryActivity> reordered) async {
    for (final a in reordered) {
      activities[a.id] = a;
    }
  }

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) async => [];
  @override
  Future<void> addSavedPlace(SavedPlace place) async {}
  @override
  Future<void> updateSavedPlace(SavedPlace place) async {}
  @override
  Future<void> deleteSavedPlace(String id) async {}

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) async => [];
  @override
  Future<void> addTransport(TravelTransport transport) async {}
  @override
  Future<void> updateTransport(TravelTransport transport) async {}
  @override
  Future<void> deleteTransport(String id) async {}

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId) async => [];
  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {}
  @override
  Future<void> deleteAccommodation(String id) async {}

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async => [];
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
  @override
  Future<void> deleteSplit(String id) async {}

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) async => [];
}

void main() {
  group('Itinerary CRUD & State Tests', () {
    late MockTravelRepository repository;
    late TravelProvider provider;

    setUp(() {
      repository = MockTravelRepository();
      provider = TravelProvider(repository: repository);
    });

    test('ItineraryActivity model handles isOvernight and round-trips correctly', () {
      final act = ItineraryActivity(
        id: 'act_101',
        tripId: 'trip_1',
        dayId: 'day_1',
        title: 'Overnight Sleeper Train',
        placeName: 'MAS NJP Express',
        startTime: '10:50 PM',
        endTime: '08:00 AM',
        durationMinutes: 550,
        category: ActivityCategory.transport,
        notes: 'Upper berth 45 & 46',
        address: 'Platform 5, Chennai Central',
        estimatedCost: 1450.0,
        bookingStatus: BookingStatus.booked,
        bookingReference: 'PNR89472910',
        isCompleted: false,
        isDestinationConfirmed: true,
        isOvernight: true,
        sortOrder: 0,
      );

      final map = act.toMap();
      expect(map['is_overnight'], equals(1));
      expect(map['estimated_cost'], equals(1450.0));
      expect(map['booking_status'], equals('booked'));

      final reconstructed = ItineraryActivity.fromMap(map);
      expect(reconstructed.id, equals('act_101'));
      expect(reconstructed.isOvernight, isTrue);
      expect(reconstructed.title, equals('Overnight Sleeper Train'));
      expect(reconstructed.placeName, equals('MAS NJP Express'));
      expect(reconstructed.category, equals(ActivityCategory.transport));
      expect(reconstructed.estimatedCost, equals(1450.0));
      expect(reconstructed.bookingStatus, equals(BookingStatus.booked));
    });

    test('Add, Edit, Delete Day flow works in TravelProvider', () async {
      final trip = Trip(
        id: 'test_trip_1',
        title: 'Goa Weekend',
        destination: 'Goa',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 12),
      );

      await provider.createTrip(trip);
      await provider.selectTrip('test_trip_1');

      // 3 calendar days auto-generated: Nov 10, 11, 12
      expect(provider.currentDays.length, equals(3));
      expect(provider.selectedDay, isNotNull);
      expect(provider.selectedDay!.dayNumber, equals(1));

      // Add a custom 4th day
      final newDay = ItineraryDay(
        id: 'test_trip_1_day_4',
        tripId: 'test_trip_1',
        dayNumber: 4,
        date: DateTime(2026, 11, 13),
        title: 'South Goa Beach Sunset',
      );
      await provider.addDay(newDay);
      expect(provider.currentDays.length, equals(4));
      expect(provider.selectedDay!.dayNumber, equals(4));

      // Update Day 4
      final updatedDay = newDay.copyWith(title: 'Palolem Beach & Boat Ride');
      await provider.updateDay(updatedDay);
      expect(provider.selectedDay!.title, equals('Palolem Beach & Boat Ride'));

      // Delete Day 4
      await provider.deleteDay('test_trip_1_day_4');
      expect(provider.currentDays.length, equals(3));
      expect(provider.selectedDay!.dayNumber, equals(1));
    });

    test('Add, Edit, Toggle, Reorder, and Delete Activity stops flow works', () async {
      final trip = Trip(
        id: 'kerala_trip',
        title: 'Munnar & Alleppey',
        destination: 'Kerala',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 3),
      );

      await provider.createTrip(trip);
      await provider.selectTrip('kerala_trip');

      final day1 = provider.currentDays.first;

      // Add Stop 1
      final stop1 = ItineraryActivity(
        id: 'stop_1',
        tripId: 'kerala_trip',
        dayId: day1.id,
        title: 'Tea Museum Tour',
        placeName: 'KDHP Tea Museum',
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        category: ActivityCategory.sightseeing,
        estimatedCost: 250.0,
      );
      await provider.addActivity(stop1);

      // Add Stop 2
      final stop2 = ItineraryActivity(
        id: 'stop_2',
        tripId: 'kerala_trip',
        dayId: day1.id,
        title: 'Traditional Kerala Lunch',
        placeName: 'Rapsy Restaurant',
        startTime: '12:30 PM',
        endTime: '01:30 PM',
        category: ActivityCategory.meal,
        estimatedCost: 400.0,
      );
      await provider.addActivity(stop2);

      expect(provider.activitiesByDay[day1.id]!.length, equals(2));
      expect(provider.getDailyEstimatedCost(day1.id), equals(650.0));

      // Toggle completion on stop 1
      await provider.toggleActivityCompletion(stop1);
      final refreshedStop1 = provider.activitiesByDay[day1.id]!
          .firstWhere((a) => a.id == 'stop_1');
      expect(refreshedStop1.isCompleted, isTrue);

      // Edit stop 2 (update cost)
      final editedStop2 = stop2.copyWith(estimatedCost: 550.0);
      await provider.updateActivity(editedStop2);
      expect(provider.getDailyEstimatedCost(day1.id), equals(800.0));

      // Reorder activities (move stop 1 down)
      await provider.reorderActivities(day1.id, 0, 2);
      expect(provider.activitiesByDay[day1.id]!.first.id, equals('stop_2'));

      // Delete stop 1
      await provider.deleteActivity('stop_1', day1.id);
      expect(provider.activitiesByDay[day1.id]!.length, equals(1));
      expect(provider.activitiesByDay[day1.id]!.first.id, equals('stop_2'));
    });
  });

  group('Itinerary Widgets Rendering Tests', () {
    testWidgets('ItineraryTimelineView renders day summary and stops cleanly',
        (tester) async {
      final repository = MockTravelRepository();
      final provider = TravelProvider(repository: repository);

      final trip = Trip(
        id: 'shimla_trip',
        title: 'Shimla Getaway',
        destination: 'Shimla',
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 6),
      );

      await provider.createTrip(trip);
      await provider.selectTrip('shimla_trip');
      final day1 = provider.currentDays.first;

      await provider.addActivity(
        ItineraryActivity(
          id: 'act_mall_road',
          tripId: 'shimla_trip',
          dayId: day1.id,
          title: 'Mall Road Stroll',
          placeName: 'The Ridge & Mall Road',
          startTime: '04:00 PM',
          category: ActivityCategory.sightseeing,
          estimatedCost: 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TravelProvider>.value(
            value: provider,
            child: Scaffold(
              body: ItineraryTimelineView(
                day: day1,
                isDark: false,
                onAddStop: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day 1 Itinerary'), findsOneWidget);
      expect(find.text('The Ridge & Mall Road'), findsOneWidget);
      expect(find.text('04:00 PM'), findsOneWidget);
      expect(find.text('Sightseeing'), findsOneWidget);
    });

    testWidgets('AddEditDaySheet renders fields and has Delete Day when editing',
        (tester) async {
      final day = ItineraryDay(
        id: 'day_edit_test',
        tripId: 'trip_1',
        dayNumber: 2,
        date: DateTime(2026, 11, 15),
        title: 'Explore Old Town',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditDaySheet(
              tripId: 'trip_1',
              dayToEdit: day,
              defaultDayNumber: 2,
              defaultDate: DateTime(2026, 11, 15),
              isDark: false,
              onSave: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Itinerary Day'), findsOneWidget);
      expect(find.text('Delete This Day'), findsOneWidget);
    });

    testWidgets('AddEditActivitySheet renders and has Delete Stop when editing',
        (tester) async {
      final activity = ItineraryActivity(
        id: 'act_edit_test',
        tripId: 'trip_1',
        dayId: 'day_1',
        title: 'Visit Museum',
        placeName: 'National Heritage Museum',
        category: ActivityCategory.sightseeing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditActivitySheet(
              tripId: 'trip_1',
              dayId: 'day_1',
              activityToEdit: activity,
              isDark: false,
              onSave: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Itinerary Stop'), findsOneWidget);
      expect(find.text('Delete Stop'), findsOneWidget);
    });
  });
}
