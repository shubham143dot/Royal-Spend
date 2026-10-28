import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/default_categories.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/itinerary_activity.dart';
import '../models/itinerary_day.dart';
import '../models/saved_place.dart';
import '../models/travel_accommodation.dart';
import '../models/travel_checklist_item.dart';
import '../models/travel_split.dart';
import '../models/travel_transport.dart';
import '../models/trip.dart';

class DatabaseHelper {
  static const String _databaseName = 'royal_spend.db';
  static const int _databaseVersion = 2;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appSupportDir = await getApplicationSupportDirectory();
      path = p.join(appSupportDir.path, _databaseName);
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Expenses Table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        is_income INTEGER NOT NULL DEFAULT 0,
        trip_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_date ON expenses (date DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_category ON expenses (category_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_trip ON expenses (trip_id)
    ''');

    // 2. Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        monthly_limit REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        warning_threshold REAL NOT NULL DEFAULT 0.8
      )
    ''');

    // 3. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Populate initial categories
    final batch = db.batch();
    for (final category in DefaultCategories.categories) {
      batch.insert('categories', category.toMap());
    }
    await batch.commit(noResult: true);

    // 4. Travel Tables
    await _createTravelTables(db);
  }

  Future<void> _createTravelTables(DatabaseExecutor db) async {
    // Trips
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        destination TEXT NOT NULL,
        additional_destinations TEXT,
        departure_city TEXT,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'INR',
        travelers_count INTEGER NOT NULL DEFAULT 1,
        travelers_names TEXT,
        budget REAL NOT NULL DEFAULT 0.0,
        transport_budget REAL DEFAULT 0.0,
        accommodation_budget REAL DEFAULT 0.0,
        food_budget REAL DEFAULT 0.0,
        sightseeing_budget REAL DEFAULT 0.0,
        shopping_budget REAL DEFAULT 0.0,
        other_budget REAL DEFAULT 0.0,
        description TEXT,
        cover_image TEXT,
        preferences TEXT,
        status TEXT NOT NULL DEFAULT 'upcoming',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_trips_dates ON trips (start_date ASC, end_date ASC)
    ''');

    // Itinerary Days
    await db.execute('''
      CREATE TABLE IF NOT EXISTS itinerary_days (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        day_number INTEGER NOT NULL,
        date INTEGER NOT NULL,
        title TEXT,
        notes TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_itinerary_days_trip ON itinerary_days (trip_id, day_number ASC)
    ''');

    // Itinerary Activities
    await db.execute('''
      CREATE TABLE IF NOT EXISTS itinerary_activities (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        day_id TEXT NOT NULL,
        title TEXT NOT NULL,
        place_name TEXT,
        start_time TEXT,
        end_time TEXT,
        duration_minutes INTEGER,
        category TEXT NOT NULL DEFAULT 'sightseeing',
        notes TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        estimated_cost REAL DEFAULT 0.0,
        booking_status TEXT DEFAULT 'unconfirmed',
        booking_reference TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_destination_confirmed INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (day_id) REFERENCES itinerary_days (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_activities_trip_day ON itinerary_activities (trip_id, day_id, sort_order ASC)
    ''');

    // Saved Places
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_places (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        location_notes TEXT,
        category TEXT DEFAULT 'Sightseeing',
        latitude REAL,
        longitude REAL,
        planned_date INTEGER,
        is_visited INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_saved_places_trip ON saved_places (trip_id)
    ''');

    // Travel Transports
    await db.execute('''
      CREATE TABLE IF NOT EXISTS travel_transports (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        type TEXT NOT NULL,
        provider TEXT,
        departure_place TEXT NOT NULL,
        arrival_place TEXT NOT NULL,
        departure_time INTEGER NOT NULL,
        arrival_time INTEGER NOT NULL,
        booking_reference TEXT,
        booking_status TEXT NOT NULL DEFAULT 'unconfirmed',
        cost REAL DEFAULT 0.0,
        notes TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transports_trip ON travel_transports (trip_id)
    ''');

    // Travel Accommodations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS travel_accommodations (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        property_name TEXT NOT NULL,
        address TEXT,
        check_in INTEGER NOT NULL,
        check_out INTEGER NOT NULL,
        booking_status TEXT NOT NULL DEFAULT 'unconfirmed',
        cost REAL DEFAULT 0.0,
        booking_reference TEXT,
        contact_info TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_accommodations_trip ON travel_accommodations (trip_id)
    ''');

    // Travel Checklists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS travel_checklists (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        category TEXT NOT NULL,
        item TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_checklists_trip ON travel_checklists (trip_id)
    ''');

    // Travel Splits
    await db.execute('''
      CREATE TABLE IF NOT EXISTS travel_splits (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        expense_id TEXT,
        title TEXT NOT NULL,
        total_amount REAL NOT NULL,
        paid_by TEXT NOT NULL,
        split_type TEXT NOT NULL DEFAULT 'equal',
        shares_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_splits_trip ON travel_splits (trip_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add trip_id column to expenses if not already present
      final tableInfo = await db.rawQuery('PRAGMA table_info(expenses)');
      final hasTripId = tableInfo.any((col) => col['name'] == 'trip_id');
      if (!hasTripId) {
        await db.execute('ALTER TABLE expenses ADD COLUMN trip_id TEXT;');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_expenses_trip ON expenses (trip_id);');
      }

      // 2. Create travel tables
      await _createTravelTables(db);
    }
  }

  // --- Expense CRUD Operations ---

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch - 1;

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  // --- Budget Operations ---

  Future<Budget?> getBudgetForMonth(int year, int month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> setBudgetForMonth(Budget budget) async {
    final db = await database;
    return await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Multi-Trip Travel CRUD Operations ---

  Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return await db.insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<int> deleteTrip(String tripId, {bool deleteExpenses = false}) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      if (deleteExpenses) {
        await txn.delete('expenses', where: 'trip_id = ?', whereArgs: [tripId]);
      } else {
        // Disassociate expenses safely so financial history remains intact
        await txn.rawUpdate(
          'UPDATE expenses SET trip_id = NULL WHERE trip_id = ?',
          [tripId],
        );
      }
      await txn.delete('itinerary_activities',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('itinerary_days',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('saved_places',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('travel_transports',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('travel_accommodations',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('travel_checklists',
          where: 'trip_id = ?', whereArgs: [tripId]);
      await txn.delete('travel_splits',
          where: 'trip_id = ?', whereArgs: [tripId]);
      return await txn.delete('trips', where: 'id = ?', whereArgs: [tripId]);
    });
  }

  Future<Trip?> getTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Trip.fromMap(maps.first);
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      orderBy: 'start_date ASC, created_at DESC',
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  // --- Itinerary Day Operations ---

  Future<int> insertItineraryDay(ItineraryDay day) async {
    final db = await database;
    return await db.insert(
      'itinerary_days',
      day.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateItineraryDay(ItineraryDay day) async {
    final db = await database;
    return await db.update(
      'itinerary_days',
      day.toMap(),
      where: 'id = ?',
      whereArgs: [day.id],
    );
  }

  Future<int> deleteItineraryDay(String dayId) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      await txn.delete('itinerary_activities',
          where: 'day_id = ?', whereArgs: [dayId]);
      return await txn
          .delete('itinerary_days', where: 'id = ?', whereArgs: [dayId]);
    });
  }

  Future<List<ItineraryDay>> getDaysForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'itinerary_days',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'day_number ASC',
    );
    return maps.map((m) => ItineraryDay.fromMap(m)).toList();
  }

  // --- Itinerary Activity Operations ---

  Future<int> insertActivity(ItineraryActivity activity) async {
    final db = await database;
    return await db.insert(
      'itinerary_activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateActivity(ItineraryActivity activity) async {
    final db = await database;
    return await db.update(
      'itinerary_activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<int> deleteActivity(String activityId) async {
    final db = await database;
    return await db.delete(
      'itinerary_activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<List<ItineraryActivity>> getActivitiesForDay(String dayId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'itinerary_activities',
      where: 'day_id = ?',
      whereArgs: [dayId],
      orderBy: 'sort_order ASC, start_time ASC',
    );
    return maps.map((m) => ItineraryActivity.fromMap(m)).toList();
  }

  Future<List<ItineraryActivity>> getActivitiesForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'itinerary_activities',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'sort_order ASC, start_time ASC',
    );
    return maps.map((m) => ItineraryActivity.fromMap(m)).toList();
  }

  // --- Saved Places Operations ---

  Future<int> insertSavedPlace(SavedPlace place) async {
    final db = await database;
    return await db.insert(
      'saved_places',
      place.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateSavedPlace(SavedPlace place) async {
    final db = await database;
    return await db.update(
      'saved_places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<int> deleteSavedPlace(String placeId) async {
    final db = await database;
    return await db.delete(
      'saved_places',
      where: 'id = ?',
      whereArgs: [placeId],
    );
  }

  Future<List<SavedPlace>> getSavedPlacesForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saved_places',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => SavedPlace.fromMap(m)).toList();
  }

  // --- Travel Transport Operations ---

  Future<int> insertTransport(TravelTransport transport) async {
    final db = await database;
    return await db.insert(
      'travel_transports',
      transport.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTransport(TravelTransport transport) async {
    final db = await database;
    return await db.update(
      'travel_transports',
      transport.toMap(),
      where: 'id = ?',
      whereArgs: [transport.id],
    );
  }

  Future<int> deleteTransport(String transportId) async {
    final db = await database;
    return await db.delete(
      'travel_transports',
      where: 'id = ?',
      whereArgs: [transportId],
    );
  }

  Future<List<TravelTransport>> getTransportsForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'travel_transports',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'departure_time ASC',
    );
    return maps.map((m) => TravelTransport.fromMap(m)).toList();
  }

  // --- Travel Accommodation Operations ---

  Future<int> insertAccommodation(TravelAccommodation accommodation) async {
    final db = await database;
    return await db.insert(
      'travel_accommodations',
      accommodation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateAccommodation(TravelAccommodation accommodation) async {
    final db = await database;
    return await db.update(
      'travel_accommodations',
      accommodation.toMap(),
      where: 'id = ?',
      whereArgs: [accommodation.id],
    );
  }

  Future<int> deleteAccommodation(String accommodationId) async {
    final db = await database;
    return await db.delete(
      'travel_accommodations',
      where: 'id = ?',
      whereArgs: [accommodationId],
    );
  }

  Future<List<TravelAccommodation>> getAccommodationsForTrip(
      String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'travel_accommodations',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'check_in ASC',
    );
    return maps.map((m) => TravelAccommodation.fromMap(m)).toList();
  }

  // --- Travel Checklist Operations ---

  Future<int> insertChecklistItem(TravelChecklistItem item) async {
    final db = await database;
    return await db.insert(
      'travel_checklists',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateChecklistItem(TravelChecklistItem item) async {
    final db = await database;
    return await db.update(
      'travel_checklists',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteChecklistItem(String itemId) async {
    final db = await database;
    return await db.delete(
      'travel_checklists',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<List<TravelChecklistItem>> getChecklistForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'travel_checklists',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map((m) => TravelChecklistItem.fromMap(m)).toList();
  }

  // --- Travel Split Operations ---

  Future<int> insertSplit(TravelSplit split) async {
    final db = await database;
    return await db.insert(
      'travel_splits',
      split.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteSplit(String splitId) async {
    final db = await database;
    return await db.delete(
      'travel_splits',
      where: 'id = ?',
      whereArgs: [splitId],
    );
  }

  Future<List<TravelSplit>> getSplitsForTrip(String tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'travel_splits',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => TravelSplit.fromMap(m)).toList();
  }

  // --- Data Management & Seeding ---

  Future<void> clearAllExpenses() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('budgets');
  }

  Future<void> clearAllTravelData() async {
    final db = await database;
    await db.delete('itinerary_activities');
    await db.delete('itinerary_days');
    await db.delete('saved_places');
    await db.delete('travel_transports');
    await db.delete('travel_accommodations');
    await db.delete('travel_checklists');
    await db.delete('travel_splits');
    await db.delete('trips');
  }

  Future<void> seedRealisticSampleData() async {
    final db = await database;
    const uuid = Uuid();
    final now = DateTime.now();

    final sampleItems = [
      // Today
      Expense(
        id: uuid.v4(),
        title: 'Artisan Espresso & Croissant',
        amount: 280.0,
        categoryId: 'food',
        date: now.subtract(const Duration(hours: 3)),
        paymentMethod: PaymentMethod.upi,
        notes: 'Blue Tokai Cafe with team',
      ),
      Expense(
        id: uuid.v4(),
        title: 'Uber Premier to Client Office',
        amount: 450.0,
        categoryId: 'transport',
        date: now.subtract(const Duration(hours: 6)),
        paymentMethod: PaymentMethod.upi,
      ),
      // Yesterday
      Expense(
        id: uuid.v4(),
        title: 'Whole Foods Grocery Supply',
        amount: 2150.0,
        categoryId: 'food',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        paymentMethod: PaymentMethod.creditCard,
        notes: 'Monthly pantry restock',
      ),
      Expense(
        id: uuid.v4(),
        title: 'High-Speed Fiber Internet Bill',
        amount: 1499.0,
        categoryId: 'bills',
        date: now.subtract(const Duration(days: 1, hours: 5)),
        paymentMethod: PaymentMethod.upi,
        notes: 'AirTel Xstream Gigabit',
      ),
      // Earlier this week
      Expense(
        id: uuid.v4(),
        title: 'Apple Developer Account Renewal',
        amount: 8900.0,
        categoryId: 'education',
        date: now.subtract(const Duration(days: 3)),
        paymentMethod: PaymentMethod.creditCard,
        notes: 'Annual iOS developer license',
      ),
      Expense(
        id: uuid.v4(),
        title: 'Weekend Flight Ticket to Goa',
        amount: 4200.0,
        categoryId: 'travel',
        date: now.subtract(const Duration(days: 4)),
        paymentMethod: PaymentMethod.debitCard,
        notes: 'IndiGo 6E-241',
      ),
      Expense(
        id: uuid.v4(),
        title: 'Minimalist Mechanical Keyboard',
        amount: 3600.0,
        categoryId: 'shopping',
        date: now.subtract(const Duration(days: 6)),
        paymentMethod: PaymentMethod.creditCard,
      ),
      Expense(
        id: uuid.v4(),
        title: 'Monthly Gym & Spa Membership',
        amount: 2500.0,
        categoryId: 'health',
        date: now.subtract(const Duration(days: 7)),
        paymentMethod: PaymentMethod.bankTransfer,
      ),
      Expense(
        id: uuid.v4(),
        title: 'IMAX Cinema - Christopher Nolan Night',
        amount: 950.0,
        categoryId: 'entertainment',
        date: now.subtract(const Duration(days: 9)),
        paymentMethod: PaymentMethod.upi,
      ),
      Expense(
        id: uuid.v4(),
        title: 'Studio Workspace & Cloud Services',
        amount: 8500.0,
        categoryId: 'bills',
        date: DateTime(now.year, now.month, 1),
        paymentMethod: PaymentMethod.bankTransfer,
        isIncome: false,
        notes: 'Monthly Workspace & Dev Server Infrastructure',
      ),
    ];

    final batch = db.batch();
    for (final item in sampleItems) {
      batch.insert('expenses', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Default budget for current month
    final defaultBudget = Budget(
      id: '${now.year}-${now.month}',
      monthlyLimit: 35000.0,
      month: now.month,
      year: now.year,
      warningThreshold: 0.8,
    );
    batch.insert('budgets', defaultBudget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }
}
