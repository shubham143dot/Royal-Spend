import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_pop.dart';
import '../widgets/set_budget_sheet.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final isDark = settings.isDarkMode(context);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Settings',
                style: AppTextStyles.titleLarge.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // User Profile Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: _buildProfileCard(context, settings, isDark),
            ),
          ),

          // Section 1: Appearance (from Reference Image)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Text(
                'APPEARANCE',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildAppearanceCard(context, settings, isDark),
            ),
          ),

          // Section 2: Financial Preferences
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'FINANCIAL PREFERENCES',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: CupertinoIcons.money_dollar,
                      iconColor: AppColors.appleGreen,
                      title: 'Currency',
                      trailingText: '${settings.currencyCode} (${settings.currencySymbol})',
                      isDark: isDark,
                      onTap: () => _showCurrencyDialog(context, settings),
                    ),
                    _buildDivider(isDark),
                    _buildSettingsTile(
                      icon: CupertinoIcons.slider_horizontal_3,
                      iconColor: AppColors.appleBlue,
                      title: 'Monthly Budget',
                      trailingText: CurrencyFormatter.format(
                        expenseProvider.monthlyLimit,
                        symbol: settings.currencySymbol,
                      ),
                      isDark: isDark,
                      onTap: () => SetBudgetSheet.show(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section 3: Tactile Haptics
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'SYSTEM & HAPTICS',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7.5),
                            color: AppColors.applePurple,
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.waveform, size: 17, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Tactile Haptics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      value: settings.hapticsEnabled,
                      activeTrackColor: AppColors.appleGreen,
                      onChanged: (val) {
                        HapticHelper.mediumImpact();
                        settings.setHapticsEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section 4: Data Management
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'DATA MANAGEMENT',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: CupertinoIcons.share,
                      iconColor: AppColors.appleBlue,
                      title: 'Export Transactions',
                      subtitle: 'Copy records as CSV or JSON to clipboard',
                      isDark: isDark,
                      onTap: () => _showExportSheet(context, expenseProvider, settings),
                    ),
                    _buildDivider(isDark),
                    _buildSettingsTile(
                      icon: CupertinoIcons.sparkles,
                      iconColor: AppColors.appleOrange,
                      title: 'Load Realistic Sample Data',
                      subtitle: 'Populate expenses across categories',
                      isDark: isDark,
                      onTap: () => _confirmSeedData(context, expenseProvider),
                    ),
                    _buildDivider(isDark),
                    _buildSettingsTile(
                      icon: CupertinoIcons.trash_fill,
                      iconColor: AppColors.appleRed,
                      title: 'Clear All Expenses',
                      subtitle: 'Permanently remove all local transaction records',
                      isDark: isDark,
                      onTap: () => _confirmClearData(context, expenseProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section 4: About Royal Spend
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'ABOUT',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: AppColors.royalGradient,
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.shield_lefthalf_fill, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                'v${AppConstants.appVersion} • Phase 1 Personal Edition',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Crafted with precision by ${AppConstants.brandName}. Designed to offer a fluid, iOS-inspired glassmorphic financial experience with zero tracking and full offline SQLite local persistence.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, SettingsProvider settings, bool isDark) {
    return LiquidPop(
      pressedScale: 0.985,
      onTap: () => _showNameDialog(context, settings),
      child: GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.royalGradient,
              ),
              child: Center(
                child: Text(
                  settings.userName.isNotEmpty ? settings.userName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Royal Spend • Local Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: isDark ? const Color(0xFF636366) : const Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context, SettingsProvider settings, bool isDark) {
    final activeMode = settings.themeMode;
    final isSystem = activeMode == ThemeMode.system;
    final isLightActive = activeMode == ThemeMode.light || (isSystem && !isDark);
    final isDarkActive = activeMode == ThemeMode.dark || (isSystem && isDark);

    return GlassCard(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhonePreview(
                  label: 'Light',
                  isSelected: isLightActive,
                  isDarkPreview: false,
                  isDark: isDark,
                  onTap: () {
                    HapticHelper.selectionClick();
                    settings.setThemeMode(ThemeMode.light);
                  },
                ),
                _buildPhonePreview(
                  label: 'Dark',
                  isSelected: isDarkActive,
                  isDarkPreview: true,
                  isDark: isDark,
                  onTap: () {
                    HapticHelper.selectionClick();
                    settings.setThemeMode(ThemeMode.dark);
                  },
                ),
              ],
            ),
          ),
          _buildDivider(isDark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Automatic',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                CupertinoSwitch(
                  value: isSystem,
                  activeTrackColor: AppColors.appleGreen,
                  onChanged: (val) {
                    HapticHelper.mediumImpact();
                    if (val) {
                      settings.setThemeMode(ThemeMode.system);
                    } else {
                      settings.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePreview({
    required String label,
    required bool isSelected,
    required bool isDarkPreview,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return LiquidPop(
      pressedScale: 0.95,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 82,
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.appleBlue
                    : (isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6)),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.appleBlue.withValues(alpha: isDark ? 0.35 : 0.20)
                      : (isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x1A000000)),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isDarkPreview
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF8B2516),
                                  Color(0xFF1E2838),
                                  Color(0xFF0F172A),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFFB288),
                                  Color(0xFF75A6FF),
                                  Color(0xFFE2E8F0),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 7,
                    child: Text(
                      '9:41',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: isDarkPreview ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.wifi,
                          size: 7,
                          color: isDarkPreview ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          CupertinoIcons.battery_25,
                          size: 9,
                          color: isDarkPreview ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 24,
                    left: 6,
                    right: 6,
                    child: Column(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isDarkPreview
                                ? const Color(0xD91C1C1E)
                                : const Color(0xE6FFFFFF),
                            border: Border.all(
                              color: isDarkPreview
                                  ? const Color(0x33FFFFFF)
                                  : const Color(0x33000000),
                              width: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: AppColors.appleBlue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 26,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1.5),
                                  color: isDarkPreview ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isDarkPreview
                                ? const Color(0xD91C1C1E)
                                : const Color(0xE6FFFFFF),
                            border: Border.all(
                              color: isDarkPreview
                                  ? const Color(0x33FFFFFF)
                                  : const Color(0x33000000),
                              width: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: AppColors.appleGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 32,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      color: isDarkPreview ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: AppColors.appleOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 24,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      color: isDarkPreview ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.appleBlue : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? AppColors.appleBlue
                    : (isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93)),
                width: 1.5,
              ),
            ),
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: const Center(
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? trailingText,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return LiquidPop(
      pressedScale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.5),
                color: iconColor,
              ),
              child: Center(
                child: Icon(icon, size: 17, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: isDark ? const Color(0xFF636366) : const Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDark ? AppColors.darkSeparator : const Color(0x333C3C43),
      indent: 58,
      endIndent: 0,
    );
  }

  void _showCurrencyDialog(BuildContext context, SettingsProvider settings) {
    final currencies = [
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
      {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
      {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Preferred Currency'),
        actions: currencies.map((c) {
          final isSelected = settings.currencyCode == c['code'];
          return CupertinoActionSheetAction(
            onPressed: () {
              settings.setCurrency(c['symbol']!, c['code']!);
              Navigator.pop(ctx);
            },
            child: Text(
              '${c['symbol']}  ${c['name']} (${c['code']})${isSelected ? ' ✓' : ''}',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.userName);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Update Profile Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Your Name',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                settings.setUserName(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmSeedData(BuildContext context, ExpenseProvider provider) {
    HapticHelper.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Seed Realistic Sample Data?'),
        content: const Text(
          'This will populate your database with realistic expenses across food, travel, bills, and tech along with a monthly budget.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              provider.seedRealisticSampleData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Realistic sample data loaded successfully!')),
              );
            },
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, ExpenseProvider provider) {
    HapticHelper.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear All Transactions?'),
        content: const Text(
          'This will permanently delete all expenses and reset budgets. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All local transactions cleared.')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
  ) {
    HapticHelper.mediumImpact();
    final isDark = settings.isDarkMode(context);
    final expenses = provider.allExpenses;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x4DFFFFFF) : const Color(0x33000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.royalIndigo.withValues(alpha: 0.18),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up_doc_fill,
                          color: AppColors.royalIndigoLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Export Transactions',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export your ${expenses.length} transaction records directly to your clipboard for Excel, Google Sheets, or personal backups.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Option 1: CSV Export
                  LiquidPop(
                    pressedScale: 0.97,
                    onTap: () {
                      HapticHelper.lightImpact();
                      Navigator.pop(ctx);
                      final buffer = StringBuffer();
                      buffer.writeln('Date,Time,Title,Category,Amount,Type,Payment Method,Notes');
                      for (final e in expenses) {
                        final cleanTitle = e.title.replaceAll('"', '""');
                        final cleanNotes = (e.notes ?? '').replaceAll('"', '""');
                        buffer.writeln(
                          '${DateFormatter.formatDate(e.date)},${DateFormatter.formatTime(e.date)},"$cleanTitle",${e.category.name},${e.amount.toStringAsFixed(2)},${e.isIncome ? "Income" : "Expense"},${e.paymentMethod.displayName},"$cleanNotes"',
                        );
                      }
                      Clipboard.setData(ClipboardData(text: buffer.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied ${expenses.length} transactions as CSV to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: GlassDecorations.glassTileDecoration(isDark: isDark),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.vividMint.withValues(alpha: 0.15),
                            ),
                            child: const Icon(CupertinoIcons.table, color: AppColors.vividMint, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copy as CSV Spreadsheet',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Standard comma-separated format for Excel & Numbers',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.vividMint),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Option 2: JSON Export
                  LiquidPop(
                    pressedScale: 0.97,
                    onTap: () {
                      HapticHelper.lightImpact();
                      Navigator.pop(ctx);
                      final jsonList = expenses.map((e) => e.toMap()).toList();
                      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
                      Clipboard.setData(ClipboardData(text: jsonString));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied ${expenses.length} transactions as JSON to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: GlassDecorations.glassTileDecoration(isDark: isDark),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.electricCyan.withValues(alpha: 0.15),
                            ),
                            child: const Icon(CupertinoIcons.chevron_left_slash_chevron_right, color: AppColors.electricCyan, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copy as JSON Backup',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Structured data format for developers and database backups',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.electricCyan),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
