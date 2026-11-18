class ItineraryDay {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? title;
  final String? notes;
  final bool isCompleted;
  final String? startPlaceName;
  final String? startAddress;
  final double? startLatitude;
  final double? startLongitude;
  final String? startPlaceId;
  final String? startTime;
  final String? startNotes;
  final String? startType; // 'hotel', 'airport', 'home', 'station', 'custom'
  final String? endPlaceName;
  final String? endAddress;
  final double? endLatitude;
  final double? endLongitude;
  final String? endPlaceId;
  final String? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.title,
    this.notes,
    this.isCompleted = false,
    this.startPlaceName,
    this.startAddress,
    this.startLatitude,
    this.startLongitude,
    this.startPlaceId,
    this.startTime,
    this.startNotes,
    this.startType,
    this.endPlaceName,
    this.endAddress,
    this.endLatitude,
    this.endLongitude,
    this.endPlaceId,
    this.endTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasStartingPoint =>
      startPlaceName != null && startPlaceName!.trim().isNotEmpty;

  bool get hasStartingCoordinates =>
      startLatitude != null && startLongitude != null;

  bool get hasEndPoint =>
      endPlaceName != null && endPlaceName!.trim().isNotEmpty;

  bool get hasEndCoordinates =>
      endLatitude != null && endLongitude != null;

  ItineraryDay copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    DateTime? date,
    String? title,
    String? notes,
    bool? isCompleted,
    String? startPlaceName,
    bool clearStartPlaceName = false,
    String? startAddress,
    bool clearStartAddress = false,
    double? startLatitude,
    bool clearStartCoordinates = false,
    double? startLongitude,
    String? startPlaceId,
    bool clearStartPlaceId = false,
    String? startTime,
    bool clearStartTime = false,
    String? startNotes,
    bool clearStartNotes = false,
    String? startType,
    bool clearStartType = false,
    String? endPlaceName,
    bool clearEndPlaceName = false,
    String? endAddress,
    bool clearEndAddress = false,
    double? endLatitude,
    bool clearEndCoordinates = false,
    double? endLongitude,
    String? endPlaceId,
    bool clearEndPlaceId = false,
    String? endTime,
    bool clearEndTime = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      startPlaceName:
          clearStartPlaceName ? null : (startPlaceName ?? this.startPlaceName),
      startAddress:
          clearStartAddress ? null : (startAddress ?? this.startAddress),
      startLatitude: clearStartCoordinates
          ? null
          : (startLatitude ?? this.startLatitude),
      startLongitude: clearStartCoordinates
          ? null
          : (startLongitude ?? this.startLongitude),
      startPlaceId:
          clearStartPlaceId ? null : (startPlaceId ?? this.startPlaceId),
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      startNotes: clearStartNotes ? null : (startNotes ?? this.startNotes),
      startType: clearStartType ? null : (startType ?? this.startType),
      endPlaceName:
          clearEndPlaceName ? null : (endPlaceName ?? this.endPlaceName),
      endAddress: clearEndAddress ? null : (endAddress ?? this.endAddress),
      endLatitude:
          clearEndCoordinates ? null : (endLatitude ?? this.endLatitude),
      endLongitude:
          clearEndCoordinates ? null : (endLongitude ?? this.endLongitude),
      endPlaceId: clearEndPlaceId ? null : (endPlaceId ?? this.endPlaceId),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'day_number': dayNumber,
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'notes': notes,
      'is_completed': isCompleted ? 1 : 0,
      'start_place_name': startPlaceName,
      'start_address': startAddress,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'start_place_id': startPlaceId,
      'start_time': startTime,
      'start_notes': startNotes,
      'start_type': startType,
      'end_place_name': endPlaceName,
      'end_address': endAddress,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'end_place_id': endPlaceId,
      'end_time': endTime,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ItineraryDay.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        final dynamic d = val;
        return d.toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return false;
    }

    return ItineraryDay(
      id: map['id']?.toString() ?? '',
      tripId: map['trip_id']?.toString() ?? '',
      dayNumber: (map['day_number'] as num?)?.toInt() ?? 1,
      date: parseDate(map['date']),
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      isCompleted: parseBool(map['is_completed']),
      startPlaceName: map['start_place_name'] as String?,
      startAddress: map['start_address'] as String?,
      startLatitude: (map['start_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble(),
      startPlaceId: map['start_place_id'] as String?,
      startTime: map['start_time'] as String?,
      startNotes: map['start_notes'] as String?,
      startType: map['start_type'] as String?,
      endPlaceName: map['end_place_name'] as String?,
      endAddress: map['end_address'] as String?,
      endLatitude: (map['end_latitude'] as num?)?.toDouble(),
      endLongitude: (map['end_longitude'] as num?)?.toDouble(),
      endPlaceId: map['end_place_id'] as String?,
      endTime: map['end_time'] as String?,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
