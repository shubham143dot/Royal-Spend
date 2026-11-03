import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/auth/royal_auth_gateway.dart';
import '../../../core/theme/auth_colors.dart';
import 'blue_glass_components.dart';

/// Shows the premium blue glassmorphism password recovery dialog.
Future<void> showBlueForgotPasswordDialog({
  required BuildContext context,
  required RoyalAuthGateway authGateway,
  String initialEmail = '',
  required void Function(String message, {bool isError}) onStatusChanged,
}) async {
  final resetFormKey = GlobalKey<FormState>();
  final resetEmailController = TextEditingController(text: initialEmail);
  final resetEmailFocus = FocusNode();
  bool loading = false;
  String? dialogMessage;
  bool dialogError = true;

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> sendReset(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    if (loading || !(resetFormKey.currentState?.validate() ?? false)) return;
    setDialogState(() {
      loading = true;
      dialogMessage = null;
    });

    try {
      await authGateway.sendPasswordReset(
        email: resetEmailController.text.trim(),
      );
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      onStatusChanged(
        'Password reset instructions were sent to your email.',
        isError: false,
      );
    } on AuthProviderNotConfigured {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        loading = false;
        dialogMessage =
            'Password reset is unavailable until sign-in is connected.';
        dialogError = true;
      });
    } catch (e) {
      if (!dialogContext.mounted) return;
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      setDialogState(() {
        loading = false;
        dialogMessage = raw.isNotEmpty
            ? raw
            : 'We couldn’t send a reset link. Please try again.';
        dialogError = true;
      });
    }
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: !loading,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.1,
            ),
          ),
          title: const Text(
            'Reset your password',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: Form(
            key: resetFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the email address for your account.',
                  style: TextStyle(
                    color: RoyalAuthColors.secondaryText.withValues(alpha: 0.90),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                BlueGlassTextField(
                  controller: resetEmailController,
                  focusNode: resetEmailFocus,
                  label: 'Email address',
                  hint: 'name@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  onFieldSubmitted: (_) => sendReset(dialogContext, setDialogState),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogMessage!,
                    style: TextStyle(
                      color: dialogError
                          ? RoyalAuthColors.errorRed
                          : RoyalAuthColors.successGreen,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: RoyalAuthColors.secondaryText,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () => sendReset(dialogContext, setDialogState),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: RoyalAuthColors.neonCyan,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RoyalAuthColors.neonCyan,
                      ),
                    )
                  : const Text('Send reset link'),
            ),
          ],
        ),
      ),
    ),
  );

  resetEmailController.dispose();
  resetEmailFocus.dispose();
}

