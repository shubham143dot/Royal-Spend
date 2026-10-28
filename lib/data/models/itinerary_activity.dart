import 'package:flutter/cupertino.dart';

enum ActivityCategory {
  transport,
  sightseeing,
  meal,
  accommodation,
  rest,
  shopping,
  custom;

  String get displayName {
    switch (this) {
      case ActivityCategory.transport:
        return 'Transport';
      case ActivityCategory.sightseeing:
        return 'Sightseeing';
      case ActivityCategory.meal:
        return 'Food & Dining';
      case ActivityCategory.accommodation:
        return 'Stay & Check-in';
      case ActivityCategory.rest:
        return 'Rest & Relax';
      case ActivityCategory.shopping:
        return 'Shopping';
      case ActivityCategory.custom:
        return 'Activity';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityCategory.transport:
        return CupertinoIcons.bus;
      case ActivityCategory.sightseeing:
        return CupertinoIcons.photo_fill;
      case ActivityCategory.meal:
        return CupertinoIcons.sparkles;
      case ActivityCategory.accommodation:
        return CupertinoIcons.bed_double_fill;
      case ActivityCategory.rest:
        return CupertinoIcons.moon_stars_fill;
      case ActivityCategory.shopping:
        return CupertinoIcons.bag_fill;
      case ActivityCategory.custom:
        return CupertinoIcons.placemark_fill;
    }
  }

  Color get color {
    switch (this) {
      case ActivityCategory.transport:
        return const Color(0xFF0A84FF); // Apple Blue
      case ActivityCategory.sightseeing:
        return const Color(0xFFBF5AF2); // Apple Purple
      case ActivityCategory.meal:
        return const Color(0xFFFF9F0A); // Apple Orange
      case ActivityCategory.accommodation:
        return const Color(0xFF30D158); // Apple Green
      case ActivityCategory.rest:
        return const Color(0xFF64D2FF); // Apple Teal / Soft Cyan
      case ActivityCategory.shopping:
        return const Color(0xFFFF375F); // Apple Pink / Rose
      case ActivityCategory.custom:
        return const Color(0xFF5E5CE6); // Apple Indigo
    }
  }
}

enum BookingStatus {
  unconfirmed,
  planned,
  booked,
  optional,
  notNeeded;

  String get displayName {
    switch (this) {
      case BookingStatus.unconfirmed:
        return 'Unconfirmed';
      case BookingStatus.planned:
        return 'Planned';
      case BookingStatus.booked:
        return 'Confirmed';
      case BookingStatus.optional:
        return 'Optional';
      case BookingStatus.notNeeded:
        return 'Not Needed';
    }
  }

  Color get badgeColor {
    switch (this) {
      case BookingStatus.unconfirmed:
        return const Color(0xFFFF9F0A);
      case BookingStatus.planned:
        return const Color(0xFF0A84FF);
      case BookingStatus.booked:
        return const Color(0xFF30D158);
      case BookingStatus.optional:
        return const Color(0xFF64D2FF);
      case BookingStatus.notNeeded:
        return const Color(0xFF8E8E93);
    }
  }
}

class ItineraryActivity {
  final String id;
  final String tripId;
  final String dayId;
  final String title;
  final String? placeName;
  final String? startTime; // e.g. "10:50 AM"
  final String? endTime; // e.g. "03:30 AM"
  final int? durationMinutes;
  final ActivityCategory category;
  final String? notes;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double estimatedCost;
  final BookingStatus bookingStatus;
  final String? bookingReference;
  final bool isCompleted;
  final bool isDestinationConfirmed;
  final bool isOvernight;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItineraryActivity({
    required this.id,
    required this.tripId,
    required this.dayId,
    required this.title,
    this.placeName,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.category = ActivityCategory.sightseeing,
    this.notes,
    this.address,
    this.latitude,
    this.longitude,
    this.estimatedCost = 0.0,
    this.bookingStatus = BookingStatus.unconfirmed,
    this.bookingReference,
    this.isCompleted = false,
    this.isDestinationConfirmed = true,
    this.isOvernight = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get formattedCost {
    if (estimatedCost <= 0) return 'Free / Included';
    return '₹${estimatedCost.toStringAsFixed(estimatedCost.truncateToDouble() == estimatedCost ? 0 : 2)}';
  }

  ItineraryActivity copyWith({
    String? id,
    String? tripId,
    String? dayId,
    String? title,
    String? placeName,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    ActivityCategory? category,
    String? notes,
    String? address,
    double? latitude,
    double? longitude,
    double? estimatedCost,
    BookingStatus? bookingStatus,
    String? bookingReference,
    bool? isCompleted,
    bool? isDestinationConfirmed,
    bool? isOvernight,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryActivity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayId: dayId ?? this.dayId,
      title: title ?? this.title,
      placeName: placeName ?? this.placeName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      bookingReference: bookingReference ?? this.bookingReference,
      isCompleted: isCompleted ?? this.isCompleted,
      isDestinationConfirmed:
          isDestinationConfirmed ?? this.isDestinationConfirmed,
      isOvernight: isOvernight ?? this.isOvernight,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'day_id': dayId,
      'title': title,
      'place_name': placeName,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'category': category.name,
      'notes': notes,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'estimated_cost': estimatedCost,
      'booking_status': bookingStatus.name,
      'booking_reference': bookingReference,
      'is_completed': isCompleted ? 1 : 0,
      'is_destination_confirmed': isDestinationConfirmed ? 1 : 0,
      'is_overnight': isOvernight ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ItineraryActivity.fromMap(Map<String, dynamic> map) {
    return ItineraryActivity(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      dayId: map['day_id'] as String,
      title: map['title'] as String,
      placeName: map['place_name'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      durationMinutes: map['duration_minutes'] as int?,
      category: ActivityCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ActivityCategory.sightseeing,
      ),
      notes: map['notes'] as String?,
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      bookingStatus: BookingStatus.values.firstWhere(
        (b) => b.name == map['booking_status'],
        orElse: () => BookingStatus.unconfirmed,
      ),
      bookingReference: map['booking_reference'] as String?,
      isCompleted: (map['is_completed'] as int) == 1,
      isDestinationConfirmed: (map['is_destination_confirmed'] as int? ?? 1) == 1,
      isOvernight: (map['is_overnight'] as int? ?? 0) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
