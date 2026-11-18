import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/travel_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_pop.dart';
import '../../widgets/stat_badge.dart';
import '../../widgets/transaction_detail_modal.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/travel/trip_card.dart';
import 'create_plan_wizard_screen.dart';
import 'trip_workspace_screen.dart';

class TravelDashboardScreen extends StatefulWidget {
  const TravelDashboardScreen({super.key});

  @override
  State<TravelDashboardScreen> createState() => _TravelDashboardScreenState();
}

class _TravelDashboardScreenState extends State<TravelDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTrip(String tripId) {
    HapticHelper.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => TripWorkspaceScreen(tripId: tripId),
      ),
    );
  }

  void _openCreatePlan() {
    HapticHelper.mediumImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const CreatePlanWizardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final currency = settings.currencySymbol;
    final travelProvider = context.watch<TravelProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    if (travelProvider.isAdmin != settings.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) travelProvider.setAdminStatus(settings.isAdmin);
      });
    }
    final trips = travelProvider.filteredTrips;

    // Travel financial data
    final allTravelExpenses = expenseProvider.allExpenses
        .where((e) => !e.isIncome && e.tripId != null && e.tripId!.isNotEmpty)
        .toList();
    final totalTravelSpent =
        allTravelExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final recentTravelExpenses = allTravelExpenses.take(4).toList();

    // Active or upcoming trip for spotlight
    final activeTrip = trips
            .where((t) => t.isActiveNow || t.status == TripStatus.inProgress)
            .firstOrNull ??
        trips.where((t) => t.status == TripStatus.upcoming).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        isDark: isDark,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            cacheExtent: 1200.0,
            slivers: [
              // Header Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header: App Brand & Subtitle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Travel Hub',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Explore, schedule, and track trips effortlessly.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatBadge(
                            label: '${trips.length} Plans',
                            icon: CupertinoIcons.airplane,
                            color: isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0D9488),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Travel Overview Stats Card
                      GlassCard(
                        isDark: isDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickStatItem(
                              'Travel Spent',
                              CurrencyFormatter.format(totalTravelSpent,
                                  symbol: currency),
                              CupertinoIcons.creditcard,
                              isDark,
                            ),
                            Container(
                              height: 30,
                              width: 0.8,
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x18000000),
                            ),
                            _buildQuickStatItem(
                              'Active / Planned',
                              '${trips.where((t) => t.status != TripStatus.completed).length}',
                              CupertinoIcons.map_pin_ellipse,
                              isDark,
                            ),
                            Container(
                              height: 30,
                              width: 0.8,
                              color: isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x18000000),
                            ),
                            _buildQuickStatItem(
                              'Completed',
                              '${trips.where((t) => t.status == TripStatus.completed).length}',
                              CupertinoIcons.checkmark_seal_fill,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Active Trip Spotlight Card (if present)
                      if (activeTrip != null) ...[
                        _buildActiveTripSpotlightCard(
                            context, activeTrip, isDark, currency),
                      ],

                      // Prominent "+ Create New Plan" Banner Button
                      LiquidPop(
                        onTap: _openCreatePlan,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppColors.royalGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.royalIndigo
                                    .withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.add_circled_solid,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '+ Plan New Adventure',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x1A000000),
                            width: 0.6,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => travelProvider.setSearchQuery(v),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search trips by title or destination...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      travelProvider.setSearchQuery('');
                                    },
                                    child: const Icon(
                                      CupertinoIcons.clear_circled_solid,
                                      size: 16,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All Plans',
                              isSelected: travelProvider.statusFilter == null,
                              isDark: isDark,
                              onTap: () {
                                HapticHelper.selectionClick();
                                travelProvider.setStatusFilter(null);
                              },
                            ),
                            ...TripStatus.values.map((status) {
                              return _FilterPill(
                                label: status.displayName,
                                isSelected:
                                    travelProvider.statusFilter == status,
                                isDark: isDark,
                                onTap: () {
                                  HapticHelper.selectionClick();
                                  travelProvider.setStatusFilter(status);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section Header: Planned Journeys
              if (trips.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 10.0, 22.0, 6.0),
                    child: Text(
                      'PLANNED JOURNEYS (${trips.length})',
                      style: AppTextStyles.labelUppercase.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

              // Trips List or Empty State
              if (trips.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 30.0),
                    child: GlassCard(
                      isDark: isDark,
                      padding: const EdgeInsets.all(26.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.royalGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.airplane,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your next adventure starts here.',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first travel plan or choose our curated template to get started instantly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Single Prominent Action
                          LiquidPop(
                            onTap: _openCreatePlan,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: AppColors.royalGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.royalIndigo
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.add,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    '+ Create Your First Plan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trip = trips[index];
                        return TripCard(
                          trip: trip,
                          isDark: isDark,
                          onTap: () => _openTrip(trip.id),
                          onEdit: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    CreatePlanWizardScreen(tripToEdit: trip),
                              ),
                            );
                          },
                          onDuplicate: () async {
                            await travelProvider.duplicateTrip(trip.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Trip duplicated as independent plan'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          onArchive: () {
                            travelProvider.toggleTripArchive(trip.id);
                          },
                          onDelete: () {
                            _confirmDeleteTrip(context, trip, travelProvider);
                          },
                        );
                      },
                      childCount: trips.length,
                    ),
                  ),
                ),

              // Recent Travel Expenses Section
              if (recentTravelExpenses.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT TRAVEL EXPENSES (${allTravelExpenses.length})',
                          style: AppTextStyles.labelUppercase.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'By Date',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = recentTravelExpenses[index];
                        return TransactionTile(
                          expense: expense,
                          currencySymbol: currency,
                          isDark: isDark,
                          onTap: () =>
                              TransactionDetailModal.show(context, expense),
                        );
                      },
                      childCount: recentTravelExpenses.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(
      String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? const Color(0xFF10B981) : const Color(0xFF0D9488),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripSpotlightCard(
    BuildContext context,
    Trip trip,
    bool isDark,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: LiquidPop(
        pressedScale: 0.98,
        onTap: () => _openTrip(trip.id),
        child: GlassCard(
          isDark: isDark,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appleGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip.isActiveNow ? 'ACTIVE EXPEDITION' : 'NEXT ADVENTURE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trip.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.location_solid,
                    size: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      trip.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted)),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormatter.formatMedium(trip.startDate)} - ${DateFormatter.formatMedium(trip.endDate)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget: ${CurrencyFormatter.format(trip.budget, symbol: currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Open Workspace →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTrip(
      BuildContext context, Trip trip, TravelProvider provider) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${trip.title}"?'),
        content: const Text(
            'This action permanently deletes this travel plan and its day-by-day itinerary. Financial expense records will remain safe.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteTrip(trip.id);
            },
            child: const Text('Delete Plan'),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: LiquidPop(
        pressedScale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                : (isDark
                    ? AppColors.darkSurface
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x1A000000)),
              width: 0.6,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
