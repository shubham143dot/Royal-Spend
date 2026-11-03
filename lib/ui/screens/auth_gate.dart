import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/firestore/firestore_sync_service.dart';
import '../../providers/expense_provider.dart';
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

  void _triggerSyncIfNeeded(String uid) {
    if (_lastSyncedUid == uid) return;
    _lastSyncedUid = uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final expenseProv = context.read<ExpenseProvider>();
      final travelProv = context.read<TravelProvider>();

      FirestoreSyncService.instance.syncAll(
        uid,
        onRefresh: () {
          expenseProv.refresh();
          travelProv.refresh();
        },
      );

      FirestoreSyncService.instance.setupRealtimeListeners(
        uid,
        onDataChanged: () {
          expenseProv.refresh();
          travelProv.refresh();
        },
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
          _triggerSyncIfNeeded(user.uid);
          return const MainNavigationScreen();
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

