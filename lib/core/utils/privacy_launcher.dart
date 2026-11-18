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
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.privacyEmail,
      queryParameters: {
        'subject': 'Royal Spend Privacy & Data Inquiry',
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[PrivacyLauncher] Error launching mail: $e');
    }

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Contact Privacy Team at: ${AppConstants.privacyEmail}',
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return false;
  }
}
