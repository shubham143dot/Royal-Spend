import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import 'glass_card.dart';
import 'liquid_pop.dart';

/// Modal bottom sheet presenting the official Privacy Policy for Royal Spend.
/// Fully compliant with Google Play Financial Data Policies, Apple App Store Guidelines,
/// and international privacy regulations (GDPR, CCPA, India DPDP Act).
class PrivacyPolicySheet extends StatelessWidget {
  final bool isDark;

  const PrivacyPolicySheet({super.key, required this.isDark});

  static Future<void> show(BuildContext context, {required bool isDark}) {
    HapticHelper.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => PrivacyPolicySheet(isDark: isDark),
    );
  }

  static const String privacyEmail = 'royalshubhampixellabs@gmail.com';

  Future<void> _contactPrivacyTeam(BuildContext context) async {
    HapticHelper.lightImpact();
    final uri = Uri(
      scheme: 'mailto',
      path: privacyEmail,
      queryParameters: {
        'subject': 'Royal Spend Privacy & Data Inquiry',
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact email: royalshubhampixellabs@gmail.com'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact email: royalshubhampixellabs@gmail.com'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? AppColors.royalGold.withValues(alpha: 0.25)
              : AppColors.royalGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.royalGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalGold.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${AppConstants.appName} • ${AppConstants.brandName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable Policy Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Privacy Guarantee Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.appleGreen : AppColors.vividMint)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDark
                              ? AppColors.appleGreen
                              : AppColors.vividMint)
                          .withValues(alpha: 0.32),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_shield_fill,
                        color:
                            isDark ? AppColors.appleGreen : AppColors.vividMint,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Zero Data Sales • Offline-First Ledger • Hardware-Isolated Biometrics',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.appleGreen
                                : AppColors.vividMint,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _buildPolicySection(
                  title: '1. Overview & Data Sovereignty',
                  icon: CupertinoIcons.info_circle_fill,
                  iconColor: AppColors.appleBlue,
                  content:
                      'Royal Spend is an offline-first personal financial ledger and travel planning application engineered by Royal Shubham Pixel Labs. Your financial transactions, budgets, itineraries, and split balances belong entirely to you. We do not sell your personal data, partner with data brokers, or deliver advertisements.',
                ),

                _buildPolicySection(
                  title: '2. Financial Services Clarification',
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  iconColor: AppColors.appleOrange,
                  content:
                      '• Personal Budgeting Only: Royal Spend is strictly a manual personal expenditure and travel coordination utility.\n'
                      '• No Banking or Loans: The App does NOT offer loans, credit facilities, bank account connections, or investment brokerage.\n'
                      '• No Payment Processing: The App does not transfer money or process card transactions. Group bill split balances are mathematical ledgers for personal convenience.',
                ),

                _buildPolicySection(
                  title: '3. Information We Collect',
                  icon: CupertinoIcons.tray_full_fill,
                  iconColor: AppColors.royalGold,
                  content:
                      '• Account Credentials: Email address and display name when using Google Sign-In or Firebase Authentication.\n'
                      '• Financial Data: Manually entered expense amounts, categories, dates, payment modes, merchant notes, and monthly budget limits.\n'
                      '• Travel Itineraries: Trip destinations, waypoints, schedules, hotel/transport records, and bill-split settlements.\n'
                      '• Profile Picture: Optional user avatar selected from device photos.',
                ),

                _buildPolicySection(
                  title: '4. Biometric App Lock & Device Security',
                  icon: CupertinoIcons.lock_shield_fill,
                  iconColor: AppColors.appleGreen,
                  content:
                      'When App Lock is enabled, Royal Spend invokes native device security APIs (Fingerprint, Face ID, Device PIN/Passcode). The app NEVER accesses, collects, records, or transmits your fingerprint patterns, facial scans, or PINs. Authentication takes place strictly within your device\'s hardware Secure Enclave / TEE.',
                ),

                _buildPolicySection(
                  title: '5. Third-Party Infrastructure',
                  icon: CupertinoIcons.cloud_fill,
                  iconColor: AppColors.appleIndigo,
                  content:
                      '• Google Firebase: User authentication and encrypted Cloud Firestore multi-device synchronization.\n'
                      '• Google Maps Platform: Interactive travel route and waypoint visualization.\n'
                      '• Google Play Services: Core runtime libraries and app distribution.\n'
                      'Notice: Royal Spend contains NO third-party advertising frameworks (e.g. AdMob), tracking cookies, or marketing analytics SDKs.',
                ),

                _buildPolicySection(
                  title: '6. Storage, Encryption & Security',
                  icon: CupertinoIcons.shield_fill,
                  iconColor: AppColors.applePurple,
                  content:
                      'Local data is stored in a private SQLite database file (royal_spend.db) isolated within the operating system sandbox. All cloud communications with Firebase use HTTPS / TLS 1.3 encryption, and data stored in Cloud Firestore is encrypted at rest using AES-256.',
                ),

                _buildPolicySection(
                  title: '7. Your Rights & Account Deletion',
                  icon: CupertinoIcons.person_crop_circle_badge_xmark,
                  iconColor: AppColors.appleRed,
                  content:
                      'In accordance with Google Play standards, GDPR, CCPA, and India DPDP regulations:\n'
                      '• In-App Clear: Purge local database records in Settings at any time.\n'
                      '• Permanent Deletion: To permanently delete your account, authentication record, profile avatar, and all cloud backups, email royalshubhampixellabs@gmail.com with subject "Delete My Royal Spend Account". Data is permanently purged within 30 days.',
                ),

                _buildPolicySection(
                  title: '8. Contact & Grievances',
                  icon: CupertinoIcons.mail_solid,
                  iconColor: AppColors.appleTeal,
                  content:
                      'For privacy inquiries, security questions, or data protection feedback:\n'
                      '• Entity: Royal Shubham Pixel Labs\n'
                      '• Privacy Email: royalshubhampixellabs@gmail.com\n'
                      '• Admin Contact: subhamsoudeep@gmail.com\n'
                      '• Last Updated: November 18, 2026',
                ),

                const SizedBox(height: 16),

                // Button to email Privacy Team
                LiquidPop(
                  onTap: () => _contactPrivacyTeam(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.royalGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.royalGold.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.mail_solid,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Contact Privacy & Support Team',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
