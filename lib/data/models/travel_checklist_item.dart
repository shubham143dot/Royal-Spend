import 'package:flutter/cupertino.dart';

enum ChecklistCategory {
  documents,
  transport,
  accommodation,
  clothing,
  electronics,
  toiletries,
  essentials,
  shopping,
  custom;

  String get displayName {
    switch (this) {
      case ChecklistCategory.documents:
        return 'Documents & IDs';
      case ChecklistCategory.transport:
        return 'Tickets & Transport';
      case ChecklistCategory.accommodation:
        return 'Stay & Bookings';
      case ChecklistCategory.clothing:
        return 'Clothing & Gear';
      case ChecklistCategory.electronics:
        return 'Electronics & Chargers';
      case ChecklistCategory.toiletries:
        return 'Toiletries & Care';
      case ChecklistCategory.essentials:
        return 'Personal Essentials';
      case ChecklistCategory.shopping:
        return 'Shopping List';
      case ChecklistCategory.custom:
        return 'General Tasks';
    }
  }

  IconData get icon {
    switch (this) {
      case ChecklistCategory.documents:
        return CupertinoIcons.doc_text_fill;
      case ChecklistCategory.transport:
        return CupertinoIcons.ticket_fill;
      case ChecklistCategory.accommodation:
        return CupertinoIcons.house_fill;
      case ChecklistCategory.clothing:
        return CupertinoIcons.tag_fill;
      case ChecklistCategory.electronics:
        return CupertinoIcons.device_phone_portrait;
      case ChecklistCategory.toiletries:
        return CupertinoIcons.drop_fill;
      case ChecklistCategory.essentials:
        return CupertinoIcons.heart_fill;
      case ChecklistCategory.shopping:
        return CupertinoIcons.bag_fill;
      case ChecklistCategory.custom:
        return CupertinoIcons.check_mark_circled_solid;
    }
  }

  Color get color {
    switch (this) {
      case ChecklistCategory.documents:
        return const Color(0xFF0A84FF);
      case ChecklistCategory.transport:
        return const Color(0xFF5E5CE6);
      case ChecklistCategory.accommodation:
        return const Color(0xFF30D158);
      case ChecklistCategory.clothing:
        return const Color(0xFFFF9F0A);
      case ChecklistCategory.electronics:
        return const Color(0xFF64D2FF);
      case ChecklistCategory.toiletries:
        return const Color(0xFFBF5AF2);
      case ChecklistCategory.essentials:
        return const Color(0xFFFF375F);
      case ChecklistCategory.shopping:
        return const Color(0xFFFFD60A);
      case ChecklistCategory.custom:
        return const Color(0xFF8E8E93);
    }
  }
}

class TravelChecklistItem {
  final String id;
  final String tripId;
  final ChecklistCategory category;
  final String item;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  TravelChecklistItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.item,
    this.isCompleted = false,
    this.dueDate,
    this.notes,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TravelChecklistItem copyWith({
    String? id,
    String? tripId,
    ChecklistCategory? category,
    String? item,
    bool? isCompleted,
    DateTime? dueDate,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return TravelChecklistItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      item: item ?? this.item,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'category': category.name,
      'item': item,
      'is_completed': isCompleted ? 1 : 0,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TravelChecklistItem.fromMap(Map<String, dynamic> map) {
    return TravelChecklistItem(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      category: ChecklistCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ChecklistCategory.custom,
      ),
      item: map['item'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      notes: map['notes'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
