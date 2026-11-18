import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/itinerary_activity.dart';
import 'package:royal_spend/data/models/travel_accommodation.dart';
import 'package:royal_spend/data/models/travel_transport.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/widgets/travel/add_edit_stay_sheet.dart';
import 'package:royal_spend/ui/widgets/travel/add_edit_transport_sheet.dart';
import 'package:royal_spend/ui/widgets/travel/transport_accommodation_view.dart';
import 'travel_multi_plan_isolation_test.dart';

void main() {
  group('Travel Details - Transports & Stays Edit, Timings & Deletion Tests', () {
    late MockTravelRepository mockRepo;
    late TravelProvider travelProvider;

    final trip = Trip(
      id: 'trip-himalayas-01',
      title: 'Himalayan Expedition',
      destination: 'Darjeeling & Gangtok',
      departureCity: 'Kolkata',
      startDate: DateTime(2026, 12, 10),
      endDate: DateTime(2026, 12, 18),
      budget: 35000,
      status: TripStatus.upcoming,
    );

    final initialTransport = TravelTransport(
      id: 'trans-01',
      tripId: trip.id,
      type: TransportType.flight,
      provider: 'IndiGo 6E-204',
      departurePlace: 'CCU Kolkata Terminal 1',
      arrivalPlace: 'IXB Bagdogra Airport',
      departureTime: DateTime(2026, 12, 10, 8, 30),
      arrivalTime: DateTime(2026, 12, 10, 9, 45),
      bookingReference: '6E-PNR-8924',
      bookingStatus: BookingStatus.booked,
      cost: 4200.0,
      notes: 'Check-in 2 hours prior with valid photo ID',
    );

    final initialStay = TravelAccommodation(
      id: 'stay-01',
      tripId: trip.id,
      propertyName: 'Cedar Inn Heritage Resort',
      address: 'Jalapahar Road, Darjeeling',
      checkIn: DateTime(2026, 12, 10, 14, 0),
      checkOut: DateTime(2026, 12, 14, 11, 0),
      bookingStatus: AccommodationStatus.booked,
      bookingReference: 'BOOKING-99482',
      contactInfo: '+91 354 225 4446',
      cost: 16000.0,
      notes: 'Kanchenjunga view deluxe suite booked',
    );

    setUp(() async {
      mockRepo = MockTravelRepository();
      mockRepo.trips.add(trip);
      mockRepo.transports.add(initialTransport);
      mockRepo.accommodations.add(initialStay);

      travelProvider = TravelProvider(repository: mockRepo);
      await travelProvider.initialize();
      await travelProvider.selectTrip(trip.id);
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: travelProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: TransportAccommodationView(isDark: false),
          ),
        ),
      );
    }

    testWidgets('Renders Transport & Accommodation cards with timing and rich details',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check Transport card details
      expect(find.text('IndiGo 6E-204'), findsOneWidget);
      expect(find.text('CCU Kolkata Terminal 1'), findsOneWidget);
      expect(find.text('IXB Bagdogra Airport'), findsOneWidget);
      expect(find.text('PNR / Ref: 6E-PNR-8924'), findsOneWidget);
      expect(find.text('Fare: ₹4,200'), findsOneWidget);
      expect(find.text('1h 15m'), findsOneWidget); // Duration

      // Check Stay card details
      expect(find.text('Cedar Inn Heritage Resort'), findsOneWidget);
      expect(find.text('Jalapahar Road, Darjeeling'), findsOneWidget);
      expect(find.text('4 Nights'), findsOneWidget); // 10 Dec to 14 Dec
      expect(find.text('Ref: BOOKING-99482'), findsOneWidget);
      expect(find.text('+91 354 225 4446'), findsOneWidget);
      expect(find.text('Rate: ₹16,000'), findsOneWidget);
    });

    testWidgets('Tapping Edit on Transport opens AddEditTransportSheet in edit mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Edit button on Transport card
      final editButtons = find.text('Edit');
      expect(editButtons, findsNWidgets(2)); // 1 for transport, 1 for stay
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Verify AddEditTransportSheet modal is open in edit mode
      expect(find.byType(AddEditTransportSheet), findsOneWidget);
      expect(find.text('Edit Transport'), findsOneWidget);
      expect(find.text('Update Transport'), findsOneWidget);
      expect(find.text('CCU Kolkata Terminal 1'), findsWidgets);
      expect(find.text('IXB Bagdogra Airport'), findsWidgets);
      expect(find.text('6E-PNR-8924'), findsWidgets);
    });

    testWidgets('Updating Transport timing and provider updates provider and repo',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open Edit Sheet for Transport
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();

      // Update provider name
      final providerFinder = find.widgetWithText(TextFormField, 'IndiGo 6E-204');
      await tester.enterText(providerFinder, 'SpiceJet SG-102');
      await tester.pumpAndSettle();

      // Tap Update Transport
      await tester.tap(find.text('Update Transport'));
      await tester.pumpAndSettle();

      // Modal closed and UI updated
      expect(find.byType(AddEditTransportSheet), findsNothing);
      expect(find.text('SpiceJet SG-102'), findsOneWidget);
      expect(travelProvider.currentTransports.first.provider, 'SpiceJet SG-102');
    });

    testWidgets('Tapping Delete on Transport prompts confirmation dialog and cancels cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Delete on Transport card
      final deleteButtons = find.text('Delete');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Cupertino confirmation dialog should be displayed
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Delete Transport Connection?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Transport was NOT deleted
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(travelProvider.currentTransports.length, 1);
    });

    testWidgets('Confirming Delete on Transport removes record from list and repository',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Delete on Transport card
      final deleteButtons = find.text('Delete');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Tap Delete in dialog
      final dialogDeleteButton = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Delete'),
      );
      await tester.tap(dialogDeleteButton);
      await tester.pumpAndSettle();

      // Transport is deleted
      expect(travelProvider.currentTransports.isEmpty, isTrue);
      expect(mockRepo.transports.isEmpty, isTrue);
    });

    testWidgets('Tapping Edit on Accommodation opens AddEditStaySheet and updates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Edit button on Stay card (second Edit button)
      final editButtons = find.text('Edit');
      await tester.tap(editButtons.last);
      await tester.pumpAndSettle();

      // Verify AddEditStaySheet modal is open
      expect(find.byType(AddEditStaySheet), findsOneWidget);
      expect(find.text('Edit Accommodation'), findsOneWidget);
      expect(find.text('Update Accommodation'), findsOneWidget);
      expect(find.text('Cedar Inn Heritage Resort'), findsWidgets);

      // Change property name
      final nameFinder =
          find.widgetWithText(TextFormField, 'Cedar Inn Heritage Resort');
      await tester.enterText(nameFinder, 'Windamere Hotel Heritage');
      await tester.pumpAndSettle();

      // Tap Update Accommodation
      await tester.tap(find.text('Update Accommodation'));
      await tester.pumpAndSettle();

      // Modal closed and UI updated
      expect(find.byType(AddEditStaySheet), findsNothing);
      expect(find.text('Windamere Hotel Heritage'), findsOneWidget);
      expect(travelProvider.currentAccommodations.first.propertyName,
          'Windamere Hotel Heritage');
    });

    testWidgets('Confirming Delete on Accommodation removes record with confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Delete on Stay card
      final deleteButtons = find.text('Delete');
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Delete Accommodation?'), findsOneWidget);

      // Confirm delete
      final dialogDeleteButton = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Delete'),
      );
      await tester.tap(dialogDeleteButton);
      await tester.pumpAndSettle();

      // Accommodation deleted
      expect(travelProvider.currentAccommodations.isEmpty, isTrue);
      expect(mockRepo.accommodations.isEmpty, isTrue);
    });
  });
}
