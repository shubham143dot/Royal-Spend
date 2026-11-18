import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../providers/app_lock_provider.dart';
import '../../widgets/liquid_pop.dart';

/// Full-screen Native Security Lock Barrier for Royal Spend.
///
/// Prevents any sensitive dashboard, transaction, or travel information
/// from rendering or leaking into app previews until native device authentication succeeds.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appLock = context.read<AppLockProvider>();
        if (appLock.isLocked && !appLock.isAuthenticating) {
          appLock.unlockApp();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appLock = context.watch<AppLockProvider>();

    final bgColor = isDark ? const Color(0xFF0A0C14) : const Color(0xFFF2F4F7);
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Ambient Background Lighting
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo).withValues(alpha: 0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -40,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppColors.royalGold : AppColors.appleOrange).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: const SizedBox.expand(),
              ),
            ),

            // Main Lock Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top App Branding
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF2C2D35), const Color(0xFF181920)]
                                : [Colors.white, const Color(0xFFE8EAF0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.white70,
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            AppConstants.appIconPath,
                            width: 44,
                            height: 44,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              CupertinoIcons.shield_fill,
                              size: 36,
                              color: isDark ? AppColors.royalGold : AppColors.royalIndigo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secured by Device Authentication',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: secondaryTextColor,
                        ),
                      ),

                      const SizedBox(height: 52),

                      // Central Security Emblem
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF141622)
                              : Colors.white.withValues(alpha: 0.90),
                          border: Border.all(
                            color: isDark
                                ? AppColors.appleBlue.withValues(alpha: 0.40)
                                : AppColors.royalIndigo.withValues(alpha: 0.25),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                                  .withValues(alpha: 0.22),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            appLock.securityIcon,
                            size: 52,
                            color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'App Locked',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          appLock.biometricDescription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // Error message pill if authentication was cancelled or failed
                      if (appLock.errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.appleRed.withValues(alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.appleRed.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_circle_fill,
                                size: 16,
                                color: AppColors.appleRed,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  appLock.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.appleRed,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 48),

                      // Unlock Action Button
                      LiquidPop(
                        onTap: () {
                          HapticHelper.mediumImpact();
                          appLock.unlockApp();
                        },
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E5BFF), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E5BFF).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                appLock.isAuthenticating
                                    ? CupertinoIcons.arrow_2_circlepath
                                    : CupertinoIcons.lock_open_fill,
                                size: 19,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                appLock.isAuthenticating ? 'Authenticating...' : 'Unlock Royal Spend',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Privacy Guarantee Note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            size: 13,
                            color: AppColors.appleGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Offline Device Security • 100% Private',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
