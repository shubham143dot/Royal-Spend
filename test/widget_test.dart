import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';

import 'package:royal_spend/providers/travel_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Royal Spend App Smoke Test - Renders main dashboard and floating nav', (WidgetTester tester) async {
    final settingsRepo = SettingsRepository();
    final settingsProvider = SettingsProvider(repository: settingsRepo);
    final expenseProvider = ExpenseProvider();
    final quickLogProvider = QuickLogProvider();
    final travelProvider = TravelProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: quickLogProvider),
          ChangeNotifierProvider.value(value: travelProvider),
        ],
        child: const _TestApp(),
      ),
    );

    await tester.pump();

    // Verify app renders all navigation tabs including Travel
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Verify financial header items exist
    expect(find.text('SPENT THIS MONTH'), findsOneWidget);
    expect(find.text('MONTHLY BUDGET'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const MainNavigationScreen(),
    );
  }
}
