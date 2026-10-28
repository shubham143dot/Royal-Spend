import 'package:flutter/material.dart';

enum AccommodationStatus {
  savedPreference,
  planned,
  unconfirmed,
  booked,
  cancelled;

  String get displayName {
    switch (this) {
      case AccommodationStatus.savedPreference:
        return 'Saved Preference';
      case AccommodationStatus.planned:
        return 'Planned';
      case AccommodationStatus.unconfirmed:
        return 'Unconfirmed';
      case AccommodationStatus.booked:
        return 'Booked';
      case AccommodationStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get badgeColor {
    switch (this) {
      case AccommodationStatus.savedPreference:
        return const Color(0xFFBF5AF2); // Apple Purple
      case AccommodationStatus.planned:
        return const Color(0xFF0A84FF); // Apple Blue
      case AccommodationStatus.unconfirmed:
        return const Color(0xFFFF9F0A); // Apple Orange
      case AccommodationStatus.booked:
        return const Color(0xFF30D158); // Apple Green
      case AccommodationStatus.cancelled:
        return const Color(0xFFFF453A); // Apple Red
    }
  }
}

class TravelAccommodation {
  final String id;
  final String tripId;
  final String propertyName;
  final String? address;
  final DateTime checkIn;
  final DateTime checkOut;
  final AccommodationStatus bookingStatus;
  final double cost;
  final String? bookingReference;
  final String? contactInfo;
  final String? notes;
  final DateTime createdAt;

  TravelAccommodation({
    required this.id,
    required this.tripId,
    required this.propertyName,
    this.address,
    required this.checkIn,
    required this.checkOut,
    this.bookingStatus = AccommodationStatus.unconfirmed,
    this.cost = 0.0,
    this.bookingReference,
    this.contactInfo,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AccommodationStatus get status => bookingStatus;

  int get nightsCount {
    final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final diff = end.difference(start).inDays;
    return diff > 0 ? diff : 1;
  }

  TravelAccommodation copyWith({
    String? id,
    String? tripId,
    String? propertyName,
    String? address,
    DateTime? checkIn,
    DateTime? checkOut,
    AccommodationStatus? bookingStatus,
    double? cost,
    String? bookingReference,
    String? contactInfo,
    String? notes,
    DateTime? createdAt,
  }) {
    return TravelAccommodation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      propertyName: propertyName ?? this.propertyName,
      address: address ?? this.address,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      cost: cost ?? this.cost,
      bookingReference: bookingReference ?? this.bookingReference,
      contactInfo: contactInfo ?? this.contactInfo,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'property_name': propertyName,
      'address': address,
      'check_in': checkIn.millisecondsSinceEpoch,
      'check_out': checkOut.millisecondsSinceEpoch,
      'booking_status': bookingStatus.name,
      'cost': cost,
      'booking_reference': bookingReference,
      'contact_info': contactInfo,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TravelAccommodation.fromMap(Map<String, dynamic> map) {
    return TravelAccommodation(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      propertyName: map['property_name'] as String,
      address: map['address'] as String?,
      checkIn:
          DateTime.fromMillisecondsSinceEpoch(map['check_in'] as int),
      checkOut:
          DateTime.fromMillisecondsSinceEpoch(map['check_out'] as int),
      bookingStatus: AccommodationStatus.values.firstWhere(
        (b) => b.name == map['booking_status'],
        orElse: () => AccommodationStatus.unconfirmed,
      ),
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      bookingReference: map['booking_reference'] as String?,
      contactInfo: map['contact_info'] as String?,
      notes: map['notes'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
