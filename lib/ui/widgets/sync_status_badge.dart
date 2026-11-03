import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/firestore/firestore_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/travel_provider.dart';
import 'liquid_pop.dart';

/// Luxury Glassmorphic Offline & Cloud Synchronization Status Pill.
/// Displays non-intrusive status: Online, Offline, Syncing, Synced, or Error.
/// Allows manual sync on tap with tactile feedback.
class SyncStatusBadge extends StatelessWidget {
  final bool isDark;
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: FirestoreSyncService.instance.syncStatus,
      builder: (context, status, _) {
        final (IconData icon, Color color, String label) = switch (status) {
          SyncStatus.online => (
              Icons.cloud_done_rounded,
              const Color(0xFF34C759),
              'Connected'
            ),
          SyncStatus.syncing => (
              CupertinoIcons.arrow_2_circlepath,
              AppColors.royalGold,
              'Syncing…'
            ),
          SyncStatus.synced => (
              CupertinoIcons.checkmark_seal_fill,
              AppColors.royalGold,
              'All Synced'
            ),
          SyncStatus.offline => (
              Icons.cloud_off_rounded,
              const Color(0xFFFF9F0A),
              'Working Locally'
            ),
          SyncStatus.error => (
              Icons.sync_problem_rounded,
              AppColors.appleRed,
              'Sync Issue'
            ),
        };

        return LiquidPop(
          pressedScale: 0.94,
          onTap: () async {
            HapticHelper.lightImpact();
            final uid = FirestoreSyncService.instance.currentUserId;
            if (uid != null) {
              final expenseProv = context.read<ExpenseProvider>();
              final travelProv = context.read<TravelProvider>();
              await FirestoreSyncService.instance.syncAll(
                uid,
                onRefresh: () {
                  expenseProv.refresh();
                  travelProv.refresh();
                },
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xE810131E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.royalGold.withValues(alpha: 0.5)),
                  ),
                  content: Text(
                    'Sign in to sync your data across devices.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: compact ? 13 : 14, color: color),
                    if (!compact) ...[
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
