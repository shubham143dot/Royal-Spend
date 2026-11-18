import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import 'haptic_helper.dart';

/// Centralized utility for launching the official online Privacy Policy and legal contacts.
class PrivacyLauncher {
  PrivacyLauncher._();

  /// Directly opens the official Royal Spend Privacy Policy in the device's default web browser.
  static Future<bool> openPrivacyPolicy([BuildContext? context]) async {
    HapticHelper.lightImpact();
    final uri = Uri.parse(AppConstants.privacyPolicyUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;

      // Fallback to in-app / platform default browser
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error opening Privacy Policy: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Privacy Policy: ${AppConstants.privacyPolicyUrl}',
              style: const TextStyle(fontSize: 12),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Opens the default email client addressed to the Royal Spend Privacy Team.
  static Future<bool> contactPrivacyTeam([BuildContext? context]) async {
    HapticHelper.lightImpact();
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: AppConstants.privacyEmail,
      queryParameters: {
        'subject': 'Royal Spend Privacy & Data Inquiry',
      },
    );

    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching mail: $e');
    }

    try {
      final webGmailUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(AppConstants.privacyEmail)}&su=${Uri.encodeComponent("Royal Spend Privacy & Data Inquiry")}',
      );
      return await launchUrl(
        webGmailUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching web Gmail fallback: $e');
    }
    return false;
  }

  /// Opens the default email app / Gmail addressed to Royal Spend Support.
  /// If native intent is unavailable, seamlessly redirects to web Gmail compose.
  static Future<bool> openSupportEmail([BuildContext? context]) async {
    HapticHelper.lightImpact();
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {
        'subject': 'Royal Spend Support & Help Request',
      },
    );

    // 1. Try launching native mail app (Gmail) via externalApplication mode
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching mailto intent: $e');
    }

    // 2. Try launching native mail app with platformDefault mode
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching mailto platformDefault: $e');
    }

    // 3. Fallback: Seamlessly redirect to Gmail web composer in external browser
    try {
      final webGmailUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(AppConstants.supportEmail)}&su=${Uri.encodeComponent("Royal Spend Support & Help Request")}',
      );
      final webLaunched = await launchUrl(
        webGmailUri,
        mode: LaunchMode.externalApplication,
      );
      if (webLaunched) return true;

      return await launchUrl(
        webGmailUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching web Gmail fallback: $e');
    }

    return false;
  }

  /// Directly opens the Google Form for account deletion requests in the external browser.
  static Future<bool> openAccountDeletionForm([BuildContext? context]) async {
    HapticHelper.lightImpact();
    final uri = Uri.parse(AppConstants.accountDeletionFormUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;

      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error opening account deletion form: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account Deletion Request: ${AppConstants.accountDeletionFormUrl}',
              style: const TextStyle(fontSize: 12),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
      return false;
    }
  }
}
