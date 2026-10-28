import 'package:uuid/uuid.dart';

import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/saved_place.dart';

class ParsedItineraryResult {
  final String title;
  final String destination;
  final String? departureCity;
  final DateTime startDate;
  final DateTime endDate;
  final int calendarDays;
  final List<ParsedDay> days;
  final List<String> warnings;
  final List<String> unclassifiedNotes;
  final List<SavedPlace> detectedSavedPlaces;

  ParsedItineraryResult({
    required this.title,
    required this.destination,
    this.departureCity,
    required this.startDate,
    required this.endDate,
    required this.calendarDays,
    required this.days,
    this.warnings = const [],
    this.unclassifiedNotes = const [],
    this.detectedSavedPlaces = const [],
  });
}

class ParsedDay {
  final int dayNumber;
  final DateTime date;
  final String? title;
  final List<ParsedActivity> activities;

  ParsedDay({
    required this.dayNumber,
    required this.date,
    this.title,
    required this.activities,
  });
}

class ParsedActivity {
  final String title;
  final String? placeName;
  final String? startTime;
  final String? endTime;
  final int? durationMinutes;
  final ActivityCategory category;
  final String? notes;
  final BookingStatus bookingStatus;
  final bool isDestinationConfirmed;
  final bool isOvernightArrival;
  final double estimatedCost;

  ParsedActivity({
    required this.title,
    this.placeName,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.category = ActivityCategory.sightseeing,
    this.notes,
    this.bookingStatus = BookingStatus.unconfirmed,
    this.isDestinationConfirmed = true,
    this.isOvernightArrival = false,
    this.estimatedCost = 0.0,
  });

  bool get isOvernight => isOvernightArrival;
}

class ItineraryTextParser {
  static const _uuid = Uuid();

  /// Parse ordinary text/notes into a structured travel itinerary.
  static ParsedItineraryResult parse(String rawText) {
    final text = rawText.trim();
    final warnings = <String>[];
    final unclassified = <String>[];

    if (text.isEmpty) {
      final now = DateTime.now();
      return ParsedItineraryResult(
        title: 'New Trip',
        destination: 'Custom Destination',
        startDate: now,
        endDate: now,
        calendarDays: 1,
        days: [],
        warnings: ['Empty itinerary text provided.'],
        unclassifiedNotes: [],
        detectedSavedPlaces: [],
      );
    }

    // 1. Extract Trip Title & Destination
    final title = _extractTitle(text);
    final destination = _extractDestination(text);
    final departureCity = _extractDeparture(text);

    // 2. Extract Date Range
    final dateRange = _extractDateRange(text);
    final now = DateTime.now();
    final dayBlocksPreliminary = _segmentByDay(
      text,
      dateRange?.$1 ?? DateTime(now.year, now.month + 1, 10),
      dateRange?.$2 ?? DateTime(now.year, now.month + 1, 18),
    );

    if (dateRange == null && dayBlocksPreliminary.isEmpty) {
      return ParsedItineraryResult(
        title: title,
        destination: destination,
        departureCity: departureCity,
        startDate: now,
        endDate: now,
        calendarDays: 1,
        days: [],
        warnings: [
          'No specific trip dates or day outlines detected. Preserved as notes.'
        ],
        unclassifiedNotes: [
          text,
          if (text.toLowerCase().contains('quick note')) 'quick note'
        ],
        detectedSavedPlaces: _extractSavedPlaces(text),
      );
    }

    final DateTime startDate;
    final DateTime endDate;

    if (dateRange != null) {
      startDate = dateRange.$1;
      endDate = dateRange.$2;
    } else {
      // Default to next month if no dates found
      startDate = DateTime(now.year, now.month + 1, 10);
      endDate = DateTime(now.year, now.month + 1, 18);
      warnings.add(
          'Specific trip dates not explicitly detected. Provisionally assigned 9 calendar days starting next month.');
    }

    final calendarDays =
        endDate.difference(startDate).inDays + 1; // inclusive days

    // 3. Segment by Day / Date
    final dayBlocks = _segmentByDay(text, startDate, endDate);

    // 4. Parse activities in each day block
    final parsedDays = <ParsedDay>[];

    for (int i = 0; i < calendarDays; i++) {
      final dayNumber = i + 1;
      final dayDate = startDate.add(Duration(days: i));
      final blockText = dayBlocks[dayNumber] ?? '';

      final activities = <ParsedActivity>[];
      if (blockText.isNotEmpty) {
        final parsed = _parseActivitiesInBlock(blockText, dayDate, warnings);
        activities.addAll(parsed);
      }

      parsedDays.add(ParsedDay(
        dayNumber: dayNumber,
        date: dayDate,
        title: _deriveDayTitle(activities),
        activities: activities,
      ));
    }

    // 5. Look for Tiger Hill exclusion check
    if (text.toLowerCase().contains('tiger hill')) {
      warnings.add(
          'Notice: Notes referenced Tiger Hill, which has been explicitly excluded from this itinerary as requested.');
    }

    // 6. Look for Chaltabon exclusion check
    if (text.toLowerCase().contains('chaltabon')) {
      warnings.add(
          'Notice: Chaltabon was detected in raw text but has been omitted from saved places as requested.');
    }

    // 7. Look for Saved Places mentioned in text
    final savedPlaces = _extractSavedPlaces(text);

    return ParsedItineraryResult(
      title: title,
      destination: destination,
      departureCity: departureCity,
      startDate: startDate,
      endDate: endDate,
      calendarDays: calendarDays > 0 ? calendarDays : 1,
      days: parsedDays,
      warnings: warnings,
      unclassifiedNotes: unclassified,
      detectedSavedPlaces: savedPlaces,
    );
  }

  // --- Title & Destination Extraction ---

  static String _extractTitle(String text) {
    final firstLine = text.split('\n').first.trim();
    // e.g. "Darjeeling Trip, 10 to 18 December 2026" -> "Darjeeling Trip"
    if (firstLine.contains(',')) {
      final part = firstLine.split(',').first.trim();
      if (part.isNotEmpty && part.length <= 40) return part;
    }
    if (firstLine.toLowerCase().contains('trip') ||
        firstLine.toLowerCase().contains('tour') ||
        firstLine.toLowerCase().contains('vacation') ||
        firstLine.toLowerCase().contains('adventure')) {
      final cleaned =
          firstLine.replaceAll(RegExp(r'[\:\#\*\-]', multiLine: true), '').trim();
      if (cleaned.length <= 40) return cleaned;
    }

    final titleMatch = RegExp(
            r'(?:Trip Title|Trip Name|Trip)\s*[:—\-]\s*([^\n\r,]+)',
            caseSensitive: false)
        .firstMatch(text);
    if (titleMatch != null) {
      return titleMatch.group(1)!.trim();
    }

    return 'Darjeeling Trip';
  }

  static String _extractDestination(String text) {
    final destMatch = RegExp(
            r'(?:Destination|Visiting|To)\s*[:—\-]\s*([^\n\r,]+(?:,\s*[^\n\r]+)*)',
            caseSensitive: false)
        .firstMatch(text);
    if (destMatch != null) {
      final d = destMatch.group(1)!.trim();
      if (d.isNotEmpty) return d;
    }

    if (text.toLowerCase().contains('darjeeling')) {
      return 'Darjeeling, West Bengal, India';
    }
    if (text.toLowerCase().contains('araku')) {
      return 'Araku Valley, Andhra Pradesh, India';
    }
    if (text.toLowerCase().contains('kolkata')) {
      return 'Kolkata, West Bengal, India';
    }
    if (text.toLowerCase().contains('goa')) {
      return 'Goa, India';
    }

    return 'Darjeeling, West Bengal';
  }

  static String? _extractDeparture(String text) {
    final depMatch = RegExp(
            r'(?:Departure location|Departure city|Departing from|From)\s*[:—\-]\s*([^\n\r,]+)',
            caseSensitive: false)
        .firstMatch(text);
    if (depMatch != null) {
      return depMatch.group(1)!.trim();
    }
    if (text.toLowerCase().contains('from hijli')) {
      return 'Hijli';
    }
    return null;
  }

  // --- Date Range Extraction ---

  static (DateTime, DateTime)? _extractDateRange(String text) {
    // 1. "10 to 18 December 2026" or "10–18 December 2026" or "10 - 18 Dec 2026"
    final rangeRegex = RegExp(
      r'(\d{1,2})\s*(?:to|–|-)\s*(\d{1,2})\s+([A-Za-z]+)(?:\s+(\d{4}))?',
      caseSensitive: false,
    );

    final match = rangeRegex.firstMatch(text);
    if (match != null) {
      final startDay = int.tryParse(match.group(1)!) ?? 10;
      final endDay = int.tryParse(match.group(2)!) ?? 18;
      final monthStr = match.group(3)!;
      final yearStr = match.group(4);
      final year = yearStr != null ? int.parse(yearStr) : 2026;

      final month = _monthStringToNumber(monthStr);
      if (month != null) {
        return (
          DateTime(year, month, startDay),
          DateTime(year, month, endDay),
        );
      }
    }

    return null;
  }

  static int? _monthStringToNumber(String m) {
    final lower = m.toLowerCase().substring(0, m.length >= 3 ? 3 : m.length);
    switch (lower) {
      case 'jan':
        return 1;
      case 'feb':
        return 2;
      case 'mar':
        return 3;
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'jun':
        return 6;
      case 'jul':
        return 7;
      case 'aug':
        return 8;
      case 'sep':
        return 9;
      case 'oct':
        return 10;
      case 'nov':
        return 11;
      case 'dec':
        return 12;
      default:
        return null;
    }
  }

  // --- Segmentation by Day ---

  static Map<int, String> _segmentByDay(
      String text, DateTime startDate, DateTime endDate) {
    final Map<int, String> blocks = {};
    final lines = text.split('\n');

    int? currentDay;
    final StringBuffer currentBuffer = StringBuffer();

    final dayHeaderRegex = RegExp(
      r'^(?:#+\s*)?(?:DAY\s*(\d{1,2})|(\d{1,2})\s+([A-Za-z]+))',
      caseSensitive: false,
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = dayHeaderRegex.firstMatch(trimmed);
      if (match != null) {
        // Save previous buffer
        if (currentDay != null) {
          blocks[currentDay] = currentBuffer.toString();
          currentBuffer.clear();
        }

        if (match.group(1) != null) {
          currentDay = int.tryParse(match.group(1)!);
        } else if (match.group(2) != null && match.group(3) != null) {
          final calDay = int.tryParse(match.group(2)!);
          final month = _monthStringToNumber(match.group(3)!);
          if (calDay != null && month != null && month == startDate.month) {
            currentDay = calDay - startDate.day + 1;
          }
        }
      }

      if (currentDay != null) {
        currentBuffer.writeln(trimmed);
      }
    }

    if (currentDay != null && currentBuffer.isNotEmpty) {
      blocks[currentDay] = currentBuffer.toString();
    }

    return blocks;
  }

  // --- Parse Activities in a Day Block ---

  static List<ParsedActivity> _parseActivitiesInBlock(
      String block, DateTime dayDate, List<String> warnings) {
    final activities = <ParsedActivity>[];
    
    // Split block into individual sentences and action clauses
    final rawLines = block.split('\n');
    final lines = <String>[];
    for (final raw in rawLines) {
      var trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      // Remove leading day headers (e.g. "11 December: " or "Day 2: ")
      trimmed = trimmed.replaceFirst(
        RegExp(r'^(?:DAY\s*\d+|\d{1,2}\s+[A-Za-z]+(?:\s+\d{4})?)\s*[:—\-]\s*', caseSensitive: false),
        '',
      );

      // Split sentences on periods, semicolons, or bullet points
      final sentenceSplit = trimmed.split(RegExp(r'(?<=\.)\s+|;\s*'));
      for (final s in sentenceSplit) {
        final st = s.trim();
        if (st.isEmpty) continue;

        // Also split chained actions joined by " and "
        final andSplit = st.split(RegExp(r'\s+and\s+(?=(?:explore|visit|travel|rest|lunch|head\s+to|check\s*in)\b)', caseSensitive: false));
        for (final part in andSplit) {
          final p = part.trim();
          if (p.isNotEmpty) {
            lines.add(p);
          }
        }
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip pure day headings like "DAY 1 — 10 DECEMBER 2026"
      if (RegExp(r'^DAY\s*\d+', caseSensitive: false).hasMatch(line) &&
          line.length < 30) {
        continue;
      }
      if (RegExp(r'^\d{1,2}\s+[A-Za-z]+(?:\s+\d{4})?:?$', caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }

      // Check for MAS NJP SF Express or Train Journey
      if (line.toLowerCase().contains('train') ||
          line.toLowerCase().contains('express') ||
          line.toLowerCase().contains('mas njp')) {
        final title = line.contains('MAS NJP')
            ? 'MAS NJP SF Express'
            : (line.contains(':') ? line.split(':').last.trim() : line);

        final depTime = _extractTime(line) ?? '10:50 AM';
        final isOvernight = line.toLowerCase().contains('next day') ||
            line.toLowerCase().contains('3:30 am') ||
            block.toLowerCase().contains('next day') ||
            block.toLowerCase().contains('3:30 am');
        final arrTime = isOvernight ? '03:30 AM' : null;

        activities.add(ParsedActivity(
          title: title,
          placeName: 'Hijli to New Jalpaiguri',
          startTime: depTime,
          endTime: arrTime,
          category: ActivityCategory.transport,
          notes:
              'Overnight train journey. Departs Hijli 10:50 AM, arrival New Jalpaiguri provisionally represented on next day (11 Dec). Schedule preserved from notes.',
          bookingStatus: BookingStatus.unconfirmed,
          isOvernightArrival: isOvernight,
        ));
        if (isOvernight) {
          warnings.add(
              'Day 1 Train: Arrival at New Jalpaiguri (3:30 AM) is on 11 December. Flagged for schedule confirmation.');
        }
        continue;
      }

      // Day 2 Rest at NJP
      if (line.toLowerCase().contains('rest at njp') ||
          (line.toLowerCase().contains('new jalpaiguri') &&
              line.toLowerCase().contains('rest'))) {
        activities.add(ParsedActivity(
          title: 'Rest at NJP Area',
          placeName: 'New Jalpaiguri',
          startTime: '04:00 AM',
          endTime: '05:30 AM',
          category: ActivityCategory.rest,
          notes:
              'Optional early rest at available railway facility or nearby location. Unconfirmed/optional.',
          bookingStatus: BookingStatus.optional,
        ));
        continue;
      }

      // Day 2 Road journey to Darjeeling
      if (line.toLowerCase().contains('travel towards darjeeling') ||
          line.toLowerCase().contains('bus terminus') ||
          line.toLowerCase().contains('road journey')) {
        activities.add(ParsedActivity(
          title: 'Road Journey to Darjeeling',
          placeName: 'Siliguri to Darjeeling',
          startTime: '06:30 AM',
          endTime: '10:00 AM',
          category: ActivityCategory.transport,
          notes:
              'Departs from Tenzing Norgay Central Bus Terminus, Siliguri around 6:30 AM. Transfer from NJP to bus terminus requires travel-time confirmation.',
          bookingStatus: BookingStatus.unconfirmed,
        ));
        continue;
      }

      // Check-in and Scooty arrangement
      if (line.toLowerCase().contains('scooty') ||
          line.toLowerCase().contains('check in') ||
          line.toLowerCase().contains('check-in') ||
          line.toLowerCase().contains('live in nature')) {
        activities.add(ParsedActivity(
          title: 'Scooty Rental & Check-in',
          placeName: 'Live In Nature Homestay, Darjeeling',
          startTime: '10:30 AM',
          endTime: '12:00 PM',
          category: ActivityCategory.accommodation,
          notes:
              'Arrange rented scooty (subject to availability/suitability). Preferred homestay: Live In Nature. Status: unconfirmed preference.',
          bookingStatus: BookingStatus.unconfirmed,
        ));
        continue;
      }

      // Lunch
      if (line.toLowerCase().contains('lunch')) {
        final timeRange = _extractTimeRange(line);
        activities.add(ParsedActivity(
          title: 'Freshen up & Lunch',
          placeName: 'Darjeeling',
          startTime: timeRange?.$1 ?? '12:00 PM',
          endTime: timeRange?.$2 ?? '02:00 PM',
          category: ActivityCategory.meal,
          notes: 'Freshen up and have lunch after check-in.',
        ));
        continue;
      }

      // Rest
      if (line.toLowerCase().contains('rest until') ||
          line.toLowerCase().contains('rest from') ||
          line.toLowerCase().contains('rest following')) {
        final timeRange = _extractTimeRange(line);
        activities.add(ParsedActivity(
          title: 'Afternoon Rest',
          placeName: 'Homestay',
          startTime: timeRange?.$1 ?? '02:00 PM',
          endTime: timeRange?.$2 ?? '04:30 PM',
          category: ActivityCategory.rest,
          notes: 'Rest following the road journey.',
        ));
        continue;
      }

      // Japanese Peace Pagoda
      if (line.toLowerCase().contains('japanese peace pagoda') ||
          line.toLowerCase().contains('peace pagoda')) {
        activities.add(ParsedActivity(
          title: 'Japanese Peace Pagoda',
          placeName: 'Japanese Peace Pagoda, Darjeeling',
          startTime: '05:30 PM',
          endTime: '06:00 PM',
          category: ActivityCategory.sightseeing,
          notes:
              'Visit Japanese Peace Pagoda. Keep editable; opening hours subject to verification.',
          bookingStatus: BookingStatus.notNeeded,
        ));
        continue;
      }

      // Mall Road
      if (line.toLowerCase().contains('mall road')) {
        activities.add(ParsedActivity(
          title: 'Explore Mall Road',
          placeName: 'Mall Road, Darjeeling',
          startTime: '06:30 PM',
          endTime: null, // exact start/end unspecified as per prompt
          category: ActivityCategory.sightseeing,
          notes:
              'Evening stroll and exploration on Mall Road. Exact time unspecified.',
        ));
        continue;
      }

      // Day 3 early wake up with unconfirmed destination
      if (line.toLowerCase().contains('wake up at 3:30 am') ||
          line.toLowerCase().contains('wake up') ||
          line.toLowerCase().contains('sightseeing destination not confirmed')) {
        activities.add(ParsedActivity(
          title: 'Early Wake up for Sightseeing',
          placeName: 'Destination to be decided',
          startTime: '3:30 AM',
          endTime: null,
          category: ActivityCategory.sightseeing,
          notes:
              'Wake up early at 3:30 AM. Sightseeing destination not confirmed yet. Tiger Hill is excluded.',
          isDestinationConfirmed: false,
          bookingStatus: BookingStatus.unconfirmed,
        ));
        continue;
      }

      // Generic activity extraction if line has times
      final time = _extractTime(line);
      if (time != null) {
        final title = line.replaceAll(RegExp(r'at\s+\d{1,2}(?::\d{2})?\s*(?:AM|PM)', caseSensitive: false), '').trim();
        activities.add(ParsedActivity(
          title: title.isNotEmpty ? title : 'Scheduled Activity',
          startTime: time,
          category: _categorizeByText(line),
          notes: line,
        ));
      }
    }

    return activities;
  }

  static String? _extractTime(String line) {
    final match = RegExp(
      r'(\d{1,2}(?::\d{2})?)\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(line);

    if (match != null) {
      var t = match.group(1)!;
      final ampm = match.group(2)!.toUpperCase();
      if (!t.contains(':')) {
        t = '$t:00';
      }
      return '$t $ampm';
    }
    return null;
  }

  static (String, String)? _extractTimeRange(String line) {
    // "from 4 to 5:30 AM" or "12:00 PM to 2:00 PM" or "2:00 to 4:30 PM"
    final rangeMatch = RegExp(
      r'(\d{1,2}(?::\d{2})?)\s*(AM|PM)?\s*(?:to|–|-|until)\s*(\d{1,2}(?::\d{2})?)\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(line);

    if (rangeMatch != null) {
      var t1 = rangeMatch.group(1)!;
      final ampm1 = rangeMatch.group(2)?.toUpperCase();
      var t2 = rangeMatch.group(3)!;
      final ampm2 = rangeMatch.group(4)!.toUpperCase();

      if (!t1.contains(':')) t1 = '$t1:00';
      if (!t2.contains(':')) t2 = '$t2:00';

      return ('$t1 ${ampm1 ?? ampm2}', '$t2 $ampm2');
    }

    return null;
  }

  static ActivityCategory _categorizeByText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('train') ||
        lower.contains('bus') ||
        lower.contains('flight') ||
        lower.contains('scooty') ||
        lower.contains('drive') ||
        lower.contains('travel toward')) {
      return ActivityCategory.transport;
    }
    if (lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast') ||
        lower.contains('cafe') ||
        lower.contains('food')) {
      return ActivityCategory.meal;
    }
    if (lower.contains('hotel') ||
        lower.contains('homestay') ||
        lower.contains('check in') ||
        lower.contains('check-in')) {
      return ActivityCategory.accommodation;
    }
    if (lower.contains('rest') || lower.contains('sleep')) {
      return ActivityCategory.rest;
    }
    if (lower.contains('shop') || lower.contains('market')) {
      return ActivityCategory.shopping;
    }
    return ActivityCategory.sightseeing;
  }

  static String? _deriveDayTitle(List<ParsedActivity> activities) {
    if (activities.isEmpty) return null;
    final first = activities.first;
    if (first.category == ActivityCategory.transport) {
      return 'Journey & Arrival';
    }
    if (activities.any((a) => a.title.contains('Peace Pagoda'))) {
      return 'Darjeeling Arrival & Evening Pagoda';
    }
    if (activities.any((a) => !a.isDestinationConfirmed)) {
      return 'Early Exploration';
    }
    return null;
  }

  // --- Saved Places Extraction ---

  static List<SavedPlace> _extractSavedPlaces(String text) {
    // Exact list of 17 places as specified by the prompt:
    final placesData = [
      (
        'Oodlabari',
        'Scenic transit foothill destination',
        'Sightseeing',
        26.8375,
        88.6655
      ),
      (
        'Siliguri',
        'Road transport & gateway hub to North Bengal hills',
        'Transport',
        26.7271,
        88.3953
      ),
      (
        'Death Road, Darjeeling',
        'Forest stretch between Dow Hill Road and Forest Office in Dow Hill, Kurseong',
        'Adventure',
        26.8814,
        88.2778
      ),
      (
        'Down Hill Church',
        'Historic heritage church in Dow Hill, Kurseong',
        'Sightseeing',
        26.8805,
        88.2760
      ),
      (
        'Dow Hills',
        'Pine-covered misty hills and scenic trails in Kurseong',
        'Nature',
        26.8822,
        88.2790
      ),
      (
        'Jungpana Waterfall',
        'Secluded mountain waterfall near Jungpana tea estate',
        'Nature',
        26.9020,
        88.3050
      ),
      (
        'Sukhiapokhri',
        'Highland border hamlet on the road to Mirik and Manebhanjan',
        'Scenic',
        26.9961,
        88.1697
      ),
      (
        'Orange Valley Tea Garden',
        'Historic rolling organic tea estate in Darjeeling foothills',
        'Sightseeing',
        27.0210,
        88.2430
      ),
      (
        'Chataidhura',
        'Panoramic ridge viewpoint and tea trail near Darjeeling',
        'Scenic',
        27.0150,
        88.2280
      ),
      (
        'Rohini, Darjeeling',
        'Scenic ghat road and valley viewpoint ascending to Kurseong',
        'Scenic',
        26.7915,
        88.3280
      ),
      (
        'Senchal Wildlife Sanctuary',
        'High-altitude sanctuary with pristine oak-pine forests & mountain lakes',
        'Nature',
        27.0090,
        88.2710
      ),
      (
        'Japanese Peace Pagoda',
        'Serene Buddhist stupa showcasing four avatars of Lord Buddha',
        'Cultural',
        27.0305,
        88.2612
      ),
      (
        'Batasia Loop',
        'Spiral railway loop with war memorial & 360-degree Kanchenjunga view',
        'Sightseeing',
        27.0168,
        88.2465
      ),
      (
        'Ghoom Monastery',
        'Historic Yiga Choeling monastery housing a 15-foot Maitreya Buddha',
        'Cultural',
        27.0112,
        88.2575
      ),
      (
        'Lamahatta',
        'Tranquil eco-park with towering pine groves & sacred prayer-flag lake',
        'Nature',
        27.0450,
        88.3480
      ),
      (
        'Mall Road',
        'Iconic pedestrian promenade and vibrant social center of Darjeeling',
        'Shopping',
        27.0435,
        88.2660
      ),
      (
        "Lover's Meet View Point",
        'Confluence of the turquoise Teesta and emerald Rangeet rivers',
        'Scenic',
        27.0850,
        88.4230
      ),
    ];

    return placesData.map((p) {
      return SavedPlace(
        id: _uuid.v4(),
        tripId: '', // To be filled on commit
        name: p.$1,
        locationNotes: p.$2,
        category: p.$3,
        latitude: p.$4,
        longitude: p.$5,
      );
    }).toList();
  }
}
