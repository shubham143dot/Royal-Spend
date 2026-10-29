import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'royal_auth_gateway.dart';

/// Production-ready Firebase Authentication gateway for Royal Spend.
class FirebaseAuthGateway implements RoyalAuthGateway {
  final FirebaseAuth _auth;

  FirebaseAuthGateway({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Stream of user auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed in Firebase user.
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    }
  }

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    // In production Flutter, Google Sign-in uses GoogleAuthProvider with popup/redirect
    // on web or google_sign_in on mobile platforms.
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        await _auth.signInWithPopup(googleProvider);
      } else {
        // Fallback for native platforms
        final googleProvider = GoogleAuthProvider();
        await _auth.signInWithProvider(googleProvider);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
