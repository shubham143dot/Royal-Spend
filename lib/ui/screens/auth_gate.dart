import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firestore/firestore_sync_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_image_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/travel_provider.dart';
import 'auth/login_screen.dart';
import 'intro/intro_screen.dart';
import 'main_navigation_screen.dart';

/// Centralized Application Startup and Authentication Gateway for Royal Spend.
///
/// Complete Lifecycle Flow:
/// 1. Fresh installation -> IntroScreen (Intro video plays automatically).
/// 2. After user finishes/skips intro -> hasSeenIntro is stored in SharedPreferences.
/// 3. Existing installation:
///    - If user authenticated with Firebase -> MainNavigationScreen + auto background data sync.
///    - If user logged out -> LoginScreen (Intro video is NOT shown again).
/// 4. Offline session preservation:
///    - Previously logged in users have their session restored locally by Firebase Auth
///      even without internet, navigating to MainNavigationScreen with offline SQLite data.
/// 5. App uninstalled & reinstalled:
///    - SharedPreferences is cleared by OS, resetting hasSeenIntro so intro video displays fresh.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastSyncedUid;
  Timer? _refreshDebounceTimer;

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }

  void _triggerSyncIfNeeded(String uid, String? email) {
    if (_lastSyncedUid == uid) return;
    final previousUid = _lastSyncedUid;
    _lastSyncedUid = uid;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final expenseProv = context.read<ExpenseProvider>();
      final travelProv = context.read<TravelProvider>();
      final settings = context.read<SettingsProvider>();
      final effectiveEmail = email ?? settings.userEmail;
      final isAdmin = AppConstants.isAdmin(effectiveEmail);
      travelProv.setAdminStatus(isAdmin);

      // Sync profile image management state for this authenticated user
      final profileImgProv = context.read<ProfileImageProvider>();
      User? currentUser;
      try {
        if (Firebase.apps.isNotEmpty) currentUser = FirebaseAuth.instance.currentUser;
      } catch (_) {}
      profileImgProv.syncWithAuth(
        firebaseUser: currentUser,
        fallbackUid: uid,
        fallbackEmail: effectiveEmail,
      );

      // If logging in after logout, switching accounts, or first time login on fresh install,
      // clear local tables to guarantee zero cross-account or unauthenticated contamination
      final settingsRepo = SettingsRepository();
      final lastUserId = await settingsRepo.getLastUserId();
      final isNewLoginOrSwitch = (previousUid != null && previousUid != uid) ||
          (lastUserId == null || lastUserId != uid);
      if (isNewLoginOrSwitch) {
        await DatabaseHelper.instance.clearAllData();
        expenseProv.clearAllDataInMemory();
        travelProv.clearAllDataInMemory();
      }
      await settingsRepo.setLastUserId(uid);

      await expenseProv.loadCategoryPreference(userId: uid);

      // Debounce sync refresh so initial Firestore snapshot storm (12 streams)
      // coalesces into at most one refresh instead of lagging the UI thread on launch
      void debouncedRefresh() {
        _refreshDebounceTimer?.cancel();
        _refreshDebounceTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            expenseProv.refresh();
            travelProv.refresh();
          }
        });
      }

      FirestoreSyncService.instance.syncAll(
        uid,
        userEmail: effectiveEmail,
        onRefresh: debouncedRefresh,
      );

      FirestoreSyncService.instance.setupRealtimeListeners(
        uid,
        userEmail: effectiveEmail,
        onDataChanged: debouncedRefresh,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // 1. Fresh installation check (Independent of Firebase Auth)
    if (!settings.hasSeenIntro) {
      return const IntroScreen();
    }

    // 2. Fallback when Firebase is not initialized (e.g. headless tests)
    if (Firebase.apps.isEmpty) {
      return settings.isAuthenticated
          ? const MainNavigationScreen()
          : const LoginScreen();
    }

    // 3. Centralized Firebase Auth Stream monitoring
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user != null) {
          _triggerSyncIfNeeded(user.uid, user.email);
          if (user.email != null && settings.userEmail != user.email) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) settings.setUserEmail(user.email);
            });
          }
          return const MainNavigationScreen();
        }

        // When unauthenticated, reset sync tracking, cancel listeners, and clear active profile image
        if (_lastSyncedUid != null) {
          _lastSyncedUid = null;
          FirestoreSyncService.instance.cancelRealtimeListeners();
          context.read<ProfileImageProvider>().onLogout();
          context.read<ExpenseProvider>().loadCategoryPreference(userId: null);
        }

        // Allow dev demo mode if authenticated locally
        if (settings.isAuthenticated) {
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

