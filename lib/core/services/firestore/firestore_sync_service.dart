import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/budget.dart';

/// Real-time and batch Cloud Firestore synchronization service for Royal Spend.
class FirestoreSyncService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _userExpensesRef {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('expenses');
  }

  CollectionReference<Map<String, dynamic>>? get _userBudgetsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('budgets');
  }

  /// Upload or update an expense in Cloud Firestore.
  Future<void> syncExpense(Expense expense) async {
    final ref = _userExpensesRef;
    if (ref == null) return;
    try {
      await ref.doc(expense.id).set(expense.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncExpense error: $e');
    }
  }

  /// Delete an expense from Cloud Firestore.
  Future<void> deleteExpense(String expenseId) async {
    final ref = _userExpensesRef;
    if (ref == null) return;
    try {
      await ref.doc(expenseId).delete();
    } catch (e) {
      debugPrint('Firestore deleteExpense error: $e');
    }
  }

  /// Upload or update a budget in Cloud Firestore.
  Future<void> syncBudget(Budget budget) async {
    final ref = _userBudgetsRef;
    if (ref == null) return;
    try {
      await ref.doc(budget.id).set(budget.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore syncBudget error: $e');
    }
  }

  /// Stream user expenses from Cloud Firestore in real time.
  Stream<List<Expense>>? streamExpenses() {
    final ref = _userExpensesRef;
    if (ref == null) return null;
    return ref.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromMap(doc.data())).toList();
    });
  }
}
