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
import '../../core/services/ocr/receipt_storage_service.dart';

class DatabaseHelper {
  static const String _databaseName = 'royal_spend.db';
  static const int _databaseVersion = 3;

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
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        path = p.join(appSupportDir.path, _databaseName);
      } catch (_) {
        path = inMemoryDatabasePath;
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureSchemaIntegrity(db);
      },
    );
  }

  Future<void> _ensureSchemaIntegrity(DatabaseExecutor db) async {
    try {
      // Verify expenses table and add trip_id and offline sync columns if not exist
      final expenseColumns = await db.rawQuery('PRAGMA table_info(expenses)');
      final hasTripId = expenseColumns.any((col) => col['name'] == 'trip_id');
      if (!hasTripId) {
        await db.execute('ALTER TABLE expenses ADD COLUMN trip_id TEXT;');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_expenses_trip ON expenses (trip_id);');
      }
      if (!expenseColumns.any((col) => col['name'] == 'user_id')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN user_id TEXT;');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses (user_id);');
      }
      if (!expenseColumns.any((col) => col['name'] == 'sync_status')) {
        await db.execute(
            "ALTER TABLE expenses ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';");
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_expenses_sync_status ON expenses (sync_status);');
      }
      if (!expenseColumns.any((col) => col['name'] == 'receipt_path')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN receipt_path TEXT;');
      }
      if (!expenseColumns.any((col) => col['name'] == 'cloud_image_url')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN cloud_image_url TEXT;');
      }
      if (!expenseColumns.any((col) => col['name'] == 'ocr_data')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN ocr_data TEXT;');
      }

      // Ensure all travel tables exist
      await _createTravelTables(db);

      // Verify itinerary_days table columns
      final dayColumns =
          await db.rawQuery('PRAGMA table_info(itinerary_days)');
      final hasStartPlace =
          dayColumns.any((col) => col['name'] == 'start_place_name');
      if (!hasStartPlace && dayColumns.isNotEmpty) {
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN start_place_name TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN start_address TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN start_time TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN start_notes TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN start_type TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN end_place_name TEXT;');
        await db.execute(
            'ALTER TABLE itinerary_days ADD COLUMN end_time TEXT;');
      }

      if (!dayColumns.any((col) => col['name'] == 'start_latitude') && dayColumns.isNotEmpty) {
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN start_latitude REAL;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN start_longitude REAL;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN start_place_id TEXT;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN end_address TEXT;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN end_latitude REAL;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN end_longitude REAL;');
        await db.execute('ALTER TABLE itinerary_days ADD COLUMN end_place_id TEXT;');
      }

      // Verify itinerary_activities table columns
      final actColumns =
          await db.rawQuery('PRAGMA table_info(itinerary_activities)');
      final hasIsOvernight =
          actColumns.any((col) => col['name'] == 'is_overnight');
      if (!hasIsOvernight && actColumns.isNotEmpty) {
        await db.execute(
            'ALTER TABLE itinerary_activities ADD COLUMN is_overnight INTEGER NOT NULL DEFAULT 0;');
      }
      if (!actColumns.any((col) => col['name'] == 'place_id') && actColumns.isNotEmpty) {
        await db.execute(
            'ALTER TABLE itinerary_activities ADD COLUMN place_id TEXT;');
      }

      // Verify saved_places table columns
      final placeColumns =
          await db.rawQuery('PRAGMA table_info(saved_places)');
      if (!placeColumns.any((col) => col['name'] == 'address') && placeColumns.isNotEmpty) {
        await db.execute(
            'ALTER TABLE saved_places ADD COLUMN address TEXT;');
      }
      if (!placeColumns.any((col) => col['name'] == 'place_id') && placeColumns.isNotEmpty) {
        await db.execute(
            'ALTER TABLE saved_places ADD COLUMN place_id TEXT;');
      }

      // Ensure deleted_records table exists for tombstone synchronization
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_records (
          id TEXT PRIMARY KEY,
          record_type TEXT NOT NULL,
          deleted_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_deleted_records_type ON deleted_records (record_type)
      ''');

      // Ensure indexed query performance for date-based retrieval & composite lookups
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (date DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_expenses_trip_date ON expenses (trip_id, date DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses (user_id, date DESC)
      ''');

      // Verify categories
      final catRows =
          await db.rawQuery('SELECT COUNT(*) as count FROM categories');
      final catCount =
          catRows.isNotEmpty ? (catRows.first['count'] as int? ?? 0) : 0;
      if (catCount == 0) {
        final batch = db.batch();
        for (final category in DefaultCategories.categories) {
          batch.insert('categories', category.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('Schema integrity check note: $e');
    }
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
        updated_at INTEGER NOT NULL,
        user_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        receipt_path TEXT,
        cloud_image_url TEXT,
        ocr_data TEXT
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

    await db.execute('''
      CREATE INDEX idx_expenses_user_id ON expenses (user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_sync_status ON expenses (sync_status)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_trip_date ON expenses (trip_id, date DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_user_date ON expenses (user_id, date DESC)
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

    // 5. Tombstones Table for Permanent Deletion Preservation
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id TEXT PRIMARY KEY,
        record_type TEXT NOT NULL,
        deleted_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_deleted_records_type ON deleted_records (record_type)
    ''');
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
        start_place_name TEXT,
        start_address TEXT,
        start_latitude REAL,
        start_longitude REAL,
        start_place_id TEXT,
        start_time TEXT,
        start_notes TEXT,
        start_type TEXT,
        end_place_name TEXT,
        end_address TEXT,
        end_latitude REAL,
        end_longitude REAL,
        end_place_id TEXT,
        end_time TEXT,
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
        place_id TEXT,
        estimated_cost REAL DEFAULT 0.0,
        booking_status TEXT DEFAULT 'unconfirmed',
        booking_reference TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_destination_confirmed INTEGER NOT NULL DEFAULT 1,
        is_overnight INTEGER NOT NULL DEFAULT 0,
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
        address TEXT,
        location_notes TEXT,
        category TEXT DEFAULT 'Sightseeing',
        latitude REAL,
        longitude REAL,
        place_id TEXT,
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
    if (oldVersion < 3) {
      await _ensureSchemaIntegrity(db);
    }
  }

  // --- Expense CRUD Operations ---

  Future<int> insertExpense(Expense expense) async {
    if (await isRecordDeleted(expense.id)) return 0;
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
    try {
      final rows = await db.query(
        'expenses',
        columns: ['receipt_path'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty) {
        final path = rows.first['receipt_path'] as String?;
        if (path != null && path.isNotEmpty) {
          await ReceiptStorageService.instance.deleteReceipt(path);
        }
      }
    } catch (_) {}

    await markRecordAsDeleted(id, 'expense');
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Expense>> getPendingExpenses({String? userId}) async {
    final db = await database;
    final whereClauses = <String>['(sync_status = ? OR sync_status = ?)'];
    final whereArgs = <dynamic>[
      ExpenseSyncStatus.pending.name,
      ExpenseSyncStatus.failed.name,
    ];
    if (userId != null && userId.isNotEmpty) {
      whereClauses.add('(user_id = ? OR user_id IS NULL)');
      whereArgs.add(userId);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> updateExpenseSyncStatus(
    String id,
    ExpenseSyncStatus status, {
    String? cloudImageUrl,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'sync_status': status.name,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (cloudImageUrl != null) {
      values['cloud_image_url'] = cloudImageUrl;
    }
    return await db.update(
      'expenses',
      values,
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

  Future<List<Expense>> getExpensesForDate(DateTime date, {String? tripId, bool? isIncome}) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0, 0).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final conditions = ['date >= ?', 'date <= ?'];
    final args = <dynamic>[start, end];

    if (tripId != null) {
      conditions.add('trip_id = ?');
      args.add(tripId);
    }
    if (isIncome != null) {
      conditions.add('is_income = ?');
      args.add(isIncome ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesForDateRange(DateTime start, DateTime end, {String? tripId, bool? isIncome}) async {
    final db = await database;
    final startEpoch = start.millisecondsSinceEpoch;
    final endEpoch = end.millisecondsSinceEpoch;

    final conditions = ['date >= ?', 'date <= ?'];
    final args = <dynamic>[startEpoch, endEpoch];

    if (tripId != null) {
      conditions.add('trip_id = ?');
      args.add(tripId);
    }
    if (isIncome != null) {
      conditions.add('is_income = ?');
      args.add(isIncome ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: conditions.join(' AND '),
      whereArgs: args,
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

  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  Future<int> setBudgetForMonth(Budget budget) async {
    final db = await database;
    return await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // --- Multi-Trip Travel CRUD Operations ---

  Future<int> insertTrip(Trip trip) async {
    if (await isRecordDeleted(trip.id)) return 0;
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
      // Gather all child IDs to mark as deleted tombstones
      final daysRows = await txn.query('itinerary_days', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final dayIds = daysRows.map((r) => r['id'] as String).toList();

      final actRows = await txn.query('itinerary_activities', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final actIds = actRows.map((r) => r['id'] as String).toList();

      final placeRows = await txn.query('saved_places', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final placeIds = placeRows.map((r) => r['id'] as String).toList();

      final transRows = await txn.query('travel_transports', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final transIds = transRows.map((r) => r['id'] as String).toList();

      final accRows = await txn.query('travel_accommodations', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final accIds = accRows.map((r) => r['id'] as String).toList();

      final checkRows = await txn.query('travel_checklists', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final checkIds = checkRows.map((r) => r['id'] as String).toList();

      final splitRows = await txn.query('travel_splits', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
      final splitIds = splitRows.map((r) => r['id'] as String).toList();

      final now = DateTime.now().millisecondsSinceEpoch;
      final allChildIds = <String>[tripId, ...dayIds, ...actIds, ...placeIds, ...transIds, ...accIds, ...checkIds, ...splitIds];

      if (deleteExpenses) {
        final expRows = await txn.query('expenses', columns: ['id'], where: 'trip_id = ?', whereArgs: [tripId]);
        final expIds = expRows.map((r) => r['id'] as String).toList();
        allChildIds.addAll(expIds);
        await txn.delete('expenses', where: 'trip_id = ?', whereArgs: [tripId]);
      } else {
        // Disassociate expenses safely so financial history remains intact
        await txn.rawUpdate(
          'UPDATE expenses SET trip_id = NULL WHERE trip_id = ?',
          [tripId],
        );
      }

      for (final id in allChildIds) {
        await txn.insert(
          'deleted_records',
          {
            'id': id,
            'record_type': 'travel_cascade',
            'deleted_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
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
    if (await isRecordDeleted(day.id)) return 0;
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
      final actRows = await txn.query('itinerary_activities',
          columns: ['id'], where: 'day_id = ?', whereArgs: [dayId]);
      final actIds = actRows.map((r) => r['id'] as String).toList();
      final now = DateTime.now().millisecondsSinceEpoch;

      await txn.insert(
        'deleted_records',
        {'id': dayId, 'record_type': 'day', 'deleted_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final aid in actIds) {
        await txn.insert(
          'deleted_records',
          {'id': aid, 'record_type': 'activity', 'deleted_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

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
    if (await isRecordDeleted(activity.id)) return 0;
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
    await markRecordAsDeleted(activityId, 'activity');
    return await db.delete(
      'itinerary_activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<void> updateActivitiesSortOrder(List<ItineraryActivity> activities) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < activities.length; i++) {
      batch.update(
        'itinerary_activities',
        {
          'sort_order': i,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [activities[i].id],
      );
    }
    await batch.commit(noResult: true);
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
    if (await isRecordDeleted(place.id)) return 0;
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
    await markRecordAsDeleted(placeId, 'place');
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
    if (await isRecordDeleted(transport.id)) return 0;
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
    await markRecordAsDeleted(transportId, 'transport');
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
    if (await isRecordDeleted(accommodation.id)) return 0;
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
    await markRecordAsDeleted(accommodationId, 'accommodation');
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
    if (await isRecordDeleted(item.id)) return 0;
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
    await markRecordAsDeleted(itemId, 'checklist');
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
    if (await isRecordDeleted(split.id)) return 0;
    final db = await database;
    return await db.insert(
      'travel_splits',
      split.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteSplit(String splitId) async {
    final db = await database;
    await markRecordAsDeleted(splitId, 'split');
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

  // --- Tombstone / Deletion Management ---

  Future<void> markRecordAsDeleted(String id, String recordType) async {
    final db = await database;
    await db.insert(
      'deleted_records',
      {
        'id': id,
        'record_type': recordType,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markRecordsAsDeleted(List<String> ids, String recordType) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      batch.insert(
        'deleted_records',
        {
          'id': id,
          'record_type': recordType,
          'deleted_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> isRecordDeleted(String id) async {
    final db = await database;
    final res = await db.query(
      'deleted_records',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<Set<String>> getAllDeletedRecordIds() async {
    final db = await database;
    final res = await db.query('deleted_records', columns: ['id']);
    return res.map((r) => r['id'] as String).toSet();
  }

  Future<void> unmarkRecordAsDeleted(String id) async {
    final db = await database;
    await db.delete('deleted_records', where: 'id = ?', whereArgs: [id]);
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

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('budgets');
    await db.delete('itinerary_activities');
    await db.delete('itinerary_days');
    await db.delete('saved_places');
    await db.delete('travel_transports');
    await db.delete('travel_accommodations');
    await db.delete('travel_checklists');
    await db.delete('travel_splits');
    await db.delete('trips');
    await db.delete('deleted_records');
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
