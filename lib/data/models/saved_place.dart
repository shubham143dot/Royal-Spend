class SavedPlace {
  final String id;
  final String tripId;
  final String name;
  final String? address;
  final String? locationNotes;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final DateTime? plannedDate;
  final bool isVisited;
  final DateTime createdAt;

  SavedPlace({
    required this.id,
    required this.tripId,
    required this.name,
    this.address,
    this.locationNotes,
    this.category = 'Sightseeing',
    this.latitude,
    this.longitude,
    this.placeId,
    this.plannedDate,
    this.isVisited = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  SavedPlace copyWith({
    String? id,
    String? tripId,
    String? name,
    String? address,
    String? locationNotes,
    String? category,
    double? latitude,
    double? longitude,
    String? placeId,
    DateTime? plannedDate,
    bool? isVisited,
    DateTime? createdAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      address: address ?? this.address,
      locationNotes: locationNotes ?? this.locationNotes,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      plannedDate: plannedDate ?? this.plannedDate,
      isVisited: isVisited ?? this.isVisited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'address': address,
      'location_notes': locationNotes,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'place_id': placeId,
      'planned_date': plannedDate?.millisecondsSinceEpoch,
      'is_visited': isVisited ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    return SavedPlace(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      locationNotes: map['location_notes'] as String?,
      category: (map['category'] as String?) ?? 'Sightseeing',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      placeId: map['place_id'] as String?,
      plannedDate: map['planned_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['planned_date'] as int)
          : null,
      isVisited: (map['is_visited'] as int) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
