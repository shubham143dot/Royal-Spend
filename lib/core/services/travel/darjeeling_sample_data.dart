import 'package:uuid/uuid.dart';

import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../data/models/saved_place.dart';
import '../../../data/models/travel_accommodation.dart';
import '../../../data/models/travel_checklist_item.dart';
import '../../../data/models/travel_transport.dart';
import '../../../data/models/trip.dart';

class DarjeelingTripDataPackage {
  final Trip trip;
  final List<ItineraryDay> days;
  final List<ItineraryActivity> activities;
  final List<SavedPlace> savedPlaces;
  final List<TravelTransport> transports;
  final List<TravelAccommodation> accommodations;
  final List<TravelChecklistItem> checklist;

  const DarjeelingTripDataPackage({
    required this.trip,
    required this.days,
    required this.activities,
    required this.savedPlaces,
    required this.transports,
    required this.accommodations,
    required this.checklist,
  });
}

class DarjeelingSampleData {
  static const String rawText = '''
Darjeeling Trip, 10 to 18 December 2026.

10 December: Train from Hijli at 10:50 AM. MAS NJP SF Express. Arrive at New Jalpaiguri at 3:30 AM the next day.

11 December: Rest at NJP from 4 to 5:30 AM if required. Travel towards Darjeeling at 6:30 AM from Tenzing Norgay Central Bus Terminus, Siliguri. Arrive around 10:00–10:30 AM. Arrange a rented scooty, subject to availability, and check in to preferred accommodation Live In Nature homestay around 12:00 PM. Freshen up and lunch until 2 PM. Rest following the journey until 4:30 PM. Begin evening sightseeing departure at 5:00 PM. Visit Japanese Peace Pagoda from 5:30 to 6:00 PM and explore Mall Road in the evening. Return to accommodation and rest.

12 December: Wake up at 3:30 AM for early morning exploration. Sightseeing destination not confirmed yet. Awaiting confirmation. (Note: Tiger Hill must remain excluded).
''';

  static DarjeelingTripDataPackage buildPackage({String? customTripId}) {
    const uuid = Uuid();
    final tripId = customTripId ?? uuid.v4();

    // 10 to 18 December 2026 (9 calendar days)
    final startDate = DateTime(2026, 12, 10);
    final endDate = DateTime(2026, 12, 18);

    final trip = Trip(
      id: tripId,
      title: 'Darjeeling Trip',
      destination: 'Darjeeling, West Bengal, India',
      departureCity: 'Hijli',
      startDate: startDate,
      endDate: endDate,
      currency: 'INR',
      travelersCount: 1,
      travelersNames: const ['You'],
      budget: 25000.0,
      transportBudget: 6000.0,
      accommodationBudget: 9000.0,
      foodBudget: 5000.0,
      sightseeingBudget: 3000.0,
      shoppingBudget: 2000.0,
      description:
          'Winter adventure to the Queen of Hills via NJP and Siliguri. Rented scooty exploration and Himalayan vistas.',
      preferences: const ['Mountains', 'Nature', 'Scenic viewpoints', 'Adventure'],
      status: TripStatus.upcoming,
    );

    // Days (9 days)
    final days = <ItineraryDay>[];
    for (int i = 0; i < 9; i++) {
      final dayNum = i + 1;
      final dayDate = startDate.add(Duration(days: i));
      String? title;
      if (dayNum == 1) title = 'Overnight Train from Hijli';
      if (dayNum == 2) title = 'Siliguri Transit & Pagoda Evening';
      if (dayNum == 3) title = 'Early Exploration (Unconfirmed)';
      if (dayNum > 3) title = 'Day $dayNum — Complete your itinerary';

      days.add(ItineraryDay(
        id: '${tripId}_day_$dayNum',
        tripId: tripId,
        dayNumber: dayNum,
        date: dayDate,
        title: title,
        notes: dayNum > 3 ? 'Awaiting your custom plan. Add saved places or activities.' : null,
      ));
    }

    final activities = <ItineraryActivity>[];

    // Day 1 Activities (10 Dec)
    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_1',
      title: 'MAS NJP SF Express',
      placeName: 'Hijli Railway Station to New Jalpaiguri',
      startTime: '10:50 AM',
      endTime: '03:30 AM', // next day
      durationMinutes: 1000,
      category: ActivityCategory.transport,
      notes:
          'Overnight train journey. Departs Hijli 10:50 AM (10 Dec), arrives NJP 3:30 AM next day (11 Dec). Flagged for schedule confirmation.',
      bookingStatus: BookingStatus.unconfirmed,
      isDestinationConfirmed: true,
      isOvernight: true,
      sortOrder: 1,
    ));

    // Day 2 Activities (11 Dec)
    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Optional Early Rest',
      placeName: 'New Jalpaiguri Area',
      startTime: '04:00 AM',
      endTime: '05:30 AM',
      durationMinutes: 90,
      category: ActivityCategory.rest,
      notes:
          'Rest at available railway facility or nearby location. Optional and unconfirmed.',
      bookingStatus: BookingStatus.optional,
      sortOrder: 1,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Road Journey to Darjeeling',
      placeName: 'Tenzing Norgay Central Bus Terminus, Siliguri',
      startTime: '06:30 AM',
      endTime: '10:00 AM',
      durationMinutes: 210,
      category: ActivityCategory.transport,
      notes:
          'Bus or suitable road transport from Siliguri. Transfer from NJP to bus terminus requires travel-time confirmation.',
      bookingStatus: BookingStatus.unconfirmed,
      sortOrder: 2,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Scooty Rental & Check-in',
      placeName: 'Live In Nature Homestay, Darjeeling',
      startTime: '10:30 AM',
      endTime: '12:00 PM',
      durationMinutes: 90,
      category: ActivityCategory.accommodation,
      notes:
          'Reach Darjeeling. Arrange rented scooty if available/suitable. Travel to Live In Nature homestay (preferred preference, unconfirmed).',
      bookingStatus: BookingStatus.unconfirmed,
      sortOrder: 3,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Freshen up & Lunch',
      placeName: 'Darjeeling',
      startTime: '12:00 PM',
      endTime: '02:00 PM',
      durationMinutes: 120,
      category: ActivityCategory.meal,
      notes: 'Freshen up and enjoy warm Himalayan lunch.',
      sortOrder: 4,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Afternoon Rest',
      placeName: 'Homestay',
      startTime: '02:00 PM',
      endTime: '04:30 PM',
      durationMinutes: 150,
      category: ActivityCategory.rest,
      notes: 'Rest following the mountain journey.',
      sortOrder: 5,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Begin Evening Sightseeing',
      placeName: 'Darjeeling',
      startTime: '05:00 PM',
      endTime: null,
      category: ActivityCategory.sightseeing,
      notes: 'Evening stroll start toward Peace Pagoda.',
      sortOrder: 6,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Visit Japanese Peace Pagoda',
      placeName: 'Japanese Peace Pagoda, Darjeeling',
      startTime: '05:30 PM',
      endTime: '06:00 PM',
      durationMinutes: 30,
      category: ActivityCategory.sightseeing,
      notes: 'Quiet evening stupa visit. Opening hours subject to verification.',
      bookingStatus: BookingStatus.notNeeded,
      sortOrder: 7,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Explore Mall Road',
      placeName: 'Mall Road, Darjeeling',
      startTime: '06:30 PM',
      endTime: null, // exact time unspecified
      category: ActivityCategory.sightseeing,
      notes: 'Evening walk along Mall Road promenade. Unspecified exact times.',
      sortOrder: 8,
    ));

    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_2',
      title: 'Return and Rest',
      placeName: 'Live In Nature Homestay',
      startTime: '08:30 PM',
      endTime: null,
      category: ActivityCategory.rest,
      notes: 'Return to accommodation and prepare for next day.',
      sortOrder: 9,
    ));

    // Day 3 Activities (12 Dec)
    activities.add(ItineraryActivity(
      id: uuid.v4(),
      tripId: tripId,
      dayId: '${tripId}_day_3',
      title: 'Early Wake-up for Sightseeing',
      placeName: 'Destination awaiting confirmation',
      startTime: '03:30 AM',
      endTime: null,
      category: ActivityCategory.sightseeing,
      notes:
          'Wake up early at 3:30 AM. Sightseeing destination not confirmed yet. Tiger Hill is explicitly excluded.',
      isDestinationConfirmed: false,
      bookingStatus: BookingStatus.unconfirmed,
      sortOrder: 1,
    ));

    // Saved Places (17 places - Chaltabon removed, Tiger Hill excluded)
    final savedPlaces = <SavedPlace>[
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Oodlabari',
        locationNotes: 'Scenic transit foothill destination',
        category: 'Sightseeing',
        latitude: 26.8375,
        longitude: 88.6655,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Siliguri',
        locationNotes: 'Road transport & gateway hub to North Bengal hills',
        category: 'Transport',
        latitude: 26.7271,
        longitude: 88.3953,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Death Road, Darjeeling',
        locationNotes:
            'Forest stretch between Dow Hill Road and Forest Office in Dow Hill, Kurseong',
        category: 'Adventure',
        latitude: 26.8814,
        longitude: 88.2778,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Down Hill Church',
        locationNotes: 'Historic heritage church in Dow Hill, Kurseong',
        category: 'Sightseeing',
        latitude: 26.8805,
        longitude: 88.2760,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Dow Hills',
        locationNotes: 'Pine-covered misty hills and scenic trails in Kurseong',
        category: 'Nature',
        latitude: 26.8822,
        longitude: 88.2790,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Jungpana Waterfall',
        locationNotes: 'Secluded mountain waterfall near Jungpana tea estate',
        category: 'Nature',
        latitude: 26.9020,
        longitude: 88.3050,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Sukhiapokhri',
        locationNotes:
            'Highland border hamlet on the road to Mirik and Manebhanjan',
        category: 'Scenic',
        latitude: 26.9961,
        longitude: 88.1697,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Orange Valley Tea Garden',
        locationNotes:
            'Historic rolling organic tea estate in Darjeeling foothills',
        category: 'Sightseeing',
        latitude: 27.0210,
        longitude: 88.2430,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Chataidhura',
        locationNotes:
            'Panoramic ridge viewpoint and tea trail near Darjeeling',
        category: 'Scenic',
        latitude: 27.0150,
        longitude: 88.2280,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Rohini, Darjeeling',
        locationNotes:
            'Scenic ghat road and valley viewpoint ascending to Kurseong',
        category: 'Scenic',
        latitude: 26.7915,
        longitude: 88.3280,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Senchal Wildlife Sanctuary',
        locationNotes:
            'High-altitude sanctuary with pristine oak-pine forests & mountain lakes',
        category: 'Nature',
        latitude: 27.0090,
        longitude: 88.2710,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Japanese Peace Pagoda',
        locationNotes:
            'Serene Buddhist stupa showcasing four avatars of Lord Buddha',
        category: 'Cultural',
        latitude: 27.0305,
        longitude: 88.2612,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Batasia Loop',
        locationNotes:
            'Spiral railway loop with war memorial & 360-degree Kanchenjunga view',
        category: 'Sightseeing',
        latitude: 27.0168,
        longitude: 88.2465,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Ghoom Monastery',
        locationNotes:
            'Historic Yiga Choeling monastery housing a 15-foot Maitreya Buddha',
        category: 'Cultural',
        latitude: 27.0112,
        longitude: 88.2575,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Lamahatta',
        locationNotes:
            'Tranquil eco-park with towering pine groves & sacred prayer-flag lake',
        category: 'Nature',
        latitude: 27.0450,
        longitude: 88.3480,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: 'Mall Road',
        locationNotes:
            'Iconic pedestrian promenade and vibrant social center of Darjeeling',
        category: 'Shopping',
        latitude: 27.0435,
        longitude: 88.2660,
      ),
      SavedPlace(
        id: uuid.v4(),
        tripId: tripId,
        name: "Lover's Meet View Point",
        locationNotes:
            'Confluence of the turquoise Teesta and emerald Rangeet rivers',
        category: 'Scenic',
        latitude: 27.0850,
        longitude: 88.4230,
      ),
    ];

    // Transports
    final transports = <TravelTransport>[
      TravelTransport(
        id: uuid.v4(),
        tripId: tripId,
        type: TransportType.train,
        provider: 'MAS NJP SF Express',
        departurePlace: 'Hijli (HIJ)',
        arrivalPlace: 'New Jalpaiguri (NJP)',
        departureTime: DateTime(2026, 12, 10, 10, 50),
        arrivalTime: DateTime(2026, 12, 11, 3, 30),
        bookingStatus: BookingStatus.unconfirmed,
        cost: 1850.0,
        notes:
            'Overnight journey. Arrival provisionally represented on 11 Dec. Schedule from notes.',
      ),
      TravelTransport(
        id: uuid.v4(),
        tripId: tripId,
        type: TransportType.bus,
        provider: 'Siliguri North Bengal Transport',
        departurePlace: 'Tenzing Norgay Central Bus Terminus, Siliguri',
        arrivalPlace: 'Darjeeling Bus Stand',
        departureTime: DateTime(2026, 12, 11, 6, 30),
        arrivalTime: DateTime(2026, 12, 11, 10, 15),
        bookingStatus: BookingStatus.unconfirmed,
        cost: 250.0,
        notes: 'Transfer from NJP to bus terminus requires travel-time confirmation.',
      ),
      TravelTransport(
        id: uuid.v4(),
        tripId: tripId,
        type: TransportType.scooty,
        provider: 'Darjeeling Scooty Rental',
        departurePlace: 'Darjeeling Mall Road Hub',
        arrivalPlace: 'Live In Nature Homestay & Sightseeing',
        departureTime: DateTime(2026, 12, 11, 11, 0),
        arrivalTime: DateTime(2026, 12, 18, 10, 0),
        bookingStatus: BookingStatus.unconfirmed,
        cost: 5600.0,
        notes: 'Subject to mountain availability and weather suitability.',
      ),
    ];

    // Accommodations
    final accommodations = <TravelAccommodation>[
      TravelAccommodation(
        id: uuid.v4(),
        tripId: tripId,
        propertyName: 'Live In Nature homestay',
        address: 'Upper Tukvar / Lebong Ridge, Darjeeling',
        checkIn: DateTime(2026, 12, 11, 12, 0),
        checkOut: DateTime(2026, 12, 18, 10, 0),
        bookingStatus: AccommodationStatus.savedPreference,
        cost: 8400.0,
        notes:
            'Preferred accommodation from later notes. Unconfirmed preference; not a booked reservation.',
      ),
    ];

    // Checklist
    final checklist = <TravelChecklistItem>[
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.documents,
        item: 'Government Photo ID (Aadhaar / Voter ID)',
        isCompleted: true,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.documents,
        item: 'Driving License for rented scooty',
        isCompleted: false,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.transport,
        item: 'Verify MAS NJP SF Express PNR & berth',
        isCompleted: false,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.accommodation,
        item: 'Call Live In Nature homestay for room confirmation',
        isCompleted: false,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.clothing,
        item: 'Heavy thermal innerwear & windproof mountain jacket',
        isCompleted: true,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.clothing,
        item: 'Woolen gloves, beanie & trekking boots',
        isCompleted: false,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.electronics,
        item: 'High-capacity power bank & camera batteries (cold drainage)',
        isCompleted: true,
      ),
      TravelChecklistItem(
        id: uuid.v4(),
        tripId: tripId,
        category: ChecklistCategory.toiletries,
        item: 'Moisturizer, lip balm, and personal medication',
        isCompleted: false,
      ),
    ];

    return DarjeelingTripDataPackage(
      trip: trip,
      days: days,
      activities: activities,
      savedPlaces: savedPlaces,
      transports: transports,
      accommodations: accommodations,
      checklist: checklist,
    );
  }
}
