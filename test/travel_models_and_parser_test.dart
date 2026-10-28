import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/services/travel/darjeeling_sample_data.dart';
import 'package:royal_spend/core/services/travel/itinerary_text_parser.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/travel_accommodation.dart';
import 'package:royal_spend/data/models/travel_split.dart';
import 'package:royal_spend/data/models/trip.dart';

void main() {
  group('Trip Model & Calculation Tests', () {
    test('Calculates calendar days correctly (inclusive)', () {
      final trip = Trip(
        id: 'darjeeling-test',
        title: 'Darjeeling Winter Trip',
        destination: 'Darjeeling, West Bengal',
        startDate: DateTime(2026, 12, 10),
        endDate: DateTime(2026, 12, 18),
        budget: 25000,
      );

      // 10 Dec to 18 Dec inclusive = 9 calendar days
      expect(trip.calendarDaysCount, 9);
      expect(trip.durationString, '9 days');
      expect(trip.formattedDateRange, 'Dec 10 - 18, 2026');
    });

    test('Single day trip has 1 calendar day', () {
      final trip = Trip(
        id: 'single-day',
        title: 'Day Trip to Oodlabari',
        destination: 'Oodlabari',
        startDate: DateTime(2026, 12, 14),
        endDate: DateTime(2026, 12, 14),
      );

      expect(trip.calendarDaysCount, 1);
      expect(trip.durationString, '1 day');
    });

    test('Serialization toMap and fromMap round-trip preserves all fields', () {
      final trip = Trip(
        id: 'trip-roundtrip-1',
        title: 'Araku Valley Adventure',
        destination: 'Araku Valley, Andhra Pradesh',
        departureCity: 'Visakhapatnam',
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 8),
        travelersCount: 3,
        budget: 18000,
        currency: 'INR',
        description: 'Scenic coffee plantations and waterfalls',
        status: TripStatus.upcoming,
        preferences: ['Mountains', 'Nature', 'Adventure'],
      );

      final map = trip.toMap();
      final restored = Trip.fromMap(map);

      expect(restored.id, trip.id);
      expect(restored.title, trip.title);
      expect(restored.destination, trip.destination);
      expect(restored.departureCity, trip.departureCity);
      expect(restored.travelersCount, 3);
      expect(restored.budget, 18000);
      expect(restored.status, TripStatus.upcoming);
      expect(restored.preferences, contains('Mountains'));
      expect(restored.calendarDaysCount, 4);
    });
  });

  group('Itinerary Activity & Day Models Tests', () {
    test('ItineraryActivity stores schedule, costs, and flags properly', () {
      final activity = ItineraryActivity(
        id: 'act-1',
        tripId: 'trip-1',
        dayId: 'day-1',
        title: 'MAS NJP SF Express',
        placeName: 'Hijli Railway Station',
        startTime: '10:50 AM',
        endTime: '3:30 AM',
        category: ActivityCategory.transport,
        estimatedCost: 1450,
        notes: 'Overnight train journey. Arrival after midnight.',
        isOvernight: true,
        bookingStatus: BookingStatus.planned,
        isDestinationConfirmed: true,
      );

      expect(activity.isOvernight, isTrue);
      expect(activity.category.displayName, 'Transport');
      expect(activity.formattedCost, '₹1450');

      final updated = activity.copyWith(
        isCompleted: true,
        bookingStatus: BookingStatus.booked,
      );
      expect(updated.isCompleted, isTrue);
      expect(updated.bookingStatus, BookingStatus.booked);
      expect(updated.title, 'MAS NJP SF Express');
    });

    test('Day 3 unconfirmed exploration activity flag is respected', () {
      final activity = ItineraryActivity(
        id: 'act-day3-morning',
        tripId: 'trip-darjeeling',
        dayId: 'day-3',
        title: 'Early Wake-up for Morning Sightseeing',
        placeName: 'Destination not confirmed yet',
        startTime: '3:30 AM',
        category: ActivityCategory.sightseeing,
        notes: 'Destination awaiting confirmation. Tiger Hill excluded.',
        isDestinationConfirmed: false,
      );

      expect(activity.isDestinationConfirmed, isFalse);
      expect(activity.placeName, contains('not confirmed'));
    });
  });

  group('ItineraryTextParser - Darjeeling Specification & Intelligent Extraction', () {
    const rawDarjeelingItinerary = '''
Darjeeling Trip, 10 to 18 December 2026.
Departure from Hijli.
Preferred stay: Live In Nature homestay (earlier considered Trippers CastleWoods).
Local transport: Rented scooty.

10 December: MAS NJP SF Express from Hijli at 10:50 AM. Arrive at New Jalpaiguri at 3:30 AM next day.
11 December: Rest at NJP from 4:00 AM to 5:30 AM if required. Travel towards Darjeeling from Tenzing Norgay Central Bus Terminus, Siliguri at 6:30 AM. Arrive in Darjeeling around 10:00 - 10:30 AM. Arrange scooty and check-in to Live In Nature homestay by 12:00 PM. Lunch from 12:00 PM to 2:00 PM. Rest from 2:00 PM to 4:30 PM. Visit Japanese Peace Pagoda at 5:30 PM and explore Mall Road in the evening. Return to stay.
12 December: Wake up at 3:30 AM. Sightseeing destination not confirmed yet. Do not visit Tiger Hill.

Saved places:
Oodlabari, Siliguri, Death Road (Kurseong), Down Hill Church, Dow Hills, Jungpana Waterfall, Sukhiapokhri, Orange Valley Tea Garden, Chataidhura, Rohini, Senchal Wildlife Sanctuary, Japanese Peace Pagoda, Batasia Loop, Ghoom Monastery, Lamahatta, Mall Road, Lover's Meet View Point.
''';

    test('Parses Darjeeling notes extracting title, destination, and dates', () {
      final parsed = ItineraryTextParser.parse(rawDarjeelingItinerary);

      expect(parsed.title, contains('Darjeeling'));
      expect(parsed.destination, contains('Darjeeling'));
      expect(parsed.departureCity, 'Hijli');

      expect(parsed.startDate, isNotNull);
      expect(parsed.endDate, isNotNull);
      expect(parsed.startDate.year, 2026);
      expect(parsed.startDate.month, 12);
      expect(parsed.startDate.day, 10);

      expect(parsed.endDate.year, 2026);
      expect(parsed.endDate.month, 12);
      expect(parsed.endDate.day, 18);
    });

    test('Generates day blocks and activities for Dec 10, Dec 11, Dec 12', () {
      final parsed = ItineraryTextParser.parse(rawDarjeelingItinerary);

      expect(parsed.days.isNotEmpty, isTrue);

      // Check Dec 10 activities (Overnight train)
      final dec10 = parsed.days.firstWhere(
        (d) => d.date.day == 10,
        orElse: () => parsed.days.first,
      );
      expect(dec10.activities.isNotEmpty, isTrue);
      final trainAct = dec10.activities.firstWhere(
        (a) => a.title.contains('Express') || a.title.contains('MAS NJP'),
      );
      expect(trainAct.category, ActivityCategory.transport);
      expect(trainAct.startTime, '10:50 AM');
      expect(trainAct.isOvernight, isTrue);

      // Check Dec 11 activities
      final dec11 = parsed.days.firstWhere(
        (d) => d.date.day == 11,
      );
      expect(dec11.activities.length, greaterThanOrEqualTo(4));
      expect(
        dec11.activities.any((a) => a.title.contains('Peace Pagoda')),
        isTrue,
      );
      expect(
        dec11.activities.any((a) => a.title.contains('Mall Road')),
        isTrue,
      );

      // Check Dec 12 Day 3 (Morning wake-up with unconfirmed destination)
      final dec12 = parsed.days.firstWhere(
        (d) => d.date.day == 12,
      );
      final wakeUp = dec12.activities.firstWhere(
        (a) => a.title.contains('Wake up') || a.startTime == '3:30 AM',
      );
      expect(wakeUp.isDestinationConfirmed, isFalse);
    });

    test('Strict exclusion rule: Tiger Hill is not confirmed & flagged in warnings', () {
      final parsed = ItineraryTextParser.parse(rawDarjeelingItinerary);

      // Verify no activity has Tiger Hill as a confirmed place
      for (final day in parsed.days) {
        for (final act in day.activities) {
          expect(act.placeName?.toLowerCase().contains('tiger hill') ?? false, isFalse);
        }
      }

      // Parser must warn that Tiger Hill is explicitly excluded
      final hasTigerHillWarning = parsed.warnings.any(
        (w) => w.toLowerCase().contains('tiger hill'),
      );
      expect(hasTigerHillWarning, isTrue);
    });

    test('Exclusion rule: Chaltabon is removed and not in saved places', () {
      final parsed = ItineraryTextParser.parse(rawDarjeelingItinerary);

      for (final place in parsed.detectedSavedPlaces) {
        expect(place.name.toLowerCase().contains('chaltabon'), isFalse);
      }
    });

    test('Extracts saved places from natural language list', () {
      final parsed = ItineraryTextParser.parse(rawDarjeelingItinerary);

      final names = parsed.detectedSavedPlaces.map((p) => p.name).toList();
      expect(names, contains('Oodlabari'));
      expect(names, contains('Siliguri'));
      expect(names, contains('Batasia Loop'));
      expect(names, contains('Ghoom Monastery'));
      expect(names, contains('Lamahatta'));
      expect(names, contains('Mall Road'));
      expect(names.length, greaterThanOrEqualTo(10));
    });

    test('Handles malformed and minimal inputs gracefully without throwing', () {
      final parsed = ItineraryTextParser.parse('Just a quick note about trip next month');
      expect(parsed.days, isEmpty);
      expect(parsed.unclassifiedNotes, contains('quick note'));

      final emptyParsed = ItineraryTextParser.parse('');
      expect(emptyParsed.days, isEmpty);
      expect(emptyParsed.detectedSavedPlaces, isEmpty);
    });
  });

  group('DarjeelingSampleData Verification Package', () {
    test('Builds complete Darjeeling specification package', () {
      final package = DarjeelingSampleData.buildPackage();

      expect(package.trip.title, 'Darjeeling Trip');
      expect(package.trip.destination, 'Darjeeling, West Bengal, India');
      expect(package.trip.calendarDaysCount, 9);
      expect(package.trip.budget, 25000);

      // Verify 9 days created
      expect(package.days.length, 9);

      // Verify Day 1 has overnight train
      final day1Activities = package.activities
          .where((a) => a.dayId == package.days[0].id)
          .toList();
      expect(day1Activities.length, 1);
      expect(day1Activities.first.title, contains('MAS NJP SF Express'));
      expect(day1Activities.first.isOvernight, isTrue);

      // Verify Day 2 activities
      final day2Activities = package.activities
          .where((a) => a.dayId == package.days[1].id)
          .toList();
      expect(day2Activities.length, 9);

      // Verify Day 3 unconfirmed morning
      final day3Activities = package.activities
          .where((a) => a.dayId == package.days[2].id)
          .toList();
      expect(day3Activities.first.isDestinationConfirmed, isFalse);

      // Verify 17 saved places
      expect(package.savedPlaces.length, 17);
      expect(package.savedPlaces.any((p) => p.name == 'Oodlabari'), isTrue);
      expect(package.savedPlaces.any((p) => p.name == 'Death Road, Darjeeling'), isTrue);
      expect(package.savedPlaces.any((p) => p.name == "Lover's Meet View Point"), isTrue);
      expect(package.savedPlaces.any((p) => p.name.contains('Tiger Hill')), isFalse);
      expect(package.savedPlaces.any((p) => p.name.contains('Chaltabon')), isFalse);

      // Verify Transport & Homestay
      expect(package.transports.length, 3);
      expect(package.accommodations.length, 1);
      expect(
        package.accommodations.first.status,
        AccommodationStatus.savedPreference,
      );
      expect(
        package.accommodations.first.propertyName,
        'Live In Nature homestay',
      );

      // Verify Checklist items
      expect(package.checklist.length, greaterThanOrEqualTo(6));
    });
  });

  group('TravelSplit Net Settlements Simplification Algorithm', () {
    test('Calculates equal split and produces zero sum debt network', () {
      final split = TravelSplit(
        id: 'split-1',
        tripId: 'trip-1',
        title: 'Scooty Rental',
        totalAmount: 1800,
        paidBy: 'Subha',
        shares: {'Subha': 600, 'Rahul': 600, 'Sneha': 600},
      );

      final settlements = TravelSplit.calculateNetSettlements([split]);
      expect(settlements.length, 2);

      // Rahul owes Subha 600
      // Sneha owes Subha 600
      final rahulDebt = settlements.firstWhere((s) => s.fromPerson == 'Rahul');
      expect(rahulDebt.toPerson, 'Subha');
      expect(rahulDebt.amount, 600);

      final snehaDebt = settlements.firstWhere((s) => s.fromPerson == 'Sneha');
      expect(snehaDebt.toPerson, 'Subha');
      expect(snehaDebt.amount, 600);
    });

    test('Simplifies bilateral counter-debts into a single net settlement', () {
      final split1 = TravelSplit(
        id: 's-1',
        tripId: 'trip-1',
        title: 'Dinner at Glenary\'s',
        totalAmount: 2000,
        paidBy: 'Alice',
        shares: {'Alice': 1000, 'Bob': 1000},
      );

      final split2 = TravelSplit(
        id: 's-2',
        tripId: 'trip-1',
        title: 'Taxi to Ghoom',
        totalAmount: 1200,
        paidBy: 'Bob',
        shares: {'Alice': 600, 'Bob': 600},
      );

      // Alice paid 2000 (spent 1000 -> net +1000)
      // Later Alice spent 600 paid by Bob (net +1000 - 600 = +400)
      // Bob net: paid 1200, spent 1000 in split1 + 600 in split2 = 1600 total spent.
      // Net balance Bob: 1200 - 1600 = -400.
      // Result: Bob owes Alice 400.
      final settlements = TravelSplit.calculateNetSettlements([split1, split2]);
      expect(settlements.length, 1);
      expect(settlements.first.fromPerson, 'Bob');
      expect(settlements.first.toPerson, 'Alice');
      expect(settlements.first.amount, 400.0);
    });
  });
}
