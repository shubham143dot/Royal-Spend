import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/ocr/ocr_service.dart';
import 'package:royal_spend/core/services/ocr/receipt_parser.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/firebase_options.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/intro/intro_screen.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catches unconfigured platform environments)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // Configure system overlays for iOS/Android edge-to-edge transparent navigation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarBrightness: Brightness.light,
    ),
  );

  // Initialize Providers and initial check
  final settingsRepo = SettingsRepository();
  final settingsProvider = SettingsProvider(repository: settingsRepo);
  await settingsProvider.init();

  final expenseProvider = ExpenseProvider();
  await expenseProvider.init();

  final quickLogProvider = QuickLogProvider();
  await quickLogProvider.init();

  final travelProvider = TravelProvider();
  await travelProvider.init();

  // If first launch, seed realistic sample transactions for instant showcase
  final hasSeeded = await settingsRepo.hasSeededDemoData();
  if (!hasSeeded && expenseProvider.filteredExpenses.isEmpty) {
    await expenseProvider.seedRealisticSampleData();
    await settingsRepo.setHasSeededDemoData(true);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: quickLogProvider),
        ChangeNotifierProvider.value(value: travelProvider),
        Provider(
          create: (_) => OCRService(parser: ReceiptParser()),
        ),
      ],
      child: const RoyalSpendApp(),
    ),
  );
}

class RoyalSpendApp extends StatelessWidget {
  const RoyalSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isFirstLaunch = settings.isFirstLaunch;

        return MaterialApp(
          title: 'Royal Spend',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: isFirstLaunch
              ? const IntroScreen()
              : const MainNavigationScreen(),
        );
      },
    );
  }
}
