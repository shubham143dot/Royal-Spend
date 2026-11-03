class ItineraryDay {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? title;
  final String? notes;
  final bool isCompleted;
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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ItineraryDay copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    DateTime? date,
    String? title,
    String? notes,
    bool? isCompleted,
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
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
