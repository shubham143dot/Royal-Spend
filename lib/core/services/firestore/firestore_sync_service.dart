import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../data/database/database_helper.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../data/models/quick_log_preset.dart';
import '../../../data/models/saved_place.dart';
import '../../../data/models/travel_accommodation.dart';
import '../../../data/models/travel_checklist_item.dart';
import '../../../data/models/travel_split.dart';
import '../../../data/models/travel_transport.dart';
import '../../../data/models/trip.dart';
import '../../../data/repositories/quick_log_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../constants/app_constants.dart';
import '../network/network_status_service.dart';

enum SyncStatus {
  online,
  offline,
  syncing,
  synced,
  error,
}

/// Real-time and batch Cloud Firestore synchronization service for Royal Spend.
/// Handles multi-device data replication, offline queuing, conflict resolution,
/// and bidirectional synchronization between local SQLite and Cloud Firestore.
class FirestoreSyncService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final FirebaseStorage? _customStorage;
  final DatabaseHelper _dbHelper;
  bool _isAutoSyncInitialized = false;

  static final FirestoreSyncService instance = FirestoreSyncService();

  final ValueNotifier<SyncStatus> syncStatus =
      ValueNotifier<SyncStatus>(SyncStatus.online);

  StreamSubscription? _expensesSubscription;
  StreamSubscription? _tripsSubscription;
  StreamSubscription? _budgetsSubscription;
  StreamSubscription? _daysSubscription;
  StreamSubscription? _activitiesSubscription;
  StreamSubscription? _placesSubscription;
  StreamSubscription? _transportsSubscription;
  StreamSubscription? _accommodationsSubscription;
  StreamSubscription? _checklistsSubscription;
  StreamSubscription? _splitsSubscription;
  StreamSubscription? _deletedRecordsSubscription;
  StreamSubscription? _userProfileSubscription;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    DatabaseHelper? dbHelper,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customStorage = storage,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static FirebaseFirestore getFirestoreInstance() {
    return FirebaseFirestore.instance;
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        return getFirestoreInstance();
      }
    } catch (_) {}
    return null;
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  FirebaseStorage? get _storage {
    if (_customStorage != null) return _customStorage;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseStorage.instance;
      }
    } catch (_) {}
    return null;
  }

  String? get currentUserId => _auth?.currentUser?.uid;

  /// Starts listening to real-time network connectivity. Whenever the device transitions
  /// from offline to online, all local pending expenses, trips, itineraries, budgets,
  /// and tombstones are automatically synchronized with Cloud Firestore.
  void initAutoSyncMonitoring() {
    if (_isAutoSyncInitialized) return;
    _isAutoSyncInitialized = true;

    NetworkStatusService.instance.isOnline.addListener(() {
      if (NetworkStatusService.instance.isOnline.value) {
        final uid = currentUserId;
        if (uid != null && uid.isNotEmpty) {
          unawaited(syncAll(uid).catchError((e) {
            debugPrint('AutoSync on reconnect note: $e');
          }));
        }
      }
    });
  }

  // Collection references
  CollectionReference<Map<String, dynamic>>? _userExpensesRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('expenses');

  CollectionReference<Map<String, dynamic>>? _userBudgetsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>>? _userTripsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('trips');

  CollectionReference<Map<String, dynamic>>? _userDaysRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('itinerary_days');

  CollectionReference<Map<String, dynamic>>? _userActivitiesRef(String uid) =>
      _firestore
          ?.collection('users')
          .doc(uid)
          .collection('itinerary_activities');

  CollectionReference<Map<String, dynamic>>? _userPlacesRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('saved_places');

  CollectionReference<Map<String, dynamic>>? _userTransportsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('travel_transports');

  CollectionReference<Map<String, dynamic>>? _userAccommodationsRef(String uid) =>
      _firestore
          ?.collection('users')
          .doc(uid)
          .collection('travel_accommodations');

  CollectionReference<Map<String, dynamic>>? _userChecklistsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('travel_checklists');

  CollectionReference<Map<String, dynamic>>? _userSplitsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('travel_splits');

  CollectionReference<Map<String, dynamic>>? _userDeletedRecordsRef(String uid) =>
      _firestore?.collection('users').doc(uid).collection('deleted_records');

  /// Known sample demo transaction titles generated by seedRealisticSampleData.
  /// Used to strictly isolate and purge fake/demo records so they never contaminate
  /// or overwrite authentic user or admin records in Cloud Firestore or local SQLite.
  static const Set<String> _sampleExpenseTitles = {
    'artisan espresso & croissant',
    'uber premier to client office',
    'whole foods grocery supply',
    'high-speed fiber internet bill',
    'apple developer account renewal',
    'weekend flight ticket to goa',
    'minimalist mechanical keyboard',
    'monthly gym & spa membership',
    'imax cinema - christopher nolan night',
    'studio workspace & cloud services',
  };

  static bool isSampleExpense(Expense expense) {
    return _sampleExpenseTitles.contains(expense.title.trim().toLowerCase());
  }

  // --- Deletion Tombstone Recording in Cloud ---

  // --- User Preferences Sync (Category Selector Scope) ---

  Future<void> saveUserCategoryPreference(String? uid, String scope) async {
    final effectiveUid = uid ?? currentUserId;
    if (effectiveUid == null || effectiveUid.isEmpty) return;
    try {
      await _firestore?.collection('users').doc(effectiveUid).set({
        'selectedCategoryScope': scope,
        'preferences': {
          'categoryScope': scope,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUserCategoryPreference note: $e');
    }
  }

  Future<void> saveUserPreferences(String? uid, Map<String, dynamic> preferences) async {
    final effectiveUid = uid ?? currentUserId;
    if (effectiveUid == null || effectiveUid.isEmpty) return;
    try {
      await _firestore?.collection('users').doc(effectiveUid).set({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUserPreferences note: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserPreferences(String? uid) async {
    final effectiveUid = uid ?? currentUserId;
    if (effectiveUid == null || effectiveUid.isEmpty) return null;
    try {
      final doc = await _firestore?.collection('users').doc(effectiveUid).get();
      if (doc != null && doc.exists) {
        final data = doc.data();
        if (data != null && data['preferences'] is Map) {
          return Map<String, dynamic>.from(data['preferences'] as Map);
        }
      }
    } catch (e) {
      debugPrint('Firestore getUserPreferences note: $e');
    }
    return null;
  }

  Future<String?> getUserCategoryPreference(String? uid) async {
    final effectiveUid = uid ?? currentUserId;
    if (effectiveUid == null || effectiveUid.isEmpty) return null;
    try {
      final doc = await _firestore?.collection('users').doc(effectiveUid).get();
      if (doc != null && doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['selectedCategoryScope'] != null) {
            return data['selectedCategoryScope'].toString();
          }
          final prefs = data['preferences'];
          if (prefs is Map && prefs['categoryScope'] != null) {
            return prefs['categoryScope'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore getUserCategoryPreference note: $e');
    }
    return null;
  }

  Future<void> recordCloudDeletion(String id, String type) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userDeletedRecordsRef(uid)?.doc(id).set({
        'id': id,
        'type': type,
        'deleted_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore recordCloudDeletion note: $e');
    }
  }

  // --- Individual Entity Sync (Device-to-Cloud) ---

  Future<void> syncExpense(Expense expense) async {
    final uid = currentUserId;
    if (uid == null) {
      await _dbHelper.updateExpenseSyncStatus(expense.id, ExpenseSyncStatus.pending);
      return;
    }

    // Account isolation guard
    if (expense.userId != null && expense.userId != uid) {
      return;
    }

    // Never push fake sample transactions to cloud
    if (isSampleExpense(expense)) {
      await _dbHelper.deleteExpense(expense.id);
      return;
    }

    try {
      String? cloudImageUrl = expense.cloudImageUrl;
      if (cloudImageUrl == null && expense.receiptPath != null) {
        final file = File(expense.receiptPath!);
        if (await file.exists()) {
          try {
            final storage = _storage;
            if (storage != null) {
              final ref = storage.ref().child('users/$uid/receipts/${expense.id}.jpg');
              final uploadTask = await ref.putFile(file);
              cloudImageUrl = await uploadTask.ref.getDownloadURL();
            }
          } catch (e) {
            debugPrint('Receipt image upload note: $e');
          }
        }
      }

      final expenseToSync = expense.copyWith(
        userId: uid,
        syncStatus: ExpenseSyncStatus.synced,
        cloudImageUrl: cloudImageUrl,
      );

      final map = expenseToSync.toMap();
      map['updatedAtServer'] = FieldValue.serverTimestamp();
      await _userExpensesRef(uid)?.doc(expense.id).set(map, SetOptions(merge: true));
      await _dbHelper.updateExpenseSyncStatus(
        expense.id,
        ExpenseSyncStatus.synced,
        cloudImageUrl: cloudImageUrl,
      );
    } catch (e) {
      debugPrint('Firestore syncExpense note: $e');
      await _dbHelper.updateExpenseSyncStatus(expense.id, ExpenseSyncStatus.pending);
    }
  }

  /// Synchronizes all pending or previously failed local expenses to Cloud Firestore.
  /// Automatically uploads associated local receipt images to Firebase Storage.
  Future<int> syncPendingExpenses(String uid) async {
    final pending = await _dbHelper.getPendingExpenses(userId: uid);
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    for (final expense in pending) {
      // Account isolation: never push another user's expenses
      if (expense.userId != null && expense.userId != uid) {
        continue;
      }

      // Never push fake sample transactions to cloud
      if (isSampleExpense(expense)) {
        await _dbHelper.deleteExpense(expense.id);
        continue;
      }

      try {
        await _dbHelper.updateExpenseSyncStatus(
          expense.id,
          ExpenseSyncStatus.syncing,
        );

        String? cloudImageUrl = expense.cloudImageUrl;
        if (cloudImageUrl == null && expense.receiptPath != null) {
          final file = File(expense.receiptPath!);
          if (await file.exists()) {
            try {
              final storage = _storage;
              if (storage != null) {
                final ref = storage.ref().child('users/$uid/receipts/${expense.id}.jpg');
                final uploadTask = await ref.putFile(file);
                cloudImageUrl = await uploadTask.ref.getDownloadURL();
              }
            } catch (e) {
              debugPrint('Receipt image upload note: $e');
            }
          }
        }

        final synced = expense.copyWith(
          userId: uid,
          syncStatus: ExpenseSyncStatus.synced,
          cloudImageUrl: cloudImageUrl,
        );

        final map = synced.toMap();
        map['updatedAtServer'] = FieldValue.serverTimestamp();
        await _userExpensesRef(uid)?.doc(expense.id).set(map, SetOptions(merge: true));

        await _dbHelper.updateExpenseSyncStatus(
          expense.id,
          ExpenseSyncStatus.synced,
          cloudImageUrl: cloudImageUrl,
        );
        syncedCount++;
      } catch (e) {
        debugPrint('Error syncing pending expense ${expense.id}: $e');
        await _dbHelper.updateExpenseSyncStatus(
          expense.id,
          ExpenseSyncStatus.failed,
        );
      }
    }
    return syncedCount;
  }

  Future<void> deleteExpense(String expenseId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userExpensesRef(uid)?.doc(expenseId).delete();
      await recordCloudDeletion(expenseId, 'expense');
    } catch (e) {
      debugPrint('Firestore deleteExpense note: $e');
    }
  }

  Future<void> syncBudget(Budget budget) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userBudgetsRef(uid)?.doc(budget.id).set(budget.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncBudget note: $e');
    }
  }

  Future<void> syncTrip(Trip trip) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final map = trip.toMap();
      map['updatedAtServer'] = FieldValue.serverTimestamp();
      await _userTripsRef(uid)?.doc(trip.id).set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncTrip note: $e');
    }
  }

  Future<void> deleteTrip(String tripId, {bool deleteExpenses = false}) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userTripsRef(uid)?.doc(tripId).delete();
      await recordCloudDeletion(tripId, 'trip');

      // Cascade delete all days for this trip in Cloud
      final daysSnap = await _userDaysRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (daysSnap != null) {
        for (final doc in daysSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'day');
        }
      }

      // Cascade delete all activities for this trip in Cloud
      final actsSnap = await _userActivitiesRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (actsSnap != null) {
        for (final doc in actsSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'activity');
        }
      }

      // Cascade delete saved places for this trip in Cloud
      final placesSnap = await _userPlacesRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (placesSnap != null) {
        for (final doc in placesSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'place');
        }
      }

      // Cascade delete transports for this trip in Cloud
      final transSnap = await _userTransportsRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (transSnap != null) {
        for (final doc in transSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'transport');
        }
      }

      // Cascade delete accommodations for this trip in Cloud
      final accSnap = await _userAccommodationsRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (accSnap != null) {
        for (final doc in accSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'accommodation');
        }
      }

      // Cascade delete checklists for this trip in Cloud
      final checkSnap = await _userChecklistsRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (checkSnap != null) {
        for (final doc in checkSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'checklist');
        }
      }

      // Cascade delete splits for this trip in Cloud
      final splitsSnap = await _userSplitsRef(uid)?.where('trip_id', isEqualTo: tripId).get();
      if (splitsSnap != null) {
        for (final doc in splitsSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'split');
        }
      }

      if (deleteExpenses) {
        final expSnap = await _userExpensesRef(uid)?.where('trip_id', isEqualTo: tripId).get();
        if (expSnap != null) {
          for (final doc in expSnap.docs) {
            await doc.reference.delete();
            await recordCloudDeletion(doc.id, 'expense');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore deleteTrip note: $e');
    }
  }

  Future<void> syncItineraryDay(ItineraryDay day) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userDaysRef(uid)?.doc(day.id).set(day.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncItineraryDay note: $e');
    }
  }

  Future<void> deleteItineraryDay(String dayId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userDaysRef(uid)?.doc(dayId).delete();
      await recordCloudDeletion(dayId, 'day');

      final actsSnap = await _userActivitiesRef(uid)?.where('day_id', isEqualTo: dayId).get();
      if (actsSnap != null) {
        for (final doc in actsSnap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'activity');
        }
      }
    } catch (e) {
      debugPrint('Firestore deleteItineraryDay note: $e');
    }
  }

  Future<void> syncItineraryActivity(ItineraryActivity activity) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userActivitiesRef(uid)?.doc(activity.id).set(activity.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncItineraryActivity note: $e');
    }
  }

  Future<void> deleteItineraryActivity(String activityId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userActivitiesRef(uid)?.doc(activityId).delete();
      await recordCloudDeletion(activityId, 'activity');
    } catch (e) {
      debugPrint('Firestore deleteItineraryActivity note: $e');
    }
  }

  Future<void> syncSavedPlace(SavedPlace place) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userPlacesRef(uid)?.doc(place.id).set(place.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncSavedPlace note: $e');
    }
  }

  Future<void> deleteSavedPlace(String placeId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userPlacesRef(uid)?.doc(placeId).delete();
      await recordCloudDeletion(placeId, 'place');
    } catch (e) {
      debugPrint('Firestore deleteSavedPlace note: $e');
    }
  }

  Future<void> syncTransport(TravelTransport transport) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userTransportsRef(uid)?.doc(transport.id).set(transport.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncTransport note: $e');
    }
  }

  Future<void> deleteTransport(String transportId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userTransportsRef(uid)?.doc(transportId).delete();
      await recordCloudDeletion(transportId, 'transport');
    } catch (e) {
      debugPrint('Firestore deleteTransport note: $e');
    }
  }

  Future<void> syncAccommodation(TravelAccommodation accommodation) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userAccommodationsRef(uid)?.doc(accommodation.id).set(accommodation.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncAccommodation note: $e');
    }
  }

  Future<void> deleteAccommodation(String accommodationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userAccommodationsRef(uid)?.doc(accommodationId).delete();
      await recordCloudDeletion(accommodationId, 'accommodation');
    } catch (e) {
      debugPrint('Firestore deleteAccommodation note: $e');
    }
  }

  Future<void> syncChecklistItem(TravelChecklistItem item) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userChecklistsRef(uid)?.doc(item.id).set(item.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncChecklistItem note: $e');
    }
  }

  Future<void> deleteChecklistItem(String itemId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userChecklistsRef(uid)?.doc(itemId).delete();
      await recordCloudDeletion(itemId, 'checklist');
    } catch (e) {
      debugPrint('Firestore deleteChecklistItem note: $e');
    }
  }

  Future<void> syncTravelSplit(TravelSplit split) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userSplitsRef(uid)?.doc(split.id).set(split.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncTravelSplit note: $e');
    }
  }

  Future<void> deleteTravelSplit(String splitId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userSplitsRef(uid)?.doc(splitId).delete();
      await recordCloudDeletion(splitId, 'split');
    } catch (e) {
      debugPrint('Firestore deleteTravelSplit note: $e');
    }
  }

  Future<void> clearAllCloudExpenses() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final snap = await _userExpensesRef(uid)?.get();
      if (snap != null) {
        for (final doc in snap.docs) {
          await doc.reference.delete();
          await recordCloudDeletion(doc.id, 'expense');
        }
      }
    } catch (e) {
      debugPrint('Firestore clearAllCloudExpenses note: $e');
    }
  }

  // --- Real-time Streams ---

  Stream<List<Expense>>? streamExpenses() {
    final uid = currentUserId;
    if (uid == null) return null;
    return _userExpensesRef(uid)?.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList();
    });
  }

  Stream<List<Trip>>? streamTrips() {
    final uid = currentUserId;
    if (uid == null) return null;
    return _userTripsRef(uid)?.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Trip.fromMap(doc.data())).toList();
    });
  }

  // --- Complete Multi-Device Synchronization ---

  /// Pulls all user data from Firestore into local SQLite.
  /// Critical for Device B scenario when user installs app on a second device.
  Future<int> pullCloudData(String uid, {String? userEmail}) async {
    int totalPulled = 0;
    final firestore = _firestore;
    if (firestore == null) return 0;

    // 0. Pull Cloud Tombstones (deleted records) and synchronize with local storage
    try {
      final delSnap = await _userDeletedRecordsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (delSnap != null) {
        for (final doc in delSnap.docs) {
          final data = doc.data();
          final type = data['type'] as String? ?? 'general';
          await _dbHelper.markRecordAsDeleted(doc.id, type);
        }
      }
    } catch (e) {
      debugPrint('Firestore pull deleted_records note: $e');
    }

    final deletedIds = await _dbHelper.getAllDeletedRecordIds();
    final isAdmin = AppConstants.isAdmin(userEmail ?? _auth?.currentUser?.email);

    // 1. Expenses
    try {
      final expensesSnap = await _userExpensesRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (expensesSnap != null) {
        for (final doc in expensesSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            // Document was permanently deleted by user! Purge from cloud
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final data = doc.data();
            final expense = Expense.fromMap(data);
            // Purge contaminated sample item from cloud so user/admin data stays 100% authentic
            if (isSampleExpense(expense)) {
              unawaited(doc.reference.delete().catchError((_) {}));
              continue;
            }
            await _dbHelper.insertExpense(expense);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling expense ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull expenses note: $e');
    }

    // 2. Budgets
    try {
      final budgetsSnap = await _userBudgetsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (budgetsSnap != null) {
        for (final doc in budgetsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final budget = Budget.fromMap(doc.data());
            await _dbHelper.setBudgetForMonth(budget);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling budget ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull budgets note: $e');
    }

    // 3. Trips
    try {
      final tripsSnap = await _userTripsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (tripsSnap != null) {
        for (final doc in tripsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            // Document was permanently deleted by user! Purge from cloud
            unawaited(deleteTrip(doc.id).catchError((_) {}));
            continue;
          }
          try {
            final trip = Trip.fromMap(doc.data());
            // Guard: "Back to Life" trip is restricted strictly to admin!
            if (!isAdmin && AppConstants.isBackToLifeTrip(trip.title, trip.destination)) {
              // Purge from non-admin account in Firestore
              unawaited(deleteTrip(doc.id, deleteExpenses: true).catchError((_) {}));
              continue;
            }
            await _dbHelper.insertTrip(trip);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling trip ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull trips note: $e');
    }

    // 4. Itinerary Days
    try {
      final daysSnap = await _userDaysRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (daysSnap != null) {
        for (final doc in daysSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final day = ItineraryDay.fromMap(doc.data());
            await _dbHelper.insertItineraryDay(day);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling day ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull days note: $e');
    }

    // 5. Itinerary Activities
    try {
      final activitiesSnap = await _userActivitiesRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (activitiesSnap != null) {
        for (final doc in activitiesSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final activity = ItineraryActivity.fromMap(doc.data());
            await _dbHelper.insertActivity(activity);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling activity ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull activities note: $e');
    }

    // 6. Saved Places
    try {
      final placesSnap = await _userPlacesRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (placesSnap != null) {
        for (final doc in placesSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final place = SavedPlace.fromMap(doc.data());
            await _dbHelper.insertSavedPlace(place);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling place ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull places note: $e');
    }

    // 7. Transports
    try {
      final transportsSnap = await _userTransportsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (transportsSnap != null) {
        for (final doc in transportsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final transport = TravelTransport.fromMap(doc.data());
            await _dbHelper.insertTransport(transport);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling transport ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull transports note: $e');
    }

    // 8. Accommodations
    try {
      final accommodationsSnap = await _userAccommodationsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (accommodationsSnap != null) {
        for (final doc in accommodationsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final acc = TravelAccommodation.fromMap(doc.data());
            await _dbHelper.insertAccommodation(acc);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling accommodation ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull accommodations note: $e');
    }

    // 9. Checklists
    try {
      final checklistsSnap = await _userChecklistsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (checklistsSnap != null) {
        for (final doc in checklistsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final item = TravelChecklistItem.fromMap(doc.data());
            await _dbHelper.insertChecklistItem(item);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling checklist ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull checklists note: $e');
    }

    // 10. Travel Splits
    try {
      final splitsSnap = await _userSplitsRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (splitsSnap != null) {
        for (final doc in splitsSnap.docs) {
          if (deletedIds.contains(doc.id)) {
            unawaited(doc.reference.delete().catchError((_) {}));
            continue;
          }
          try {
            final split = TravelSplit.fromMap(doc.data());
            await _dbHelper.insertSplit(split);
            totalPulled++;
          } catch (e) {
            debugPrint('Error pulling split ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore pull splits note: $e');
    }

    // 11. User Profile & Preferences
    try {
      final userDoc = await _firestore
          ?.collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final name = data['displayName'] as String? ?? data['name'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            await SettingsRepository().setUserName(name.trim());
          }
          final photoUrl = data['photoURL'] as String?;
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            await SettingsRepository().setUserProfilePhoto(photoUrl.trim());
          }
          final catScope = data['selectedCategoryScope'] as String?;
          if (catScope != null && catScope.isNotEmpty) {
            await SettingsRepository().setSelectedCategoryScope(catScope, userId: uid);
          }
          final prefs = data['preferences'];
          if (prefs is Map) {
            final theme = prefs['themeMode'] as String?;
            if (theme == 'dark') {
              await SettingsRepository().setThemeMode(ThemeMode.dark);
            } else if (theme == 'light') {
              await SettingsRepository().setThemeMode(ThemeMode.light);
            } else if (theme == 'system') {
              await SettingsRepository().setThemeMode(ThemeMode.system);
            }
            final symbol = prefs['currencySymbol'] as String?;
            final code = prefs['currencyCode'] as String?;
            if (symbol != null && code != null) {
              await SettingsRepository().setCurrencySymbol(symbol, code);
            }
            final monthlyBudget = prefs['monthlyBudget'];
            if (monthlyBudget is num) {
              await SettingsRepository().setMonthlyBudget(monthlyBudget.toDouble());
            }
            final haptics = prefs['hapticsEnabled'];
            if (haptics is bool) {
              await SettingsRepository().setHapticsEnabled(haptics);
            }
            final ql = prefs['quickLogPresets'];
            if (ql is List) {
              final presets = ql
                  .whereType<Map>()
                  .map((m) => QuickLogPreset.fromJson(Map<String, dynamic>.from(m)))
                  .toList();
              await QuickLogRepository().savePresetsLocally(presets);
            }
          }
          totalPulled++;
        }
      }
    } catch (e) {
      debugPrint('Firestore pull user preferences note: $e');
    }

    return totalPulled;
  }

  /// Pushes local SQLite records to Cloud Firestore.
  /// Preserves stable UUIDs and uses merge to avoid overwriting or duplicate creation.
  Future<int> pushLocalData(String uid, {String? userEmail}) async {
    int totalPushed = 0;
    final firestore = _firestore;
    if (firestore == null) return 0;

    final deletedIds = await _dbHelper.getAllDeletedRecordIds();
    final isAdmin = AppConstants.isAdmin(userEmail ?? _auth?.currentUser?.email);

    // Sync local deletion tombstones to cloud
    for (final delId in deletedIds) {
      unawaited(recordCloudDeletion(delId, 'tombstone').catchError((_) {}));
    }

    // 1. Push expenses
    try {
      final localExpenses = await _dbHelper.getAllExpenses();
      for (final exp in localExpenses) {
        if (deletedIds.contains(exp.id)) continue;
        if (isSampleExpense(exp)) {
          // Permanently purge sample expense from local database and NEVER push to cloud
          await _dbHelper.deleteExpense(exp.id);
          continue;
        }
        try {
          await syncExpense(exp);
          totalPushed++;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Firestore push expenses note: $e');
    }

    // 2. Push trips and all associated items
    try {
      final localTrips = await _dbHelper.getAllTrips();
      for (final trip in localTrips) {
        if (deletedIds.contains(trip.id)) continue;
        // Never push "Back to Life" trip into non-admin cloud accounts
        if (!isAdmin && AppConstants.isBackToLifeTrip(trip.title, trip.destination)) {
          continue;
        }
        try {
          await syncTrip(trip);
          totalPushed++;

          final days = await _dbHelper.getDaysForTrip(trip.id);
          for (final day in days) {
            if (deletedIds.contains(day.id)) continue;
            await syncItineraryDay(day);
            totalPushed++;
          }

          final activities = await _dbHelper.getActivitiesForTrip(trip.id);
          for (final act in activities) {
            if (deletedIds.contains(act.id)) continue;
            await syncItineraryActivity(act);
            totalPushed++;
          }

          final places = await _dbHelper.getSavedPlacesForTrip(trip.id);
          for (final place in places) {
            if (deletedIds.contains(place.id)) continue;
            await syncSavedPlace(place);
            totalPushed++;
          }

          final transports = await _dbHelper.getTransportsForTrip(trip.id);
          for (final t in transports) {
            if (deletedIds.contains(t.id)) continue;
            await syncTransport(t);
            totalPushed++;
          }

          final accommodations =
              await _dbHelper.getAccommodationsForTrip(trip.id);
          for (final a in accommodations) {
            if (deletedIds.contains(a.id)) continue;
            await syncAccommodation(a);
            totalPushed++;
          }

          final checklists = await _dbHelper.getChecklistForTrip(trip.id);
          for (final c in checklists) {
            if (deletedIds.contains(c.id)) continue;
            await syncChecklistItem(c);
            totalPushed++;
          }

          final splits = await _dbHelper.getSplitsForTrip(trip.id);
          for (final s in splits) {
            if (deletedIds.contains(s.id)) continue;
            await syncTravelSplit(s);
            totalPushed++;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Firestore push trips note: $e');
    }

    // 3. Budgets
    try {
      final allBudgets = await _dbHelper.getAllBudgets();
      for (final budget in allBudgets) {
        if (deletedIds.contains(budget.id)) continue;
        try {
          await syncBudget(budget);
          totalPushed++;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Firestore push budgets note: $e');
    }

    // 4. User Preferences & Category Scope
    try {
      final settingsRepo = SettingsRepository();
      final currentScope = await settingsRepo.getSelectedCategoryScope(userId: uid);
      final themeMode = await settingsRepo.getThemeMode();
      final currencySymbol = await settingsRepo.getCurrencySymbol();
      final currencyCode = await settingsRepo.getCurrencyCode();
      final monthlyBudget = await settingsRepo.getMonthlyBudget();
      final hapticsEnabled = await settingsRepo.isHapticsEnabled();
      final quickLogPresets = await QuickLogRepository().getPresets();

      await saveUserCategoryPreference(uid, currentScope);
      await saveUserPreferences(uid, {
        'themeMode': themeMode == ThemeMode.dark
            ? 'dark'
            : (themeMode == ThemeMode.light ? 'light' : 'system'),
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'monthlyBudget': monthlyBudget,
        'hapticsEnabled': hapticsEnabled,
        'categoryScope': currentScope,
        'quickLogPresets': quickLogPresets.map((p) => p.toJson()).toList(),
      });
      totalPushed++;
    } catch (e) {
      debugPrint('Firestore push user preferences note: $e');
    }

    return totalPushed;
  }

  /// Full two-way synchronization:
  /// Pulls from cloud first (so returning users or Device B get their data),
  /// then pushes local records that may have been created offline.
  Future<void> syncAll(String uid, {String? userEmail, VoidCallback? onRefresh}) async {
    syncStatus.value = SyncStatus.syncing;
    try {
      // 1. Cloud-to-device pull first (graceful timeout)
      try {
        await pullCloudData(uid, userEmail: userEmail).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('pullCloudData note: $e');
      }

      // 2. Device-to-cloud push (graceful timeout)
      try {
        await pushLocalData(uid, userEmail: userEmail).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('pushLocalData note: $e');
      }

      // 3. Sync pending offline expenses & receipt images
      try {
        await syncPendingExpenses(uid).timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('syncPendingExpenses note: $e');
      }

      onRefresh?.call();
      syncStatus.value = SyncStatus.synced;

      // Revert to online after short confirmation interval
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (syncStatus.value == SyncStatus.synced) {
          syncStatus.value = SyncStatus.online;
        }
      });
    } catch (e) {
      debugPrint('syncAll note: $e');
      onRefresh?.call();
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('unavailable') ||
          msg.contains('offline')) {
        syncStatus.value = SyncStatus.offline;
      } else {
        syncStatus.value = SyncStatus.error;
      }
    }
  }

  /// Setup real-time listeners for live updates from other devices across all elements.
  void setupRealtimeListeners(String uid, {String? userEmail, VoidCallback? onDataChanged}) {
    cancelRealtimeListeners();

    // 1. Expenses Live Listener
    try {
      _expensesSubscription = _userExpensesRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final exp = Expense.fromMap(change.doc.data()!);
                if (isSampleExpense(exp)) {
                  unawaited(change.doc.reference.delete().catchError((_) {}));
                  continue;
                }
                await _dbHelper.insertExpense(exp);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteExpense(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Expenses realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting expenses realtime listener: $e');
    }

    // 2. Trips Live Listener
    try {
      _tripsSubscription = _userTripsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          final isAdmin = AppConstants.isAdmin(userEmail ?? _auth?.currentUser?.email);
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(deleteTrip(change.doc.id).catchError((_) {}));
                continue;
              }
              try {
                final trip = Trip.fromMap(change.doc.data()!);
                if (!isAdmin && AppConstants.isBackToLifeTrip(trip.title, trip.destination)) {
                  unawaited(deleteTrip(trip.id, deleteExpenses: true).catchError((_) {}));
                  continue;
                }
                await _dbHelper.insertTrip(trip);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteTrip(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Trips realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting trips realtime listener: $e');
    }

    // 3. Budgets Live Listener
    try {
      _budgetsSubscription = _userBudgetsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final budget = Budget.fromMap(change.doc.data()!);
                await _dbHelper.setBudgetForMonth(budget);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteBudget(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Budgets realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting budgets realtime listener: $e');
    }

    // 4. Itinerary Days Live Listener
    try {
      _daysSubscription = _userDaysRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final day = ItineraryDay.fromMap(change.doc.data()!);
                await _dbHelper.insertItineraryDay(day);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteItineraryDay(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Days realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting days realtime listener: $e');
    }

    // 5. Itinerary Activities Live Listener
    try {
      _activitiesSubscription = _userActivitiesRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final act = ItineraryActivity.fromMap(change.doc.data()!);
                await _dbHelper.insertActivity(act);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteActivity(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Activities realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting activities realtime listener: $e');
    }

    // 6. Saved Places Live Listener
    try {
      _placesSubscription = _userPlacesRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final place = SavedPlace.fromMap(change.doc.data()!);
                await _dbHelper.insertSavedPlace(place);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteSavedPlace(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Places realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting places realtime listener: $e');
    }

    // 7. Transports Live Listener
    try {
      _transportsSubscription = _userTransportsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final transport = TravelTransport.fromMap(change.doc.data()!);
                await _dbHelper.insertTransport(transport);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteTransport(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Transports realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting transports realtime listener: $e');
    }

    // 8. Accommodations Live Listener
    try {
      _accommodationsSubscription = _userAccommodationsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final acc = TravelAccommodation.fromMap(change.doc.data()!);
                await _dbHelper.insertAccommodation(acc);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteAccommodation(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Accommodations realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting accommodations realtime listener: $e');
    }

    // 9. Checklists Live Listener
    try {
      _checklistsSubscription = _userChecklistsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final item = TravelChecklistItem.fromMap(change.doc.data()!);
                await _dbHelper.insertChecklistItem(item);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteChecklistItem(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Checklists realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting checklists realtime listener: $e');
    }

    // 10. Travel Splits Live Listener
    try {
      _splitsSubscription = _userSplitsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          final deletedIds = await _dbHelper.getAllDeletedRecordIds();
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (deletedIds.contains(change.doc.id)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
                continue;
              }
              try {
                final split = TravelSplit.fromMap(change.doc.data()!);
                await _dbHelper.insertSplit(split);
                hasChanges = true;
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteSplit(change.doc.id);
                hasChanges = true;
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Splits realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting splits realtime listener: $e');
    }

    // 11. Cloud Tombstones (Deleted Records) Live Listener
    try {
      _deletedRecordsSubscription = _userDeletedRecordsRef(uid)?.snapshots().listen(
        (snapshot) async {
          if (snapshot.docChanges.isEmpty) return;
          bool hasChanges = false;
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final id = change.doc.id;
              final data = change.doc.data();
              final type = data?['type'] as String? ?? 'general';
              await _dbHelper.markRecordAsDeleted(id, type);
              hasChanges = true;

              // Cascade delete locally based on type
              try {
                switch (type) {
                  case 'expense':
                    await _dbHelper.deleteExpense(id);
                    break;
                  case 'trip':
                    await _dbHelper.deleteTrip(id);
                    break;
                  case 'day':
                    await _dbHelper.deleteItineraryDay(id);
                    break;
                  case 'activity':
                    await _dbHelper.deleteActivity(id);
                    break;
                  case 'place':
                    await _dbHelper.deleteSavedPlace(id);
                    break;
                  case 'transport':
                    await _dbHelper.deleteTransport(id);
                    break;
                  case 'accommodation':
                    await _dbHelper.deleteAccommodation(id);
                    break;
                  case 'checklist':
                    await _dbHelper.deleteChecklistItem(id);
                    break;
                  case 'split':
                    await _dbHelper.deleteSplit(id);
                    break;
                  case 'budget':
                    await _dbHelper.deleteBudget(id);
                    break;
                }
              } catch (_) {}
            }
          }
          if (hasChanges) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('Deleted records realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting deleted records realtime listener: $e');
    }

    // 12. User Profile & Preferences Live Listener
    try {
      _userProfileSubscription = _firestore?.collection('users').doc(uid).snapshots().listen(
        (docSnap) async {
          if (!docSnap.exists) return;
          final data = docSnap.data();
          if (data == null) return;

          bool changed = false;
          final catScope = data['selectedCategoryScope'] as String?;
          if (catScope != null && catScope.isNotEmpty) {
            final repo = SettingsRepository();
            final current = await repo.getSelectedCategoryScope(userId: uid);
            if (current != catScope) {
              await repo.setSelectedCategoryScope(catScope, userId: uid);
              changed = true;
            }
          }

          final prefs = data['preferences'];
          if (prefs is Map) {
            final repo = SettingsRepository();
            final theme = prefs['themeMode'] as String?;
            if (theme != null) {
              final target = theme == 'dark'
                  ? ThemeMode.dark
                  : (theme == 'light' ? ThemeMode.light : ThemeMode.system);
              final currentTheme = await repo.getThemeMode();
              if (currentTheme != target) {
                await repo.setThemeMode(target);
                changed = true;
              }
            }
            final symbol = prefs['currencySymbol'] as String?;
            final code = prefs['currencyCode'] as String?;
            if (symbol != null && code != null) {
              final curSymbol = await repo.getCurrencySymbol();
              final curCode = await repo.getCurrencyCode();
              if (curSymbol != symbol || curCode != code) {
                await repo.setCurrencySymbol(symbol, code);
                changed = true;
              }
            }
            final monthlyBudget = prefs['monthlyBudget'];
            if (monthlyBudget is num) {
              final curBudget = await repo.getMonthlyBudget();
              if (curBudget != monthlyBudget.toDouble()) {
                await repo.setMonthlyBudget(monthlyBudget.toDouble());
                changed = true;
              }
            }
            final haptics = prefs['hapticsEnabled'];
            if (haptics is bool) {
              final curHaptics = await repo.isHapticsEnabled();
              if (curHaptics != haptics) {
                await repo.setHapticsEnabled(haptics);
                changed = true;
              }
            }
          }

          if (changed) {
            onDataChanged?.call();
          }
        },
        onError: (err) {
          debugPrint('User profile realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting user profile realtime listener: $e');
    }
  }

  void cancelRealtimeListeners() {
    _expensesSubscription?.cancel();
    _expensesSubscription = null;
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
    _budgetsSubscription?.cancel();
    _budgetsSubscription = null;
    _daysSubscription?.cancel();
    _daysSubscription = null;
    _activitiesSubscription?.cancel();
    _activitiesSubscription = null;
    _placesSubscription?.cancel();
    _placesSubscription = null;
    _transportsSubscription?.cancel();
    _transportsSubscription = null;
    _accommodationsSubscription?.cancel();
    _accommodationsSubscription = null;
    _checklistsSubscription?.cancel();
    _checklistsSubscription = null;
    _splitsSubscription?.cancel();
    _splitsSubscription = null;
    _deletedRecordsSubscription?.cancel();
    _deletedRecordsSubscription = null;
    _userProfileSubscription?.cancel();
    _userProfileSubscription = null;
  }
}
