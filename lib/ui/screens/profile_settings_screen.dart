import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth/firebase_auth_gateway.dart';
import '../../core/services/firestore/firestore_sync_service.dart';
import '../../core/services/network/network_status_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/haptic_helper.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_image_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/travel_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/google_brand_icon.dart';
import '../widgets/liquid_pop.dart';
import '../../core/utils/privacy_launcher.dart';
import '../widgets/set_budget_sheet.dart';
import 'auth/login_screen.dart';
import 'intro/intro_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    AppLockProvider? appLock;
    try {
      appLock = context.watch<AppLockProvider>();
    } catch (_) {
      appLock = null;
    }
    final isDark = settings.isDarkMode(context);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        cacheExtent: 1400.0,
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
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: _buildProfileCard(context, settings, isDark),
              ),
            ),
          ),

          // Section 0: Account & Authentication
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Text(
                'ACCOUNT & AUTHENTICATION',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildAccountCard(context, settings, isDark),
              ),
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
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildAppearanceCard(context, settings, isDark),
              ),
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
            child: RepaintBoundary(
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
                      Selector<ExpenseProvider, double>(
                        selector: (_, p) => p.monthlyLimit,
                        builder: (context, monthlyLimit, _) {
                          return _buildSettingsTile(
                            icon: CupertinoIcons.slider_horizontal_3,
                            iconColor: AppColors.appleBlue,
                            title: 'Monthly Budget',
                            trailingText: CurrencyFormatter.format(
                              monthlyLimit,
                              symbol: settings.currencySymbol,
                            ),
                            isDark: isDark,
                            onTap: () => SetBudgetSheet.show(context),
                          );
                        },
                      ),
                    ],
                  ),
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
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
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
                            Flexible(
                              child: Text(
                                'Tactile Haptics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
          ),

          // Section: Security (Native App Lock)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'SECURITY',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildSecurityCard(context, appLock, isDark),
              ),
            ),
          ),

          // Section: Admin Tools (Exclusive to subhamsoudeep@gmail.com)
          if (settings.isAdmin) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                child: Text(
                  'ADMIN TOOLS',
                  style: AppTextStyles.labelUppercase.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          icon: CupertinoIcons.sparkles,
                          iconColor: AppColors.appleOrange,
                          title: 'Load Realistic Sample Data',
                          subtitle: 'Populate expenses across categories',
                          isDark: isDark,
                          onTap: () => _confirmSeedData(context, context.read<ExpenseProvider>()),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsTile(
                          icon: CupertinoIcons.play_circle_fill,
                          iconColor: AppColors.royalGold,
                          title: 'Replay Intro & Brand Video',
                          subtitle: 'Experience the Royal Spend cinematic intro',
                          isDark: isDark,
                          onTap: () {
                            HapticHelper.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const IntroScreen(),
                              ),
                            );
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSettingsTile(
                          icon: CupertinoIcons.trash_fill,
                          iconColor: AppColors.appleRed,
                          title: 'Clear All Expenses',
                          subtitle: 'Permanently remove all local transaction records',
                          isDark: isDark,
                          onTap: () => _confirmClearData(context, context.read<ExpenseProvider>()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Section: Support & Help
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'SUPPORT & HELP',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: CupertinoIcons.question_circle_fill,
                        iconColor: AppColors.appleBlue,
                        title: 'Support & Help',
                        trailingWidget: const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 15,
                          color: AppColors.royalGold,
                        ),
                        isDark: isDark,
                        onTap: () => PrivacyLauncher.openSupportEmail(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Section: Legal & Privacy
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'LEGAL & PRIVACY',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        iconColor: AppColors.royalGold,
                        title: 'Privacy Policy',
                        trailingWidget: const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 15,
                          color: AppColors.royalGold,
                        ),
                        isDark: isDark,
                        onTap: () => PrivacyLauncher.openPrivacyPolicy(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Section: Account Deletion Request
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Text(
                'ACCOUNT DELETION REQUEST',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassCard(
                  isDark: isDark,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: CupertinoIcons.trash_fill,
                        iconColor: AppColors.roseExpense,
                        title: 'Account Deletion Request',
                        trailingWidget: const Icon(
                          CupertinoIcons.arrow_up_right,
                          size: 15,
                          color: AppColors.royalGold,
                        ),
                        isDark: isDark,
                        onTap: () => PrivacyLauncher.openAccountDeletionForm(context),
                      ),
                    ],
                  ),
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
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassCard(
                  isDark: isDark,
                  borderRadius: 24,
                  borderColor: AppColors.royalGold.withValues(alpha: isDark ? 0.22 : 0.18),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.royalGold.withValues(alpha: isDark ? 0.24 : 0.16),
                                isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.royalGold.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.royalGold.withValues(alpha: isDark ? 0.25 : 0.14),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              AppConstants.appLogoPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stack) => const Icon(
                                CupertinoIcons.shield_lefthalf_fill,
                                color: AppColors.royalGold,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Royal Spend',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  letterSpacing: -0.3,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.royalGold.withValues(alpha: isDark ? 0.16 : 0.10),
                                  border: Border.all(
                                    color: AppColors.royalGold.withValues(alpha: 0.38),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'v1.0.0 Personal Finance Edition',
                                  style: TextStyle(
                                    color: AppColors.royalGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 0.8,
                      margin: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            isDark ? AppColors.royalGold.withValues(alpha: 0.3) : AppColors.royalGold.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'Take control of your money and make every journey count. Royal Spend brings together smart expense tracking, effortless travel planning and transparent expense management in one beautifully crafted experience.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        letterSpacing: -0.1,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Designed with privacy, simplicity and performance at its core, your financial records stay securely stored on your device with offline-first functionality.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        letterSpacing: -0.1,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Container(
                      height: 0.8,
                      margin: const EdgeInsets.only(top: 18, bottom: 14),
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.sparkles,
                          size: 14,
                          color: AppColors.royalGold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Crafted with precision by Royal Shubham Pixel Labs.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  User? _getFirebaseUser() {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildProfileCard(BuildContext context, SettingsProvider settings, bool isDark) {
    final user = _getFirebaseUser();
    final isGoogle = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isEmail = user?.providerData.any((p) => p.providerId == 'password') ?? false;
    final displayName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : (settings.userName.isNotEmpty ? settings.userName : 'Royal Member');

    final String subtitleText;
    if (isGoogle) {
      subtitleText = '${user?.email ?? "Google Account"} • Google';
    } else if (isEmail) {
      subtitleText = '${user?.email ?? "Email Account"} • Email & Password';
    } else if (user?.email != null) {
      subtitleText = '${user!.email} • Cloud Account';
    } else if (settings.isAuthenticated) {
      subtitleText = 'Royal Spend • Authenticated';
    } else {
      subtitleText = 'Royal Spend • Local Offline';
    }

    return LiquidPop(
      pressedScale: 0.985,
      onTap: () => _showProfileActions(context, settings),
      child: GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildAvatar(context, settings, user),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const ValueKey('edit_name_button'),
                        onTap: () => _showNameDialog(context, settings),
                        child: Icon(
                          CupertinoIcons.pencil_circle_fill,
                          size: 16,
                          color: AppColors.royalGold.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildAvatar(BuildContext context, SettingsProvider settings, User? user) {
    final photoUrl = user?.photoURL ?? settings.profilePhotoUrl;
    final displayName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : (settings.userName.isNotEmpty ? settings.userName : 'Royal Member');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'R';

    Widget imageContent;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        imageContent = Image.network(
          photoUrl,
          width: 56,
          height: 56,
          cacheWidth: 168,
          cacheHeight: 168,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => _buildFallbackInitial(initial),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.royalGold,
                ),
              ),
            );
          },
        );
      } else {
        imageContent = Image.file(
          File(photoUrl),
          width: 56,
          height: 56,
          cacheWidth: 168,
          cacheHeight: 168,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => _buildFallbackInitial(initial),
        );
      }
    } else {
      imageContent = _buildFallbackInitial(initial);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.royalGold.withValues(alpha: 0.75),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalGold.withValues(alpha: 0.28),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(child: imageContent),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.royalGold,
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.camera_fill,
                size: 10,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.royalGradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showProfileActions(BuildContext context, SettingsProvider settings) {
    HapticHelper.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Profile Settings'),
        message: const Text('Update your profile details and picture'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showNameDialog(context, settings);
            },
            child: const Text('Edit Display Name'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickAndUploadPhoto(context, settings, ImageSource.gallery);
            },
            child: const Text('Choose Photo from Gallery'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickAndUploadPhoto(context, settings, ImageSource.camera);
            },
            child: const Text('Take Photo with Camera'),
          ),
          if (settings.profilePhotoUrl != null || _getFirebaseUser()?.photoURL != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                HapticHelper.mediumImpact();
                await settings.setProfilePhotoUrl(null);
                try {
                  if (Firebase.apps.isNotEmpty) {
                    await FirebaseAuthGateway().updateProfile(photoURL: '');
                  }
                } catch (_) {}
              },
              child: const Text('Remove Photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
    BuildContext context,
    SettingsProvider settings,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB.')),
        );
        return;
      }

      // Save local path immediately for instantaneous UI update
      await settings.setProfilePhotoUrl(file.path);

      // If user is authenticated with Firebase, upload to Storage
      if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
        final gateway = FirebaseAuthGateway();
        final downloadUrl = await gateway.uploadProfileImage(file);
        await settings.setProfilePhotoUrl(downloadUrl);
      }
    } catch (e) {
      debugPrint('Photo upload note: $e');
    }
  }

  Widget _buildAccountCard(BuildContext context, SettingsProvider settings, bool isDark) {
    final user = _getFirebaseUser();
    final isGoogle = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isEmail = user?.providerData.any((p) => p.providerId == 'password') ?? false;
    final userEmail = user?.email ?? settings.userEmail;
    final displayName = user?.displayName;
    final hasDisplayName = displayName != null && displayName.isNotEmpty;

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          if (user != null || (userEmail != null && userEmail.isNotEmpty)) ...[
            ValueListenableBuilder<bool>(
              valueListenable: NetworkStatusService.instance.isOnline,
              builder: (context, isOnline, _) {
                return _buildSettingsTile(
                  icon: isGoogle ? Icons.g_mobiledata_rounded : CupertinoIcons.mail_solid,
                  customLeading: isGoogle
                      ? Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7.5),
                            color: Colors.white,
                          ),
                          child: const Center(child: GoogleBrandIcon(size: 18)),
                        )
                      : null,
                  iconColor: isGoogle ? AppColors.appleBlue : AppColors.royalGold,
                  title: hasDisplayName ? displayName : (userEmail ?? 'Authenticated User'),
                  subtitle: isGoogle
                      ? 'Connected via Google ($userEmail)'
                      : isEmail
                          ? 'Connected via Email & Password ($userEmail)'
                          : (settings.isAdmin
                              ? 'Administrator Account ($userEmail)'
                              : 'Firebase Cloud Account ($userEmail)'),
                  trailingText: settings.isAdmin ? 'Admin' : (isOnline ? 'Active' : 'Offline'),
                  isDark: isDark,
                  onTap: () => _showProfileActions(context, settings),
                );
              },
            ),
            _buildDivider(isDark),
            _buildSettingsTile(
              icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
              iconColor: AppColors.appleGreen,
              title: 'Sync Now',
              subtitle: 'Replicate data across devices with Firebase',
              trailingText: 'Manual',
              isDark: isDark,
              onTap: () async {
                HapticHelper.mediumImpact();
                final expenseProv = context.read<ExpenseProvider>();
                final travelProv = context.read<TravelProvider>();
                if (user != null) {
                  await FirestoreSyncService.instance.syncAll(
                    user.uid,
                    onRefresh: () {
                      expenseProv.refresh();
                      travelProv.refresh();
                    },
                  );
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xE810131E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.royalGold.withValues(alpha: 0.5)),
                      ),
                      content: const Text(
                        'Cloud synchronization complete.',
                        style: TextStyle(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            _buildDivider(isDark),
          ] else ...[
            _buildSettingsTile(
              icon: CupertinoIcons.person_crop_circle_badge_checkmark,
              iconColor: AppColors.royalGold,
              title: 'Sign In / Connect Account',
              subtitle: 'Link Google or Email for Cloud Backup & Sync',
              isDark: isDark,
              onTap: () {
                HapticHelper.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            _buildDivider(isDark),
          ],
          _buildSettingsTile(
            icon: CupertinoIcons.square_arrow_left_fill,
            iconColor: AppColors.appleRed,
            title: 'Log Out',
            titleColor: AppColors.appleRed,
            subtitle: isGoogle
                ? 'Sign out of Google account ($userEmail)'
                : isEmail
                    ? 'Sign out of Email account ($userEmail)'
                    : 'Sign out and return to login screen',
            isDark: isDark,
            onTap: () => _confirmLogout(
              context,
              settings,
              isGoogle: isGoogle,
              isEmail: isEmail,
              email: userEmail,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(
    BuildContext context,
    SettingsProvider settings, {
    bool isGoogle = false,
    bool isEmail = false,
    String? email,
  }) {
    HapticHelper.mediumImpact();

    final accountLabel = isGoogle
        ? 'Google account${email != null ? " ($email)" : ""}'
        : isEmail
            ? 'Email account${email != null ? " ($email)" : ""}'
            : 'active session';

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Log Out of Royal Spend?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Are you sure you want to log out from your $accountLabel?\n\nYour local transactions and travel plans will remain safely preserved on this device.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              HapticHelper.heavyImpact();

              try {
                if (Firebase.apps.isNotEmpty) {
                  await FirebaseAuth.instance.signOut();
                }
              } catch (e) {
                debugPrint('Firebase signOut error: $e');
              }

              FirestoreSyncService.instance.cancelRealtimeListeners();
              await SettingsRepository().setLastUserId(null);
              await DatabaseHelper.instance.clearAllData();
              if (context.mounted) {
                context.read<ProfileImageProvider>().onLogout();
                context.read<ExpenseProvider>().clearAllDataInMemory();
                context.read<TravelProvider>().clearAllDataInMemory();
              }

              await settings.logout();
              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil<void>(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, AppLockProvider? appLock, bool isDark) {
    final isEnabled = appLock?.isAppLockEnabled ?? false;
    final securityIcon = appLock?.securityIcon ?? CupertinoIcons.lock_shield_fill;

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isEnabled
                  ? AppColors.appleGreen
                  : (isDark ? const Color(0xFF2C2D35) : const Color(0xFFE2E4E9)),
            ),
            child: Center(
              child: Icon(
                securityIcon,
                size: 18,
                color: isEnabled
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'App Lock',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? AppColors.appleGreen.withValues(alpha: 0.16)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEnabled ? 'Protected' : 'Off',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isEnabled
                              ? AppColors.appleGreen
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Protect your Royal Spend app using your device's built-in security.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            value: isEnabled,
            activeTrackColor: AppColors.appleGreen,
            onChanged: (val) async {
              HapticHelper.mediumImpact();
              if (appLock == null) return;
              if (val) {
                final success = await appLock.enableAppLock(context);
                if (!success && context.mounted) {
                  final msg = appLock.errorMessage ??
                      'Please set up a screen lock on your device to enable App Lock.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: AppColors.appleRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                final success = await appLock.disableAppLock(context);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Authentication failed. App Lock remains enabled.'),
                      backgroundColor: AppColors.appleRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
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
    Widget? trailingWidget,
    Color? titleColor,
    Widget? customLeading,
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
            customLeading ??
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
                      color: titleColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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
            trailingWidget ??
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
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                await settings.setUserName(val);
                try {
                  if (Firebase.apps.isNotEmpty) {
                    await FirebaseAuthGateway().updateProfile(displayName: val);
                  }
                } catch (_) {}
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
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
}
