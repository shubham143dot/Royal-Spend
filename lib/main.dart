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
      systemNavigationBarIconBrightness: Brightness.light,
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
      ],
      child: const RoyalSpendApp(),
    ),
  );

  Future.microtask(() async {
    try {
      final ocr = MlKitOcrService();
      const testPath = '/data/user/0/com.royalshubham.royalspend.royal_spend/cache/scaled_1000328450.jpg';
      if (await File(testPath).exists()) {
        final res = await ocr.processImage(testPath);
        debugPrint('PROBE 1000328450 RAW: """${res.fullText}"""');
        for (final l in res.lines) {
          debugPrint('PROBE 1000328450 LINE: "${l.text}"');
        }
        final p = ReceiptParser.parse(res.fullText, imagePath: testPath, ocrLines: res.lines);
        debugPrint('PROBE 1000328450 PARSED: amount=${p.amount}, status=${p.amountStatus}, candidates=${p.candidateAmounts}');
      }
      const testPath2 = '/data/user/0/com.royalshubham.royalspend.royal_spend/cache/scaled_1000328449.jpg';
      if (await File(testPath2).exists()) {
        final res2 = await ocr.processImage(testPath2);
        debugPrint('PROBE 1000328449 RAW: """${res2.fullText}"""');
        for (final l in res2.lines) {
          debugPrint('PROBE 1000328449 LINE: "${l.text}"');
        }
        final p2 = ReceiptParser.parse(res2.fullText, imagePath: testPath2, ocrLines: res2.lines);
        debugPrint('PROBE 1000328449 PARSED: amount=${p2.amount}, status=${p2.amountStatus}, merchant=${p2.merchant}, candidates=${p2.candidateAmounts}');
      }
    } catch (e, st) {
      debugPrint('PROBE ERROR: $e\n$st');
    }
  });
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
      home: settings.hasCompletedIntro
          ? const MainNavigationScreen()
          : const IntroScreen(),
    );
  }
}
