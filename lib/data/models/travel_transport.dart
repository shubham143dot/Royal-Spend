import 'package:flutter/cupertino.dart';
import 'itinerary_activity.dart';

enum TransportType {
  train,
  bus,
  flight,
  taxi,
  scooty,
  selfDrive,
  walk,
  other;

  String get displayName {
    switch (this) {
      case TransportType.train:
        return 'Train';
      case TransportType.bus:
        return 'Bus';
      case TransportType.flight:
        return 'Flight';
      case TransportType.taxi:
        return 'Taxi / Cab';
      case TransportType.scooty:
        return 'Scooty / Bike Rental';
      case TransportType.selfDrive:
        return 'Self-Drive';
      case TransportType.walk:
        return 'Walking';
      case TransportType.other:
        return 'Transport';
    }
  }

  IconData get icon {
    switch (this) {
      case TransportType.train:
        return CupertinoIcons.tram_fill;
      case TransportType.bus:
        return CupertinoIcons.bus;
      case TransportType.flight:
        return CupertinoIcons.airplane;
      case TransportType.taxi:
        return CupertinoIcons.car_detailed;
      case TransportType.scooty:
        return CupertinoIcons.bolt_horizontal_circle_fill;
      case TransportType.selfDrive:
        return CupertinoIcons.car_fill;
      case TransportType.walk:
        return CupertinoIcons.location_fill;
      case TransportType.other:
        return CupertinoIcons.arrow_right_circle_fill;
    }
  }
}

class TravelTransport {
  final String id;
  final String tripId;
  final TransportType type;
  final String? provider;
  final String departurePlace;
  final String arrivalPlace;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String? bookingReference;
  final BookingStatus bookingStatus;
  final double cost;
  final String? notes;
  final DateTime createdAt;

  TravelTransport({
    required this.id,
    required this.tripId,
    required this.type,
    this.provider,
    required this.departurePlace,
    required this.arrivalPlace,
    required this.departureTime,
    required this.arrivalTime,
    this.bookingReference,
    this.bookingStatus = BookingStatus.unconfirmed,
    this.cost = 0.0,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOvernight {
    final depDay =
        DateTime(departureTime.year, departureTime.month, departureTime.day);
    final arrDay =
        DateTime(arrivalTime.year, arrivalTime.month, arrivalTime.day);
    return arrDay.isAfter(depDay);
  }

  TravelTransport copyWith({
    String? id,
    String? tripId,
    TransportType? type,
    String? provider,
    String? departurePlace,
    String? arrivalPlace,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? bookingReference,
    BookingStatus? bookingStatus,
    double? cost,
    String? notes,
    DateTime? createdAt,
  }) {
    return TravelTransport(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      provider: provider ?? this.provider,
      departurePlace: departurePlace ?? this.departurePlace,
      arrivalPlace: arrivalPlace ?? this.arrivalPlace,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      bookingReference: bookingReference ?? this.bookingReference,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'type': type.name,
      'provider': provider,
      'departure_place': departurePlace,
      'arrival_place': arrivalPlace,
      'departure_time': departureTime.millisecondsSinceEpoch,
      'arrival_time': arrivalTime.millisecondsSinceEpoch,
      'booking_reference': bookingReference,
      'booking_status': bookingStatus.name,
      'cost': cost,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TravelTransport.fromMap(Map<String, dynamic> map) {
    return TravelTransport(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      type: TransportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransportType.other,
      ),
      provider: map['provider'] as String?,
      departurePlace: map['departure_place'] as String,
      arrivalPlace: map['arrival_place'] as String,
      departureTime:
          DateTime.fromMillisecondsSinceEpoch(map['departure_time'] as int),
      arrivalTime:
          DateTime.fromMillisecondsSinceEpoch(map['arrival_time'] as int),
      bookingReference: map['booking_reference'] as String?,
      bookingStatus: BookingStatus.values.firstWhere(
        (b) => b.name == map['booking_status'],
        orElse: () => BookingStatus.unconfirmed,
      ),
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
