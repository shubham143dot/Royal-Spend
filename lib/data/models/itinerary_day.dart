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
    return ItineraryDay(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      dayNumber: map['day_number'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      isCompleted: (map['is_completed'] as int) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
