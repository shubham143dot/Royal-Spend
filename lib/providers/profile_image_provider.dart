import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/auth/firebase_auth_gateway.dart';
import '../core/services/profile/profile_image_storage_service.dart';

/// Exhaustive Profile Image States for Email/Password and Google Authentication.
enum ProfileImageState {
  /// State 1: Email/Password user has never uploaded an image. Shows placeholder + camera badge.
  noImage,

  /// State 2: Actively retrieving previously saved local profile image from disk.
  loading,

  /// State 3: User selected an image and it is being validated, processed, and saved.
  uploading,

  /// State 4: Local offline image loaded/uploaded successfully. Camera badge remains visible.
  imageLoaded,

  /// State 5: User replacing an existing profile image with a new selection.
  imageReplacing,

  /// State 6: Stored image is missing or corrupted. Gracefully falls back to placeholder.
  imageError,

  /// State 7: Active user logged out. In-memory state cleared, disk files preserved.
  loggedOut,

  /// State 8: Another account logged in. Memory state refreshed to prevent image leakage.
  accountSwitched,

  /// State 9: Google user with valid photoURL loaded.
  googleImageLoaded,

  /// State 10: Google user without photo or failed to load. Circular initial avatar displayed.
  googleImageFallback,

  /// State 11: Loading Google profile picture from network.
  googleImageLoading,
}

/// Centralized Profile Image State Controller & Provider for Royal Spend.
///
/// Implements account-specific offline storage, Google authentication fallback,
/// reactive app-wide synchronization, and zero-leakage account switching.
class ProfileImageProvider extends ChangeNotifier {
  final ProfileImageStorageService _storageService;
  final ImagePicker _imagePicker;

  ProfileImageProvider({
    ProfileImageStorageService? storageService,
    ImagePicker? imagePicker,
  })  : _storageService = storageService ?? ProfileImageStorageService.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  ProfileImageState _state = ProfileImageState.noImage;
  ProfileImageState get state => _state;

  String? _currentUid;
  String? get currentUid => _currentUid;

  String? _currentEmail;
  String? get currentEmail => _currentEmail;

  String? _displayName;
  String? get displayName => _displayName;

  bool _isGoogleAuth = false;
  bool get isGoogleAuth => _isGoogleAuth;

  File? _localImageFile;
  File? get localImageFile => _localImageFile;

  String? _googlePhotoUrl;
  String? get googlePhotoUrl => _googlePhotoUrl;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Whether the user can edit or upload a profile picture.
  /// Strictly true for Email/Password & Local users with a valid UID, false for Google Auth.
  bool get canEditImage => !_isGoogleAuth && _currentUid != null && _currentUid!.isNotEmpty;

  /// True when an image is being processed or replaced.
  bool get isUploading =>
      _state == ProfileImageState.uploading || _state == ProfileImageState.imageReplacing;

  /// True when reading from local storage or network.
  bool get isLoading =>
      _state == ProfileImageState.loading || _state == ProfileImageState.googleImageLoading;

  /// Syncs the controller state with the active authentication session.
  ///
  /// Safe against race conditions and account switching.
  Future<void> syncWithAuth({
    User? firebaseUser,
    String? fallbackUid,
    String? fallbackEmail,
    String? fallbackName,
    bool? isGoogleOverride,
  }) async {
    final effectiveUid = firebaseUser?.uid ?? fallbackUid;
    final effectiveEmail = firebaseUser?.email ?? fallbackEmail;
    final effectiveName = (firebaseUser?.displayName != null && firebaseUser!.displayName!.isNotEmpty)
        ? firebaseUser.displayName
        : fallbackName;

    final isGoogle = isGoogleOverride ??
        (firebaseUser?.providerData.any((p) => p.providerId == 'google.com') ?? false);

    // 1. User is logged out
    if (effectiveUid == null || effectiveUid.trim().isEmpty) {
      if (_currentUid != null) {
        _state = ProfileImageState.loggedOut;
      } else {
        _state = ProfileImageState.noImage;
      }
      _currentUid = null;
      _currentEmail = null;
      _displayName = null;
      _isGoogleAuth = false;
      _localImageFile = null;
      _googlePhotoUrl = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // 2. Account switched to a different UID
    if (_currentUid != null && _currentUid != effectiveUid) {
      _state = ProfileImageState.accountSwitched;
      _localImageFile = null;
      _googlePhotoUrl = null;
      _errorMessage = null;
      notifyListeners();
    }

    _currentUid = effectiveUid;
    _currentEmail = effectiveEmail;
    _displayName = effectiveName;
    _isGoogleAuth = isGoogle;

    // 3. Google Authentication Handling
    if (isGoogle) {
      _localImageFile = null;
      final photo = firebaseUser?.photoURL;
      if (photo != null && photo.trim().isNotEmpty && (photo.startsWith('http://') || photo.startsWith('https://'))) {
        _googlePhotoUrl = photo.trim();
        _state = ProfileImageState.googleImageLoaded;
      } else {
        _googlePhotoUrl = null;
        _state = ProfileImageState.googleImageFallback;
      }
      notifyListeners();
      return;
    }

    // 4. Email/Password or Local Account Handling
    _googlePhotoUrl = null;
    _state = ProfileImageState.loading;
    notifyListeners();

    try {
      final savedFile = await _storageService.getProfileImageFile(effectiveUid);
      // Double check active UID hasn't switched during async file I/O
      if (_currentUid != effectiveUid) return;

      if (savedFile != null) {
        _localImageFile = savedFile;
        _state = ProfileImageState.imageLoaded;
      } else {
        _localImageFile = null;
        _state = ProfileImageState.noImage;
      }
    } catch (e) {
      debugPrint('ProfileImageProvider: error loading image for $effectiveUid: $e');
      if (_currentUid == effectiveUid) {
        _localImageFile = null;
        _state = ProfileImageState.imageError;
        _errorMessage = e.toString();
      }
    }

    notifyListeners();
  }

  /// Opens the native image picker, processes the selected image, and saves it
  /// locally into account-specific storage.
  Future<bool> pickAndUploadImage({required ImageSource source}) async {
    if (!canEditImage) {
      debugPrint('ProfileImageProvider: Cannot upload image - account is not editable.');
      return false;
    }

    if (isUploading) {
      debugPrint('ProfileImageProvider: Upload already in progress. Ignoring duplicate trigger.');
      return false;
    }

    final targetUid = _currentUid!;
    final previousFile = _localImageFile;
    final isReplacing = previousFile != null;

    _state = isReplacing ? ProfileImageState.imageReplacing : ProfileImageState.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      // Handle user cancellation
      if (picked == null) {
        if (_currentUid == targetUid) {
          _state = isReplacing ? ProfileImageState.imageLoaded : ProfileImageState.noImage;
          notifyListeners();
        }
        return false;
      }

      // Check UID hasn't changed while picker was open
      if (_currentUid != targetUid) {
        debugPrint('ProfileImageProvider: User session changed during image picking. Aborting.');
        return false;
      }

      final sourceFile = File(picked.path);
      final savedFile = await _storageService.saveProfileImage(targetUid, sourceFile);

      if (_currentUid != targetUid) {
        // User changed right after save; clean up saved file to prevent leak
        await _storageService.deleteProfileImage(targetUid);
        return false;
      }

      _localImageFile = savedFile;
      _state = ProfileImageState.imageLoaded;
      _errorMessage = null;

      // Sync profile picture to Firebase Storage and update Firebase Auth & Firestore profile
      if (Firebase.apps.isNotEmpty) {
        unawaited(FirebaseAuthGateway().uploadProfileImage(savedFile).catchError((e) {
          debugPrint('Cloud profile image sync note: $e');
          return '';
        }));
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ProfileImageProvider: failed uploading image: $e');
      if (_currentUid == targetUid) {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', '');
        // Preserve previous image if replacement failed, else fallback to error/noImage
        if (isReplacing && previousFile.existsSync()) {
          _localImageFile = previousFile;
          _state = ProfileImageState.imageLoaded;
        } else {
          _localImageFile = null;
          _state = ProfileImageState.imageError;
        }
        notifyListeners();
      }
      return false;
    }
  }

  /// Removes the uploaded profile picture for the active Email/Password account.
  Future<void> removeImage() async {
    if (!canEditImage || _currentUid == null) return;
    final uid = _currentUid!;

    try {
      await _storageService.deleteProfileImage(uid);
      if (Firebase.apps.isNotEmpty) {
        unawaited(FirebaseAuthGateway().updateProfile(photoURL: '').catchError((_) {}));
      }
      if (_currentUid == uid) {
        _localImageFile = null;
        _state = ProfileImageState.noImage;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ProfileImageProvider: error removing image: $e');
    }
  }

  /// Called when Google profile image network request fails.
  /// Gracefully transitions to the letter initial fallback avatar.
  void onGoogleImageFailed() {
    if (_isGoogleAuth && _state != ProfileImageState.googleImageFallback) {
      _state = ProfileImageState.googleImageFallback;
      notifyListeners();
    }
  }

  /// Clears active profile image in memory on logout.
  /// The local file on disk is preserved so returning to this account restores it.
  void onLogout() {
    _state = ProfileImageState.loggedOut;
    _currentUid = null;
    _currentEmail = null;
    _displayName = null;
    _isGoogleAuth = false;
    _localImageFile = null;
    _googlePhotoUrl = null;
    _errorMessage = null;
    notifyListeners();
  }
}
