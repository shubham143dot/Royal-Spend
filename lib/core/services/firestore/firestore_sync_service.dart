import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../data/database/database_helper.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/itinerary_activity.dart';
import '../../../data/models/itinerary_day.dart';
import '../../../data/models/saved_place.dart';
import '../../../data/models/travel_accommodation.dart';
import '../../../data/models/travel_checklist_item.dart';
import '../../../data/models/travel_split.dart';
import '../../../data/models/travel_transport.dart';
import '../../../data/models/trip.dart';

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
  final DatabaseHelper _dbHelper;

  static final FirestoreSyncService instance = FirestoreSyncService();

  final ValueNotifier<SyncStatus> syncStatus =
      ValueNotifier<SyncStatus>(SyncStatus.online);

  StreamSubscription? _expensesSubscription;
  StreamSubscription? _tripsSubscription;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DatabaseHelper? dbHelper,
  })  : _customFirestore = firestore,
        _customAuth = auth,
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

  String? get currentUserId => _auth?.currentUser?.uid;

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

  // --- Individual Entity Sync (Device-to-Cloud) ---

  Future<void> syncExpense(Expense expense) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final map = expense.toMap();
      map['updatedAtServer'] = FieldValue.serverTimestamp();
      await _userExpensesRef(uid)?.doc(expense.id).set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncExpense note: $e');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userExpensesRef(uid)?.doc(expenseId).delete();
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

  Future<void> deleteTrip(String tripId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _userTripsRef(uid)?.doc(tripId).delete();
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
    } catch (e) {
      debugPrint('Firestore deleteTravelSplit note: $e');
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
  Future<int> pullCloudData(String uid) async {
    int totalPulled = 0;
    final firestore = _firestore;
    if (firestore == null) return 0;

    // 1. Expenses
    try {
      final expensesSnap = await _userExpensesRef(uid)
          ?.get()
          .timeout(const Duration(seconds: 8));
      if (expensesSnap != null) {
        for (final doc in expensesSnap.docs) {
          try {
            final data = doc.data();
            final expense = Expense.fromMap(data);
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
          try {
            final trip = Trip.fromMap(doc.data());
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

    return totalPulled;
  }

  /// Pushes local SQLite records to Cloud Firestore.
  /// Preserves stable UUIDs and uses merge to avoid overwriting or duplicate creation.
  Future<int> pushLocalData(String uid) async {
    int totalPushed = 0;
    final firestore = _firestore;
    if (firestore == null) return 0;

    // 1. Push expenses
    try {
      final localExpenses = await _dbHelper.getAllExpenses();
      for (final exp in localExpenses) {
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
        try {
          await syncTrip(trip);
          totalPushed++;

          final days = await _dbHelper.getDaysForTrip(trip.id);
          for (final day in days) {
            await syncItineraryDay(day);
            totalPushed++;
          }

          final activities = await _dbHelper.getActivitiesForTrip(trip.id);
          for (final act in activities) {
            await syncItineraryActivity(act);
            totalPushed++;
          }

          final places = await _dbHelper.getSavedPlacesForTrip(trip.id);
          for (final place in places) {
            await syncSavedPlace(place);
            totalPushed++;
          }

          final transports = await _dbHelper.getTransportsForTrip(trip.id);
          for (final t in transports) {
            await syncTransport(t);
            totalPushed++;
          }

          final accommodations =
              await _dbHelper.getAccommodationsForTrip(trip.id);
          for (final a in accommodations) {
            await syncAccommodation(a);
            totalPushed++;
          }

          final checklists = await _dbHelper.getChecklistForTrip(trip.id);
          for (final c in checklists) {
            await syncChecklistItem(c);
            totalPushed++;
          }

          final splits = await _dbHelper.getSplitsForTrip(trip.id);
          for (final s in splits) {
            await syncTravelSplit(s);
            totalPushed++;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Firestore push trips note: $e');
    }

    // 3. Current month budget
    try {
      final now = DateTime.now();
      final budget = await _dbHelper.getBudgetForMonth(now.year, now.month);
      if (budget != null) {
        await syncBudget(budget);
        totalPushed++;
      }
    } catch (e) {
      debugPrint('Firestore push budget note: $e');
    }

    return totalPushed;
  }

  /// Full two-way synchronization:
  /// Pulls from cloud first (so returning users or Device B get their data),
  /// then pushes local records that may have been created offline.
  Future<void> syncAll(String uid, {VoidCallback? onRefresh}) async {
    syncStatus.value = SyncStatus.syncing;
    try {
      // 1. Cloud-to-device pull first (graceful timeout)
      try {
        await pullCloudData(uid).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('pullCloudData note: $e');
      }

      // 2. Device-to-cloud push (graceful timeout)
      try {
        await pushLocalData(uid).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('pushLocalData note: $e');
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

  /// Setup real-time listeners for live updates from other devices.
  void setupRealtimeListeners(String uid, {VoidCallback? onDataChanged}) {
    cancelRealtimeListeners();

    try {
      _expensesSubscription = _userExpensesRef(uid)?.snapshots().listen(
        (snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              try {
                final exp = Expense.fromMap(change.doc.data()!);
                await _dbHelper.insertExpense(exp);
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteExpense(change.doc.id);
              } catch (_) {}
            }
          }
          onDataChanged?.call();
        },
        onError: (err) {
          debugPrint('Expenses realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting expenses realtime listener: $e');
    }

    try {
      _tripsSubscription = _userTripsRef(uid)?.snapshots().listen(
        (snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              try {
                final trip = Trip.fromMap(change.doc.data()!);
                await _dbHelper.insertTrip(trip);
              } catch (_) {}
            } else if (change.type == DocumentChangeType.removed) {
              try {
                await _dbHelper.deleteTrip(change.doc.id);
              } catch (_) {}
            }
          }
          onDataChanged?.call();
        },
        onError: (err) {
          debugPrint('Trips realtime listener note (graceful): $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error starting trips realtime listener: $e');
    }
  }

  void cancelRealtimeListeners() {
    _expensesSubscription?.cancel();
    _expensesSubscription = null;
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
  }
}
