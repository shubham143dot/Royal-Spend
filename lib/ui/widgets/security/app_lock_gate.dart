import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_lock_provider.dart';
import '../../screens/security/app_lock_screen.dart';

/// Top-level Security Barrier Gate that wraps the application view hierarchy.
///
/// Ensures that when App Lock is enabled and the app is locked (on cold start or
/// after backgrounding), the native `AppLockScreen` is displayed and no child widgets,
/// transactions, or sensitive financial data are rendered.
class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    AppLockProvider? appLock;
    try {
      appLock = context.watch<AppLockProvider>();
    } catch (_) {
      appLock = null;
    }

    if (appLock != null && appLock.isLocked) {
      return const AppLockScreen();
    }

    return child;
  }
}
