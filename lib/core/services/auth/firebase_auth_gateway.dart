import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'royal_auth_gateway.dart';

/// Production-ready Firebase Authentication gateway for Royal Spend.
class FirebaseAuthGateway implements RoyalAuthGateway {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseAuthGateway({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Stream of user auth state changes.
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed in Firebase user.
  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _ensureUserFirestoreProfile(user);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Sign in failed: ${e.toString().replaceAll("Exception: ", "")}';
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
      final user = credential.user;
      if (user != null) {
        if (name.trim().isNotEmpty) {
          await user.updateDisplayName(name.trim());
        }
        await _createUserFirestoreProfile(
          uid: user.uid,
          name: name.trim(),
          email: user.email ?? email.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Account creation failed: ${e.toString().replaceAll("Exception: ", "")}';
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Password reset failed: ${e.toString().replaceAll("Exception: ", "")}';
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      UserCredential credential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Native Android / iOS Google Sign-In using Google Play Services
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          // User cancelled the Google Account picker dialog
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential authCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(authCredential);
      }

      final user = credential.user;
      if (user != null) {
        await _ensureUserFirestoreProfile(user);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      debugPrint('Native Google Sign-in fallback attempt due to: $e');
      try {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        final credential = await _auth.signInWithProvider(provider);
        final user = credential.user;
        if (user != null) {
          await _ensureUserFirestoreProfile(user);
        }
      } on FirebaseAuthException catch (fe) {
        throw _mapFirebaseAuthError(fe);
      } catch (err) {
        final msg = err.toString().replaceAll('Exception: ', '');
        if (msg.contains('sign_in_canceled') || msg.contains('canceled')) {
          return; // Ignore user cancellation gracefully
        }
        throw 'Google sign-in error: $msg';
      }
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (displayName != null) {
        await user.updateDisplayName(displayName.trim());
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL.trim());
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null) updateData['name'] = displayName.trim();
      if (photoURL != null) updateData['photoURL'] = photoURL.trim();

      await _firestore.collection('users').doc(user.uid).set(
            updateData,
            SetOptions(merge: true),
          );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  /// Uploads a profile image to Firebase Storage and links it to the user's account.
  Future<String> uploadProfileImage(File file) async {
    final user = _auth.currentUser;
    if (user == null) throw 'User not authenticated.';

    try {
      final storageRef = _storage.ref().child('profile_images/${user.uid}/profile.jpg');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': user.uid},
      );

      final uploadTask = await storageRef.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await updateProfile(photoURL: downloadUrl);
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw 'Storage error (${e.code}): ${e.message}';
    } catch (e) {
      throw 'Failed to upload profile picture: $e';
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      // 1. Delete user Firestore documents & subcollections
      final userDoc = _firestore.collection('users').doc(uid);
      const subcollections = [
        'expenses',
        'trips',
        'itinerary_days',
        'itinerary_activities',
        'saved_places',
        'travel_transports',
        'travel_accommodations',
        'travel_checklists',
        'travel_splits',
        'budgets',
      ];

      for (final sub in subcollections) {
        await _deleteSubcollection(userDoc, sub);
      }
      await userDoc.delete();

      // 2. Delete profile image from Storage if exists
      try {
        final storageRef = _storage.ref().child('profile_images/$uid/profile.jpg');
        await storageRef.delete();
      } catch (_) {}

      // 3. Delete user from Firebase Auth
      await user.delete();

      // 4. Sign out from Google
      try {
        if (!kIsWeb) await _googleSignIn.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'For security, please sign out and sign in again before deleting your account.';
      }
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  Future<void> _deleteSubcollection(DocumentReference userDoc, String subName) async {
    try {
      final snapshot = await userDoc.collection(subName).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting subcollection $subName: $e');
    }
  }

  Future<void> _createUserFirestoreProfile({
    required String uid,
    required String name,
    required String email,
    String? photoURL,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'preferences': {
          'currencySymbol': '₹',
          'currencyCode': 'INR',
          'themeMode': 'dark',
          'monthlyBudget': 35000.0,
          'hapticsEnabled': true,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Note: Firestore user profile initialization: $e');
    }
  }

  Future<void> _ensureUserFirestoreProfile(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await _createUserFirestoreProfile(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          photoURL: user.photoURL,
        );
      } else {
        await docRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
          if (user.photoURL != null) 'photoURL': user.photoURL,
        });
      }
    } catch (e) {
      debugPrint('Note: Ensuring Firestore user profile: $e');
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Tap "Create Account" below to register!';
      case 'wrong-password':
        return 'Incorrect password. Please verify and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please verify or create an account.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled in Firebase Console.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
