import 'dart:convert';
import 'package:flutter/cupertino.dart';

enum TripStatus {
  upcoming,
  inProgress,
  draft,
  completed,
  archived;

  String get displayName {
    switch (this) {
      case TripStatus.upcoming:
        return 'Upcoming';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.draft:
        return 'Draft';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.archived:
        return 'Archived';
    }
  }

  Color get badgeColor {
    switch (this) {
      case TripStatus.upcoming:
        return const Color(0xFF0A84FF); // Apple Blue
      case TripStatus.inProgress:
        return const Color(0xFF30D158); // Apple Green
      case TripStatus.draft:
        return const Color(0xFFFF9F0A); // Apple Orange
      case TripStatus.completed:
        return const Color(0xFF8E8E93); // Apple Gray
      case TripStatus.archived:
        return const Color(0xFF636366);
    }
  }

  IconData get icon {
    switch (this) {
      case TripStatus.upcoming:
        return CupertinoIcons.calendar_today;
      case TripStatus.inProgress:
        return CupertinoIcons.airplane;
      case TripStatus.draft:
        return CupertinoIcons.pencil_circle;
      case TripStatus.completed:
        return CupertinoIcons.checkmark_seal_fill;
      case TripStatus.archived:
        return CupertinoIcons.archivebox_fill;
    }
  }
}

class Trip {
  final String id;
  final String title;
  final String destination;
  final List<String> additionalDestinations;
  final String? departureCity;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final int travelersCount;
  final List<String> travelersNames;
  final double budget;
  final double transportBudget;
  final double accommodationBudget;
  final double foodBudget;
  final double sightseeingBudget;
  final double shoppingBudget;
  final double otherBudget;
  final String? description;
  final String? coverImage;
  final List<String> preferences;
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.title,
    required this.destination,
    this.additionalDestinations = const [],
    this.departureCity,
    required this.startDate,
    required this.endDate,
    this.currency = 'INR',
    this.travelersCount = 1,
    this.travelersNames = const ['You'],
    this.budget = 0.0,
    this.transportBudget = 0.0,
    this.accommodationBudget = 0.0,
    this.foodBudget = 0.0,
    this.sightseeingBudget = 0.0,
    this.shoppingBudget = 0.0,
    this.otherBudget = 0.0,
    this.description,
    this.coverImage,
    this.preferences = const [],
    this.status = TripStatus.upcoming,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calculates the inclusive calendar days count.
  /// E.g. Dec 10 to Dec 18 = 9 calendar days.
  int get calendarDaysCount {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) return 1;
    return end.difference(start).inDays + 1;
  }

  String get durationString =>
      '$calendarDaysCount ${calendarDaysCount == 1 ? "day" : "days"}';

  static const List<String> _monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  String get formattedDateRange {
    final startMonth = _monthNames[startDate.month];
    final endMonth = _monthNames[endDate.month];
    if (startDate.year == endDate.year) {
      if (startDate.month == endDate.month) {
        return '$startMonth ${startDate.day} - ${endDate.day}, ${startDate.year}';
      }
      return '$startMonth ${startDate.day} - $endMonth ${endDate.day}, ${startDate.year}';
    }
    return '$startMonth ${startDate.day}, ${startDate.year} - $endMonth ${endDate.day}, ${endDate.year}';
  }

  /// Calculates remaining days until departure or elapsed days if started.
  int get daysUntilTrip {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return start.difference(today).inDays;
  }

  /// Returns true if today falls within trip startDate and endDate (inclusive).
  bool get isActiveNow {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  /// Current day number (1-based) if currently on trip.
  int? get currentTripDayNumber {
    if (!isActiveNow) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays + 1;
  }

  Trip copyWith({
    String? id,
    String? title,
    String? destination,
    List<String>? additionalDestinations,
    String? departureCity,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    int? travelersCount,
    List<String>? travelersNames,
    double? budget,
    double? transportBudget,
    double? accommodationBudget,
    double? foodBudget,
    double? sightseeingBudget,
    double? shoppingBudget,
    double? otherBudget,
    String? description,
    String? coverImage,
    List<String>? preferences,
    TripStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      additionalDestinations:
          additionalDestinations ?? this.additionalDestinations,
      departureCity: departureCity ?? this.departureCity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currency: currency ?? this.currency,
      travelersCount: travelersCount ?? this.travelersCount,
      travelersNames: travelersNames ?? this.travelersNames,
      budget: budget ?? this.budget,
      transportBudget: transportBudget ?? this.transportBudget,
      accommodationBudget: accommodationBudget ?? this.accommodationBudget,
      foodBudget: foodBudget ?? this.foodBudget,
      sightseeingBudget: sightseeingBudget ?? this.sightseeingBudget,
      shoppingBudget: shoppingBudget ?? this.shoppingBudget,
      otherBudget: otherBudget ?? this.otherBudget,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      preferences: preferences ?? this.preferences,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'destination': destination,
      'additional_destinations': jsonEncode(additionalDestinations),
      'departure_city': departureCity,
      'start_date': startDate.millisecondsSinceEpoch,
      'end_date': endDate.millisecondsSinceEpoch,
      'currency': currency,
      'travelers_count': travelersCount,
      'travelers_names': jsonEncode(travelersNames),
      'budget': budget,
      'transport_budget': transportBudget,
      'accommodation_budget': accommodationBudget,
      'food_budget': foodBudget,
      'sightseeing_budget': sightseeingBudget,
      'shopping_budget': shoppingBudget,
      'other_budget': otherBudget,
      'description': description,
      'cover_image': coverImage,
      'preferences': jsonEncode(preferences),
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return Trip(
      id: map['id'] as String,
      title: map['title'] as String,
      destination: map['destination'] as String,
      additionalDestinations:
          parseStringList(map['additional_destinations']),
      departureCity: map['departure_city'] as String?,
      startDate:
          DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
      endDate:
          DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int),
      currency: (map['currency'] as String?) ?? 'INR',
      travelersCount: (map['travelers_count'] as int?) ?? 1,
      travelersNames: parseStringList(map['travelers_names']).isNotEmpty
          ? parseStringList(map['travelers_names'])
          : const ['You'],
      budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
      transportBudget:
          (map['transport_budget'] as num?)?.toDouble() ?? 0.0,
      accommodationBudget:
          (map['accommodation_budget'] as num?)?.toDouble() ?? 0.0,
      foodBudget: (map['food_budget'] as num?)?.toDouble() ?? 0.0,
      sightseeingBudget:
          (map['sightseeing_budget'] as num?)?.toDouble() ?? 0.0,
      shoppingBudget:
          (map['shopping_budget'] as num?)?.toDouble() ?? 0.0,
      otherBudget: (map['other_budget'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      coverImage: map['cover_image'] as String?,
      preferences: parseStringList(map['preferences']),
      status: TripStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TripStatus.upcoming,
      ),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
