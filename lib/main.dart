import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/core/services/network/network_status_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/firebase_options.dart';
import 'package:royal_spend/providers/app_lock_provider.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/auth_gate.dart';
import 'package:royal_spend/ui/screens/splash/cinematic_splash_screen.dart';
import 'package:royal_spend/ui/widgets/security/app_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catches unconfigured platform environments)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // Configure Google Maps Android renderer asynchronously (non-blocking for fast cold-start)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest).catchError((e) {
        debugPrint('GoogleMapsFlutterAndroid renderer init note: $e');
        return AndroidMapRenderer.latest;
      });
    }
  }

  // Configure system overlays for iOS/Android edge-to-edge transparent navigation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize core providers concurrently with Future.wait for maximum cold-start performance
  final settingsRepo = SettingsRepository();
  final settingsProvider = SettingsProvider(repository: settingsRepo);
  final expenseProvider = ExpenseProvider();
  final quickLogProvider = QuickLogProvider();
  final travelProvider = TravelProvider();
  final profileImageProvider = ProfileImageProvider();
  final appLockProvider = AppLockProvider(settingsRepo: settingsRepo);

  await Future.wait([
    settingsProvider.init(),
    expenseProvider.init(),
    quickLogProvider.init(),
    travelProvider.init(),
    appLockProvider.init(),
  ]);

  // Start real-time network connectivity monitoring & background sync
  NetworkStatusService.instance.startMonitoring();
  FirestoreSyncService.instance.initAutoSyncMonitoring();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: quickLogProvider),
        ChangeNotifierProvider.value(value: travelProvider),
        ChangeNotifierProvider.value(value: profileImageProvider),
        ChangeNotifierProvider.value(value: appLockProvider),
      ],
      child: const RoyalSpendApp(),
    ),
  );
}

class RoyalSpendApp extends StatelessWidget {
  const RoyalSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const CinematicSplashGate(
        child: AppLockGate(
          child: AuthGate(),
        ),
      ),
    );
  }
}
