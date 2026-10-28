import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/expense.dart';
import '../data/models/itinerary_activity.dart';
import '../data/models/itinerary_day.dart';
import '../data/models/saved_place.dart';
import '../data/models/travel_accommodation.dart';
import '../data/models/travel_checklist_item.dart';
import '../data/models/travel_split.dart';
import '../data/models/travel_transport.dart';
import '../data/models/trip.dart';
import '../data/repositories/travel_repository.dart';

class TravelProvider extends ChangeNotifier {
  final ITravelRepository _repository;
  static const _uuid = Uuid();

  TravelProvider({ITravelRepository? repository})
      : _repository = repository ?? TravelRepository();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isWorkspaceLoading = false;
  bool get isWorkspaceLoading => _isWorkspaceLoading;

  List<Trip> _trips = [];
  List<Trip> get trips => List.unmodifiable(_trips);

  // Active workspace state (Strictly scoped to the currently selected trip)
  Trip? _selectedTrip;
  Trip? get selectedTrip => _selectedTrip;

  List<ItineraryDay> _currentDays = [];
  List<ItineraryDay> get currentDays => List.unmodifiable(_currentDays);

  ItineraryDay? _selectedDay;
  ItineraryDay? get selectedDay => _selectedDay;

  // Activities keyed by dayId for instant access and zero cross-trip contamination
  Map<String, List<ItineraryActivity>> _activitiesByDay = {};
  Map<String, List<ItineraryActivity>> get activitiesByDay =>
      Map.unmodifiable(_activitiesByDay);

  List<ItineraryActivity> get allSelectedTripActivities =>
      _activitiesByDay.values.expand((list) => list).toList();

  List<SavedPlace> _currentSavedPlaces = [];
  List<SavedPlace> get currentSavedPlaces =>
      List.unmodifiable(_currentSavedPlaces);

  List<TravelTransport> _currentTransports = [];
  List<TravelTransport> get currentTransports =>
      List.unmodifiable(_currentTransports);

  List<TravelAccommodation> _currentAccommodations = [];
  List<TravelAccommodation> get currentAccommodations =>
      List.unmodifiable(_currentAccommodations);

  List<TravelChecklistItem> _currentChecklist = [];
  List<TravelChecklistItem> get currentChecklist =>
      List.unmodifiable(_currentChecklist);

  List<TravelSplit> _currentSplits = [];
  List<TravelSplit> get currentSplits => List.unmodifiable(_currentSplits);

  List<Expense> _currentLinkedExpenses = [];
  List<Expense> get currentLinkedExpenses =>
      List.unmodifiable(_currentLinkedExpenses);

  // Search & Filter
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  TripStatus? _statusFilter;
  TripStatus? get statusFilter => _statusFilter;

  // --- Initializer ---

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await loadTrips();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> initialize() => init();

  Future<void> loadTrips() async {
    _trips = await _repository.getAllTrips();
    notifyListeners();
  }

  // --- Filtered Trips for Dashboard ---

  List<Trip> get filteredTrips {
    return _trips.where((trip) {
      if (_statusFilter != null && trip.status != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = trip.title.toLowerCase().contains(q);
        final matchesDest = trip.destination.toLowerCase().contains(q);
        final matchesDep =
            trip.departureCity?.toLowerCase().contains(q) ?? false;
        if (!matchesTitle && !matchesDest && !matchesDep) return false;
      }
      return true;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(TripStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    notifyListeners();
  }

  // --- Workspace Plan Selection & Strict Isolation ---

  Future<void> selectTrip(String tripId) async {
    _isWorkspaceLoading = true;
    // Wipe previous workspace cache immediately so no stale data leaks
    _selectedTrip = null;
    _currentDays = [];
    _selectedDay = null;
    _activitiesByDay = {};
    _currentSavedPlaces = [];
    _currentTransports = [];
    _currentAccommodations = [];
    _currentChecklist = [];
    _currentSplits = [];
    _currentLinkedExpenses = [];
    notifyListeners();

    final trip = await _repository.getTrip(tripId);
    if (trip == null) {
      _isWorkspaceLoading = false;
      notifyListeners();
      return;
    }

    _selectedTrip = trip;

    // Load all child records isolated strictly to this tripId
    final days = await _repository.getDaysForTrip(tripId);
    _currentDays = days;
    if (_currentDays.isNotEmpty) {
      _selectedDay = _currentDays.first;
    }

    final allActivities = await _repository.getActivitiesForTrip(tripId);
    final Map<String, List<ItineraryActivity>> actMap = {};
    for (final day in days) {
      actMap[day.id] =
          allActivities.where((a) => a.dayId == day.id).toList();
    }
    _activitiesByDay = actMap;

    _currentSavedPlaces = await _repository.getSavedPlacesForTrip(tripId);
    _currentTransports = await _repository.getTransportsForTrip(tripId);
    _currentAccommodations =
        await _repository.getAccommodationsForTrip(tripId);
    _currentChecklist = await _repository.getChecklistForTrip(tripId);
    _currentSplits = await _repository.getSplitsForTrip(tripId);
    _currentLinkedExpenses = await _repository.getExpensesForTrip(tripId);

    _isWorkspaceLoading = false;
    notifyListeners();
  }

  void selectDay(ItineraryDay day) {
    if (_selectedDay?.id == day.id) return;
    _selectedDay = day;
    notifyListeners();
  }

  void clearSelectedTrip() {
    _selectedTrip = null;
    _currentDays = [];
    _selectedDay = null;
    _activitiesByDay = {};
    _currentSavedPlaces = [];
    _currentTransports = [];
    _currentAccommodations = [];
    _currentChecklist = [];
    _currentSplits = [];
    _currentLinkedExpenses = [];
    notifyListeners();
  }

  // --- Trip CRUD & Multi-Plan Operations ---

  Future<Trip> createTrip(
    Trip trip, {
    List<ItineraryDay>? days,
    List<ItineraryActivity>? activities,
    List<SavedPlace>? savedPlaces,
    List<TravelTransport>? transports,
    List<TravelAccommodation>? accommodations,
    List<TravelChecklistItem>? checklists,
  }) async {
    await _repository.addTrip(trip);

    // If days supplied, save them; otherwise auto-generate calendar days
    final finalDays = days ?? [];
    if (finalDays.isEmpty) {
      for (int i = 0; i < trip.calendarDaysCount; i++) {
        final dayNum = i + 1;
        final dayDate = trip.startDate.add(Duration(days: i));
        final day = ItineraryDay(
          id: '${trip.id}_day_$dayNum',
          tripId: trip.id,
          dayNumber: dayNum,
          date: dayDate,
          title: 'Day $dayNum',
        );
        finalDays.add(day);
      }
    }

    for (final day in finalDays) {
      await _repository.addDay(day);
    }

    if (activities != null) {
      for (final act in activities) {
        await _repository.addActivity(act);
      }
    }

    if (savedPlaces != null) {
      for (final place in savedPlaces) {
        await _repository.addSavedPlace(place.copyWith(tripId: trip.id));
      }
    }

    if (transports != null) {
      for (final t in transports) {
        await _repository.addTransport(t.copyWith(tripId: trip.id));
      }
    }

    if (accommodations != null) {
      for (final a in accommodations) {
        await _repository.addAccommodation(a.copyWith(tripId: trip.id));
      }
    }

    if (checklists != null) {
      for (final c in checklists) {
        await _repository.addChecklistItem(c.copyWith(tripId: trip.id));
      }
    }

    await loadTrips();
    return trip;
  }

  Future<void> updateTrip(Trip updatedTrip) async {
    await _repository.updateTrip(updatedTrip);
    if (_selectedTrip?.id == updatedTrip.id) {
      _selectedTrip = updatedTrip;
    }
    await loadTrips();
  }

  Future<void> deleteTrip(String tripId, {bool deleteExpenses = false}) async {
    await _repository.deleteTrip(tripId, deleteExpenses: deleteExpenses);
    if (_selectedTrip?.id == tripId) {
      clearSelectedTrip();
    }
    await loadTrips();
  }

  Future<Trip> duplicateTrip(String sourceTripId) async {
    final sourceTrip = await _repository.getTrip(sourceTripId);
    if (sourceTrip == null) throw Exception('Trip not found');

    final newTripId = _uuid.v4();
    final newTrip = sourceTrip.copyWith(
      id: newTripId,
      title: '${sourceTrip.title} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.addTrip(newTrip);

    // Duplicate days and map old day ID to new day ID
    final oldDays = await _repository.getDaysForTrip(sourceTripId);
    final Map<String, String> dayIdMap = {};

    for (final oldDay in oldDays) {
      final newDayId = '${newTripId}_day_${oldDay.dayNumber}';
      dayIdMap[oldDay.id] = newDayId;
      await _repository.addDay(oldDay.copyWith(
        id: newDayId,
        tripId: newTripId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Duplicate activities
    final oldActivities =
        await _repository.getActivitiesForTrip(sourceTripId);
    for (final oldAct in oldActivities) {
      final newDayId = dayIdMap[oldAct.dayId] ?? '${newTripId}_day_1';
      await _repository.addActivity(oldAct.copyWith(
        id: _uuid.v4(),
        tripId: newTripId,
        dayId: newDayId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Duplicate saved places
    final oldPlaces = await _repository.getSavedPlacesForTrip(sourceTripId);
    for (final p in oldPlaces) {
      await _repository.addSavedPlace(p.copyWith(
        id: _uuid.v4(),
        tripId: newTripId,
        createdAt: DateTime.now(),
      ));
    }

    // Duplicate transports
    final oldTrans = await _repository.getTransportsForTrip(sourceTripId);
    for (final t in oldTrans) {
      await _repository.addTransport(t.copyWith(
        id: _uuid.v4(),
        tripId: newTripId,
        createdAt: DateTime.now(),
      ));
    }

    // Duplicate accommodations
    final oldAccs =
        await _repository.getAccommodationsForTrip(sourceTripId);
    for (final a in oldAccs) {
      await _repository.addAccommodation(a.copyWith(
        id: _uuid.v4(),
        tripId: newTripId,
        createdAt: DateTime.now(),
      ));
    }

    // Duplicate checklist
    final oldChecklist =
        await _repository.getChecklistForTrip(sourceTripId);
    for (final c in oldChecklist) {
      await _repository.addChecklistItem(c.copyWith(
        id: _uuid.v4(),
        tripId: newTripId,
        createdAt: DateTime.now(),
      ));
    }

    await loadTrips();
    return newTrip;
  }

  Future<void> toggleTripArchive(String tripId) async {
    final trip = _trips.firstWhere((t) => t.id == tripId);
    final newStatus = trip.status == TripStatus.archived
        ? TripStatus.upcoming
        : TripStatus.archived;
    await updateTrip(trip.copyWith(status: newStatus));
  }

  // --- Day & Activity Operations ---

  Future<void> addDay(ItineraryDay day) async {
    await _repository.addDay(day);
    if (_selectedTrip != null && day.tripId == _selectedTrip!.id) {
      _currentDays.add(day);
      _currentDays.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      _activitiesByDay[day.id] = [];
      _selectedDay = day;
      notifyListeners();
    }
  }

  Future<void> updateDay(ItineraryDay day) async {
    await _repository.updateDay(day);
    if (_selectedTrip != null && day.tripId == _selectedTrip!.id) {
      final idx = _currentDays.indexWhere((d) => d.id == day.id);
      if (idx != -1) {
        _currentDays[idx] = day;
        if (_selectedDay?.id == day.id) {
          _selectedDay = day;
        }
        notifyListeners();
      }
    }
  }

  Future<void> deleteDay(String dayId) async {
    await _repository.deleteDay(dayId);
    if (_selectedTrip != null) {
      _currentDays.removeWhere((d) => d.id == dayId);
      _activitiesByDay.remove(dayId);
      if (_selectedDay?.id == dayId) {
        _selectedDay = _currentDays.isNotEmpty ? _currentDays.first : null;
      }
      notifyListeners();
    }
  }

  Future<void> addActivity(ItineraryActivity activity) async {
    await _repository.addActivity(activity);
    if (_selectedTrip != null && activity.tripId == _selectedTrip!.id) {
      final list = _activitiesByDay[activity.dayId] ?? [];
      list.add(activity);
      _activitiesByDay[activity.dayId] = list;
      notifyListeners();
    }
  }

  Future<void> updateActivity(ItineraryActivity activity) async {
    await _repository.updateActivity(activity);
    if (_selectedTrip != null && activity.tripId == _selectedTrip!.id) {
      final list = _activitiesByDay[activity.dayId] ?? [];
      final idx = list.indexWhere((a) => a.id == activity.id);
      if (idx != -1) {
        list[idx] = activity;
        _activitiesByDay[activity.dayId] = list;
        notifyListeners();
      }
    }
  }

  Future<void> deleteActivity(String activityId, String dayId) async {
    await _repository.deleteActivity(activityId);
    if (_selectedTrip != null) {
      final list = _activitiesByDay[dayId] ?? [];
      list.removeWhere((a) => a.id == activityId);
      _activitiesByDay[dayId] = list;
      notifyListeners();
    }
  }

  Future<void> moveActivityToDay(
      ItineraryActivity activity, String newDayId) async {
    final oldDayId = activity.dayId;
    final updated = activity.copyWith(dayId: newDayId);
    await _repository.updateActivity(updated);

    if (_selectedTrip != null) {
      _activitiesByDay[oldDayId]?.removeWhere((a) => a.id == activity.id);
      final destList = _activitiesByDay[newDayId] ?? [];
      destList.add(updated);
      _activitiesByDay[newDayId] = destList;
      notifyListeners();
    }
  }

  Future<void> toggleActivityCompletion(ItineraryActivity activity) async {
    final updated = activity.copyWith(isCompleted: !activity.isCompleted);
    await updateActivity(updated);
  }

  // --- Saved Places Operations ---

  Future<void> addSavedPlace(SavedPlace place) async {
    await _repository.addSavedPlace(place);
    if (_selectedTrip != null && place.tripId == _selectedTrip!.id) {
      _currentSavedPlaces.add(place);
      notifyListeners();
    }
  }

  Future<void> deleteSavedPlace(String placeId) async {
    await _repository.deleteSavedPlace(placeId);
    if (_selectedTrip != null) {
      _currentSavedPlaces.removeWhere((p) => p.id == placeId);
      notifyListeners();
    }
  }

  Future<void> toggleSavedPlaceVisited(SavedPlace place) async {
    final updated = place.copyWith(isVisited: !place.isVisited);
    await _repository.updateSavedPlace(updated);
    if (_selectedTrip != null) {
      final idx = _currentSavedPlaces.indexWhere((p) => p.id == place.id);
      if (idx != -1) {
        _currentSavedPlaces[idx] = updated;
        notifyListeners();
      }
    }
  }

  Future<void> promoteSavedPlaceToActivity({
    required SavedPlace place,
    required String dayId,
    required String startTime,
    String? endTime,
    int? durationMinutes,
  }) async {
    final act = ItineraryActivity(
      id: _uuid.v4(),
      tripId: place.tripId,
      dayId: dayId,
      title: place.name,
      placeName: place.name,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      category: ActivityCategory.sightseeing,
      notes: place.locationNotes,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    await addActivity(act);
  }

  // --- Checklist Operations ---

  Future<void> addChecklistItem(TravelChecklistItem item) async {
    await _repository.addChecklistItem(item);
    if (_selectedTrip != null && item.tripId == _selectedTrip!.id) {
      _currentChecklist.add(item);
      notifyListeners();
    }
  }

  Future<void> toggleChecklistItem(TravelChecklistItem item) async {
    final updated = item.copyWith(isCompleted: !item.isCompleted);
    await _repository.updateChecklistItem(updated);
    if (_selectedTrip != null) {
      final idx = _currentChecklist.indexWhere((c) => c.id == item.id);
      if (idx != -1) {
        _currentChecklist[idx] = updated;
        notifyListeners();
      }
    }
  }

  Future<void> deleteChecklistItem(String itemId) async {
    await _repository.deleteChecklistItem(itemId);
    if (_selectedTrip != null) {
      _currentChecklist.removeWhere((c) => c.id == itemId);
      notifyListeners();
    }
  }

  // --- Transport & Accommodation Operations ---

  Future<void> addTransport(TravelTransport transport) async {
    await _repository.addTransport(transport);
    if (_selectedTrip != null && transport.tripId == _selectedTrip!.id) {
      _currentTransports.add(transport);
      notifyListeners();
    }
  }

  Future<void> deleteTransport(String id) async {
    await _repository.deleteTransport(id);
    if (_selectedTrip != null) {
      _currentTransports.removeWhere((t) => t.id == id);
      notifyListeners();
    }
  }

  Future<void> addAccommodation(TravelAccommodation accommodation) async {
    await _repository.addAccommodation(accommodation);
    if (_selectedTrip != null && accommodation.tripId == _selectedTrip!.id) {
      _currentAccommodations.add(accommodation);
      notifyListeners();
    }
  }

  Future<void> deleteAccommodation(String id) async {
    await _repository.deleteAccommodation(id);
    if (_selectedTrip != null) {
      _currentAccommodations.removeWhere((a) => a.id == id);
      notifyListeners();
    }
  }

  // --- Bill Splitting Operations ---

  Future<void> addSplit(TravelSplit split) async {
    await _repository.addSplit(split);
    if (_selectedTrip != null && split.tripId == _selectedTrip!.id) {
      _currentSplits.insert(0, split);
      notifyListeners();
    }
  }

  Future<void> deleteSplit(String id) async {
    await _repository.deleteSplit(id);
    if (_selectedTrip != null) {
      _currentSplits.removeWhere((s) => s.id == id);
      notifyListeners();
    }
  }

  List<SplitSettlement> get settlements =>
      TravelSplit.calculateNetSettlements(_currentSplits);

  // --- Financial & Budget Analytics (Current Trip) ---

  double get estimatedCost {
    double total = 0.0;
    for (final acts in _activitiesByDay.values) {
      for (final a in acts) {
        total += a.estimatedCost;
      }
    }
    for (final t in _currentTransports) {
      total += t.cost;
    }
    for (final a in _currentAccommodations) {
      total += a.cost;
    }
    return total;
  }

  double get actualRecordedSpending {
    return _currentLinkedExpenses.fold(
        0.0, (sum, exp) => sum + (exp.isIncome ? 0.0 : exp.amount));
  }

  double get remainingBudget {
    final b = _selectedTrip?.budget ?? 0.0;
    if (b <= 0) return 0.0;
    return b - actualRecordedSpending;
  }

  double get budgetProgress {
    final b = _selectedTrip?.budget ?? 0.0;
    if (b <= 0) return 0.0;
    return actualRecordedSpending / b;
  }

  double get checklistProgress {
    if (_currentChecklist.isEmpty) return 0.0;
    final done = _currentChecklist.where((c) => c.isCompleted).length;
    return done / _currentChecklist.length;
  }

  Future<void> refreshLinkedExpenses() async {
    if (_selectedTrip == null) return;
    _currentLinkedExpenses =
        await _repository.getExpensesForTrip(_selectedTrip!.id);
    notifyListeners();
  }
}
