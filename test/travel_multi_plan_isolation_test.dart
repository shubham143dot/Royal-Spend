import 'package:flutter_test/flutter_test.dart';
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

class MockTravelRepository implements ITravelRepository {
  final List<Trip> trips = [];
  final List<ItineraryDay> days = [];
  final List<ItineraryActivity> activities = [];
  final List<SavedPlace> savedPlaces = [];
  final List<TravelTransport> transports = [];
  final List<TravelAccommodation> accommodations = [];
  final List<TravelChecklistItem> checklist = [];
  final List<TravelSplit> splits = [];
  final List<Expense> expenses = [];

  @override
  Future<List<Trip>> getAllTrips() async => List.from(trips);

  @override
  Future<Trip?> getTrip(String id) async {
    final idx = trips.indexWhere((t) => t.id == id);
    return idx != -1 ? trips[idx] : null;
  }

  @override
  Future<void> addTrip(Trip trip) async {
    trips.add(trip);
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final idx = trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) trips[idx] = trip;
  }

  @override
  Future<void> deleteTrip(String id, {bool deleteExpenses = false}) async {
    trips.removeWhere((t) => t.id == id);
    days.removeWhere((d) => d.tripId == id);
    activities.removeWhere((a) => a.tripId == id);
    savedPlaces.removeWhere((s) => s.tripId == id);
    transports.removeWhere((tr) => tr.tripId == id);
    accommodations.removeWhere((ac) => ac.tripId == id);
    checklist.removeWhere((c) => c.tripId == id);
    splits.removeWhere((sp) => sp.tripId == id);
    if (deleteExpenses) {
      expenses.removeWhere((e) => e.tripId == id);
    }
  }

  @override
  Future<List<ItineraryDay>> getDaysForTrip(String tripId) async {
    return days.where((d) => d.tripId == tripId).toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
  }

  @override
  Future<void> addDay(ItineraryDay day) async {
    days.add(day);
  }

  @override
  Future<void> updateDay(ItineraryDay day) async {
    final idx = days.indexWhere((d) => d.id == day.id);
    if (idx != -1) days[idx] = day;
  }

  @override
  Future<void> deleteDay(String id) async {
    days.removeWhere((d) => d.id == id);
    activities.removeWhere((a) => a.dayId == id);
  }

  @override
  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) async {
    return activities.where((a) => a.dayId == dayId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) async {
    return activities.where((a) => a.tripId == tripId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> addActivity(ItineraryActivity activity) async {
    activities.add(activity);
  }

  @override
  Future<void> updateActivity(ItineraryActivity activity) async {
    final idx = activities.indexWhere((a) => a.id == activity.id);
    if (idx != -1) activities[idx] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
    activities.removeWhere((a) => a.id == id);
  }

  @override
  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) async {
    return savedPlaces.where((s) => s.tripId == tripId).toList();
  }

  @override
  Future<void> addSavedPlace(SavedPlace place) async {
    savedPlaces.add(place);
  }

  @override
  Future<void> updateSavedPlace(SavedPlace place) async {
    final idx = savedPlaces.indexWhere((s) => s.id == place.id);
    if (idx != -1) savedPlaces[idx] = place;
  }

  @override
  Future<void> deleteSavedPlace(String id) async {
    savedPlaces.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<TravelTransport>> getTransportsForTrip(String tripId) async {
    return transports.where((t) => t.tripId == tripId).toList();
  }

  @override
  Future<void> addTransport(TravelTransport transport) async {
    transports.add(transport);
  }

  @override
  Future<void> updateTransport(TravelTransport transport) async {
    final idx = transports.indexWhere((t) => t.id == transport.id);
    if (idx != -1) transports[idx] = transport;
  }

  @override
  Future<void> deleteTransport(String id) async {
    transports.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<TravelAccommodation>> getAccommodationsForTrip(String tripId) async {
    return accommodations.where((a) => a.tripId == tripId).toList();
  }

  @override
  Future<void> addAccommodation(TravelAccommodation accommodation) async {
    accommodations.add(accommodation);
  }

  @override
  Future<void> updateAccommodation(TravelAccommodation accommodation) async {
    final idx = accommodations.indexWhere((a) => a.id == accommodation.id);
    if (idx != -1) accommodations[idx] = accommodation;
  }

  @override
  Future<void> deleteAccommodation(String id) async {
    accommodations.removeWhere((a) => a.id == id);
  }

  @override
  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async {
    return checklist.where((c) => c.tripId == tripId).toList();
  }

  @override
  Future<void> addChecklistItem(TravelChecklistItem item) async {
    checklist.add(item);
  }

  @override
  Future<void> updateChecklistItem(TravelChecklistItem item) async {
    final idx = checklist.indexWhere((c) => c.id == item.id);
    if (idx != -1) checklist[idx] = item;
  }

  @override
  Future<void> deleteChecklistItem(String id) async {
    checklist.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<TravelSplit>> getSplitsForTrip(String tripId) async {
    return splits.where((s) => s.tripId == tripId).toList();
  }

  @override
  Future<void> addSplit(TravelSplit split) async {
    splits.add(split);
  }

  @override
  Future<void> deleteSplit(String id) async {
    splits.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<Expense>> getExpensesForTrip(String tripId) async {
    return expenses.where((e) => e.tripId == tripId).toList();
  }

  Future<double> getTotalExpensesForTrip(String tripId) async {
    return expenses
        .where((e) => e.tripId == tripId && !e.isIncome)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> seedDarjeelingTrip() async {}
}

void main() {
  group('Multi-Trip Isolation & Independence (Section 10 Acceptance Test Sequence)', () {
    late MockTravelRepository mockRepo;
    late TravelProvider provider;

    setUp(() async {
      mockRepo = MockTravelRepository();
      provider = TravelProvider(repository: mockRepo);
      await provider.initialize();
    });

    test('1 to 18: Complete sequence creating Darjeeling and Araku plans and verifying strict data isolation', () async {
      // 1. Create Darjeeling Trip
      final darjeelingTrip = await provider.createTrip(
        Trip(
          id: 'trip-darjeeling-iso',
          title: 'Darjeeling Trip',
          destination: 'Darjeeling, West Bengal',
          departureCity: 'Hijli',
          startDate: DateTime(2026, 12, 10),
          endDate: DateTime(2026, 12, 18),
          budget: 25000,
        ),
      );
      expect(darjeelingTrip.id.isNotEmpty, isTrue);
      expect(provider.trips.length, 1);

      // Select Darjeeling Trip workspace
      await provider.selectTrip(darjeelingTrip.id);
      expect(provider.selectedTrip?.title, 'Darjeeling Trip');
      expect(provider.currentDays.length, 9);

      // 2. Save multiple itinerary activities in Darjeeling
      final day1 = provider.currentDays[0];
      final day2 = provider.currentDays[1];

      await provider.addActivity(
        ItineraryActivity(
          id: 'act-darj-train',
          tripId: darjeelingTrip.id,
          dayId: day1.id,
          title: 'MAS NJP SF Express Train',
          placeName: 'Hijli Station',
          startTime: '10:50 AM',
          category: ActivityCategory.transport,
          estimatedCost: 1400,
          isOvernight: true,
        ),
      );

      await provider.addActivity(
        ItineraryActivity(
          id: 'act-darj-pagoda',
          tripId: darjeelingTrip.id,
          dayId: day2.id,
          title: 'Visit Japanese Peace Pagoda',
          placeName: 'Japanese Peace Pagoda',
          startTime: '5:30 PM',
          category: ActivityCategory.sightseeing,
          estimatedCost: 100,
        ),
      );

      expect(provider.allSelectedTripActivities.length, 2);

      // 3. Return to Travel Plans dashboard (clear workspace selection)
      provider.clearSelectedTrip();
      expect(provider.selectedTrip, isNull);
      expect(provider.allSelectedTripActivities, isEmpty);

      // 4. Create Araku Valley Adventure
      final arakuTrip = await provider.createTrip(
        Trip(
          id: 'trip-araku-iso',
          title: 'Araku Valley Adventure',
          destination: 'Araku Valley, Andhra Pradesh',
          departureCity: 'Visakhapatnam',
          startDate: DateTime(2026, 11, 5),
          endDate: DateTime(2026, 11, 8),
          budget: 15000,
        ),
      );
      expect(provider.trips.length, 2);

      // 5. Add different activities and budget information to Araku
      await provider.selectTrip(arakuTrip.id);
      expect(provider.selectedTrip?.title, 'Araku Valley Adventure');
      expect(provider.currentDays.length, 4);

      // Araku must start with ZERO activities from Darjeeling!
      expect(provider.allSelectedTripActivities, isEmpty);

      final arakuDay1 = provider.currentDays[0];
      await provider.addActivity(
        ItineraryActivity(
          id: 'act-araku-train',
          tripId: arakuTrip.id,
          dayId: arakuDay1.id,
          title: 'Vistadome Train to Araku',
          placeName: 'Visakhapatnam Railway Station',
          startTime: '6:45 AM',
          category: ActivityCategory.transport,
          estimatedCost: 800,
        ),
      );
      expect(provider.allSelectedTripActivities.length, 1);

      // 6. Return to dashboard
      provider.clearSelectedTrip();

      // 7. Open Darjeeling Trip
      await provider.selectTrip(darjeelingTrip.id);

      // 8. Confirm that Darjeeling activities remain unchanged (2 activities)
      expect(provider.selectedTrip?.id, darjeelingTrip.id);
      expect(provider.allSelectedTripActivities.length, 2);
      expect(
        provider.allSelectedTripActivities.any((a) => a.title.contains('MAS NJP')),
        isTrue,
      );
      expect(
        provider.allSelectedTripActivities.any((a) => a.title.contains('Vistadome')),
        isFalse, // No Araku activity inside Darjeeling!
      );

      // 9. Open Araku Valley Adventure
      await provider.selectTrip(arakuTrip.id);

      // 10. Confirm that no Darjeeling activities are displayed in Araku
      expect(provider.selectedTrip?.id, arakuTrip.id);
      expect(provider.allSelectedTripActivities.length, 1);
      expect(
        provider.allSelectedTripActivities.first.title,
        'Vistadome Train to Araku',
      );
      expect(
        provider.allSelectedTripActivities.any((a) => a.title.contains('MAS NJP')),
        isFalse,
      );

      // 11. Change Araku's budget
      await provider.updateTrip(
        provider.selectedTrip!.copyWith(budget: 22000),
      );
      expect(provider.selectedTrip?.budget, 22000);

      // 12. Reopen Darjeeling
      await provider.selectTrip(darjeelingTrip.id);

      // 13. Confirm that Darjeeling budget has not changed (still 25000)
      expect(provider.selectedTrip?.id, darjeelingTrip.id);
      expect(provider.selectedTrip?.budget, 25000);

      // 14. Edit an activity in Darjeeling
      final pagodaAct = provider.allSelectedTripActivities.firstWhere(
        (a) => a.title.contains('Peace Pagoda'),
      );
      await provider.updateActivity(
        pagodaAct.copyWith(estimatedCost: 250, notes: 'Purchased butter lamps'),
      );

      // 15. Open Araku again
      await provider.selectTrip(arakuTrip.id);

      // 16. Confirm that Araku itinerary remains unchanged
      expect(provider.allSelectedTripActivities.length, 1);
      expect(provider.allSelectedTripActivities.first.estimatedCost, 800);

      // 17 & 18. Simulate app restart with fresh provider pointing to the same repository
      final newProviderSession = TravelProvider(repository: mockRepo);
      await newProviderSession.initialize();

      expect(newProviderSession.trips.length, 2);

      // Re-verify Darjeeling
      await newProviderSession.selectTrip(darjeelingTrip.id);
      expect(newProviderSession.selectedTrip?.budget, 25000);
      expect(newProviderSession.allSelectedTripActivities.length, 2);
      final reloadedPagoda = newProviderSession.allSelectedTripActivities.firstWhere(
        (a) => a.title.contains('Peace Pagoda'),
      );
      expect(reloadedPagoda.estimatedCost, 250);

      // Re-verify Araku
      await newProviderSession.selectTrip(arakuTrip.id);
      expect(newProviderSession.selectedTrip?.budget, 22000);
      expect(newProviderSession.allSelectedTripActivities.length, 1);
      expect(newProviderSession.allSelectedTripActivities.first.title, 'Vistadome Train to Araku');
    });

    test('Allows multiple trips with identical titles without conflict', () async {
      final trip1 = await provider.createTrip(
        Trip(
          id: 'darj-title-1',
          title: 'Darjeeling Trip',
          destination: 'Darjeeling, West Bengal',
          startDate: DateTime(2026, 12, 10),
          endDate: DateTime(2026, 12, 18),
        ),
      );

      final trip2 = await provider.createTrip(
        Trip(
          id: 'darj-title-2',
          title: 'Darjeeling Trip', // Identical title!
          destination: 'Darjeeling, West Bengal',
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2027, 4, 6),
        ),
      );

      expect(trip1.id, isNot(trip2.id));
      expect(provider.trips.length, 2);
      expect(provider.trips[0].title, provider.trips[1].title);

      // Can open trip 1
      await provider.selectTrip(trip1.id);
      expect(provider.selectedTrip?.id, trip1.id);
      expect(provider.currentDays.length, 9);

      // Can open trip 2
      await provider.selectTrip(trip2.id);
      expect(provider.selectedTrip?.id, trip2.id);
      expect(provider.currentDays.length, 6);
    });

    test('Deep duplicating a trip assigns new IDs and does not duplicate financial expenses', () async {
      final original = await provider.createTrip(
        Trip(
          id: 'goa-vacation',
          title: 'Goa Vacation',
          destination: 'Goa',
          startDate: DateTime(2026, 11, 20),
          endDate: DateTime(2026, 11, 25),
          budget: 30000,
        ),
      );

      await provider.selectTrip(original.id);
      await provider.addActivity(
        ItineraryActivity(
          id: 'act-goa-1',
          tripId: original.id,
          dayId: provider.currentDays[0].id,
          title: 'Sunset at Anjuna Beach',
          placeName: 'Anjuna Beach',
          category: ActivityCategory.sightseeing,
        ),
      );

      // Add expense to original trip
      mockRepo.expenses.add(
        Expense(
          id: 'exp-original',
          title: 'Flight Ticket',
          amount: 8500,
          categoryId: 'travel',
          date: DateTime(2026, 11, 20),
          tripId: original.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Duplicate trip
      final duplicated = await provider.duplicateTrip(original.id);
      expect(duplicated, isNotNull);
      expect(duplicated.id, isNot(original.id));
      expect(duplicated.title, 'Goa Vacation (Copy)');

      // Open duplicated trip
      await provider.selectTrip(duplicated.id);
      expect(provider.allSelectedTripActivities.length, 1);
      expect(provider.allSelectedTripActivities.first.id, isNot(mockRepo.activities.first.id));
      expect(provider.allSelectedTripActivities.first.tripId, duplicated.id);

      // Expenses must NOT be duplicated
      final duplicatedExpenses = await mockRepo.getExpensesForTrip(duplicated.id);
      expect(duplicatedExpenses, isEmpty);
    });

    test('Rapid trip switching cancels obsolete queries and prevents state bleed', () async {
      final tripA = await provider.createTrip(
        Trip(
          id: 'kolkata-shop',
          title: 'Kolkata Shopping',
          destination: 'Kolkata',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 3),
        ),
      );
      final tripB = await provider.createTrip(
        Trip(
          id: 'manali-snow',
          title: 'Manali Snow Trek',
          destination: 'Manali',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
        ),
      );

      // Fire selection for Trip A and immediately for Trip B
      final futureA = provider.selectTrip(tripA.id);
      final futureB = provider.selectTrip(tripB.id);

      await Future.wait([futureA, futureB]);

      // Final state must strictly reflect Trip B
      expect(provider.selectedTrip?.id, tripB.id);
      expect(provider.selectedTrip?.title, 'Manali Snow Trek');
      expect(provider.currentDays.length, 5);
    });
  });
}
