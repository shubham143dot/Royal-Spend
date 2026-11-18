import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/reports/trip_expense_pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/glass_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/trip_expense_report.dart';
import '../../../providers/travel_provider.dart';
import '../../screens/travel/trip_expense_report_preview_screen.dart';
import '../glass_button.dart';
import '../glass_card.dart';
import '../glass_text_field.dart';
import '../liquid_pop.dart';
import 'quick_travel_expense_sheet.dart';

class BillSplitDialog extends StatefulWidget {
  final String tripId;
  final bool isDark;

  const BillSplitDialog({
    super.key,
    required this.tripId,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required bool isDark,
  }) {
    HapticHelper.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (ctx) => BillSplitDialog(tripId: tripId, isDark: isDark),
    );
  }

  @override
  State<BillSplitDialog> createState() => _BillSplitDialogState();
}

class _BillSplitDialogState extends State<BillSplitDialog> {
  // Trip Report State
  Trip? _trip;
  List<Expense> _tripExpenses = [];
  bool _isLoadingExpenses = true;

  final List<ReportParticipant> _participants = [];
  ReportParticipant? _selectedPayer;

  // Add Participant Inputs
  bool _showAddParticipantForm = false;
  final _addNameController = TextEditingController();
  final _addEmailController = TextEditingController();
  String? _participantInputError;

  bool _isSavingPdf = false;

  @override
  void initState() {
    super.initState();
    _initTripData();
  }

  Future<void> _initTripData() async {
    final travelProv = context.read<TravelProvider>();
    _trip = travelProv.selectedTrip ??
        travelProv.trips.where((t) => t.id == widget.tripId).firstOrNull;

    // Initialize participants from trip travelers
    if (_trip != null && _trip!.travelersNames.isNotEmpty) {
      for (final name in _trip!.travelersNames) {
        if (name.trim().isNotEmpty && _participants.length < 15) {
          _participants.add(
            ReportParticipant(
              id: const Uuid().v4(),
              name: name.trim(),
            ),
          );
        }
      }
    }

    if (_participants.isEmpty) {
      _participants.add(
        ReportParticipant(
          id: const Uuid().v4(),
          name: 'You',
        ),
      );
    }

    _selectedPayer = _participants.first;

    await _loadTripExpenses();
  }

  Future<void> _loadTripExpenses() async {
    setState(() => _isLoadingExpenses = true);
    try {
      final travelProv = context.read<TravelProvider>();
      final list = await travelProv.getExpensesForTrip(widget.tripId);
      // Filter strictly to non-deleted expenses for this trip and sort chronologically
      final expenses = list.where((e) => !e.isIncome).toList();
      expenses.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _tripExpenses = expenses;
          _isLoadingExpenses = false;
        });
      }
    } catch (e) {
      debugPrint('[BillSplitDialog] Error loading trip expenses: $e');
      if (mounted) {
        setState(() => _isLoadingExpenses = false);
      }
    }
  }

  @override
  void dispose() {
    _addNameController.dispose();
    _addEmailController.dispose();
    super.dispose();
  }

  double get _totalTripExpenses =>
      _tripExpenses.fold(0.0, (sum, exp) => sum + exp.amount);

  double get _individualShare => _participants.isNotEmpty
      ? (_totalTripExpenses / _participants.length)
      : 0.0;

  void _handleAddParticipant() {
    final name = _addNameController.text.trim();
    final email = _addEmailController.text.trim();

    if (name.isEmpty) {
      setState(() => _participantInputError = 'Please enter a participant name');
      return;
    }

    if (_participants.length >= 15) {
      setState(() => _participantInputError =
          'You can add a maximum of 15 people to one expense report.');
      return;
    }

    final alreadyExists = _participants.any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (alreadyExists) {
      setState(() => _participantInputError =
          'A participant named "$name" has already been added.');
      return;
    }

    HapticHelper.selectionClick();
    final newParticipant = ReportParticipant(
      id: const Uuid().v4(),
      name: name,
      email: email.isNotEmpty ? email : null,
    );

    setState(() {
      _participants.add(newParticipant);
      _participantInputError = null;
      _addNameController.clear();
      _addEmailController.clear();
      _showAddParticipantForm = false;
      _selectedPayer ??= newParticipant;
    });
  }

  void _handleRemoveParticipant(ReportParticipant participant) {
    if (_participants.length <= 1) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 participant is required for the report.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticHelper.selectionClick();
    setState(() {
      _participants.removeWhere((p) => p.id == participant.id);
      if (_selectedPayer?.id == participant.id) {
        _selectedPayer = _participants.first;
      }
    });
  }

  TripExpenseReport? _buildReport() {
    if (_tripExpenses.isEmpty) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No trip transactions found. Please record at least 1 expense first.',
          ),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    if (_participants.isEmpty) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 participant.'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    if (_selectedPayer == null) {
      HapticHelper.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who paid for the expenses in Section 3.'),
          backgroundColor: AppColors.roseExpense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    final tripTitle = _trip?.title ?? 'Trip Expense Report';
    final destination = _trip?.destination ?? 'Travel Itinerary';
    final startDate = _trip?.startDate ??
        (_tripExpenses.isNotEmpty ? _tripExpenses.first.date : DateTime.now());
    final endDate = _trip?.endDate ??
        (_tripExpenses.isNotEmpty ? _tripExpenses.last.date : DateTime.now());

    return TripExpenseReport(
      tripId: widget.tripId,
      tripTitle: tripTitle,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      generatedAt: DateTime.now(),
      expenses: List.unmodifiable(_tripExpenses),
      participants: List.unmodifiable(_participants),
      payer: _selectedPayer!,
      currency: _trip?.currency ?? 'INR',
    );
  }

  Future<void> _handleSaveAsPdf() async {
    final report = _buildReport();
    if (report == null) return;

    setState(() => _isSavingPdf = true);
    HapticHelper.mediumImpact();

    try {
      await TripExpensePdfService.instance.saveAndSharePdf(report);
      HapticHelper.success();
    } catch (e) {
      debugPrint('[BillSplitDialog] PDF generation error: $e');
      HapticHelper.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.roseExpense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPdf = false);
      }
    }
  }

  void _handleViewNow() {
    final report = _buildReport();
    if (report == null) return;

    TripExpenseReportPreviewScreen.navigate(
      context,
      report: report,
      isDark: widget.isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: GlassDecorations.glassModalDecoration(isDark: isDark),
      padding: EdgeInsets.fromLTRB(18, 14, 18, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle notch
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x40FFFFFF)
                    : const Color(0x33000000),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row: Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split Trip Expense',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    Text(
                      'Trip expense description, participant shares & PDF report',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LiquidPop(
                pressedScale: 0.88,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 24,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scrollable Content: Complete Trip Report Workflow
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildTripReportWorkflow(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Complete Trip Expense Report Workflow (Main Feature)
  Widget _buildTripReportWorkflow(bool isDark) {
    if (_isLoadingExpenses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final dateFmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trip Confirmation Banner
        if (_trip != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? AppColors.appleBlue : AppColors.royalIndigo)
                    .withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.airplane,
                  size: 14,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trip: ${_trip!.title} (${_trip!.destination})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // SECTION 1: TRIP EXPENSE DESCRIPTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TRIP EXPENSE DESCRIPTION',
              style: AppTextStyles.labelUppercase.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            Text(
              '${_tripExpenses.length} Items • ${CurrencyFormatter.format(_totalTripExpenses)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_tripExpenses.isEmpty)
          _buildEmptyExpensesCard(isDark)
        else
          _buildExpensesDescriptionTable(dateFmt, isDark),

        const SizedBox(height: 20),

        // SECTION 2: ADD PEOPLE (MAX 15 PARTICIPANTS)
        _buildAddPeopleSection(isDark),
        const SizedBox(height: 20),

        // SECTION 3: WHO PAID? (PAYER SELECTION)
        _buildWhoPaidSection(isDark),
        const SizedBox(height: 20),

        // SECTION 4: EXPENSE CALCULATION AND EQUAL SPLITTING
        _buildCalculationSummaryCard(isDark),
        const SizedBox(height: 24),

        // SECTION 5: TWO FINAL OPTIONS (SAVE AS PDF & VIEW NOW)
        _buildTwoFinalActions(isDark),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Section 1: Organized Expenses Table
  Widget _buildExpensesDescriptionTable(DateFormat dateFmt, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'EXPENSE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tripExpenses.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
            itemBuilder: (context, index) {
              final e = _tripExpenses[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            '${e.category.name} • ${e.paymentMethod.displayName}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        dateFmt.format(e.date),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        CurrencyFormatter.format(e.amount),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Total Footer Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Total Trip Expense:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    CurrencyFormatter.format(_totalTripExpenses),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
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

  Widget _buildEmptyExpensesCard(bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      borderRadius: 16,
      child: Column(
        children: [
          Icon(
            CupertinoIcons.tray_fill,
            size: 32,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'No trip transactions found',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record expenses associated with this trip to automatically calculate and split the total.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await QuickTravelExpenseSheet.show(
                context,
                initialTripId: widget.tripId,
              );
              await _loadTripExpenses();
            },
            icon: const Icon(CupertinoIcons.plus_circle_fill, size: 16),
            label: const Text('Record Trip Expense Now'),
          ),
        ],
      ),
    );
  }

  /// Section 2: Add People (Max 15 Participants)
  Widget _buildAddPeopleSection(bool isDark) {
    final count = _participants.length;
    final isMaxReached = count >= 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ADD PEOPLE',
              style: AppTextStyles.labelUppercase.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isMaxReached
                        ? AppColors.roseExpense
                        : (isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count of 15 participants added',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isMaxReached
                      ? AppColors.roseExpense
                      : (isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Participant Chips / List
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _participants.map((p) {
                  final isPayer = p.id == _selectedPayer?.id;
                  return Container(
                    padding: const EdgeInsets.only(
                      left: 10,
                      top: 5,
                      bottom: 5,
                      right: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPayer
                          ? (isDark
                              ? AppColors.appleBlue.withValues(alpha: 0.25)
                              : AppColors.royalIndigo.withValues(alpha: 0.14))
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPayer
                            ? (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isPayer
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (isPayer) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Payer',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _handleRemoveParticipant(p),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Add Person Button or Expanded Form
              if (_showAddParticipantForm) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Person',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _showAddParticipantForm = false;
                              _participantInputError = null;
                            }),
                            child: Icon(
                              CupertinoIcons.xmark_circle,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GlassTextField(
                        controller: _addNameController,
                        labelText: 'Full Name',
                        hintText: 'e.g. Rahul Sharma',
                        prefixIcon: CupertinoIcons.person,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      GlassTextField(
                        controller: _addEmailController,
                        labelText: 'Email Address (Optional)',
                        hintText: 'e.g. rahul@example.com',
                        prefixIcon: CupertinoIcons.mail,
                        isDark: isDark,
                      ),
                      if (_participantInputError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _participantInputError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.roseExpense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _showAddParticipantForm = false;
                              _participantInputError = null;
                            }),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _handleAddParticipant,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.appleBlue
                                  : AppColors.royalIndigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(CupertinoIcons.add, size: 14),
                            label: const Text('Add Person'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (isMaxReached)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.roseExpense.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.roseExpense.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'You can add a maximum of 15 people to one expense report.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.roseExpense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAddParticipantForm = true),
                    icon: const Icon(CupertinoIcons.person_badge_plus, size: 16),
                    label: const Text('+ Add People'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Section 3: Who Paid? (Payer Selection)
  Widget _buildWhoPaidSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO PAID?',
          style: AppTextStyles.labelUppercase.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the person who paid for these trip expenses:',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _participants.map((p) {
                  final isSelected = _selectedPayer?.id == p.id;
                  return GestureDetector(
                    onTap: () {
                      HapticHelper.selectionClick();
                      setState(() => _selectedPayer = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x1A000000)),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedPayer != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 13,
                        color: isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Payer: ${_selectedPayer!.name} • Total Paid: ${CurrencyFormatter.format(_totalTripExpenses)}',
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
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Section 4: Expense Calculation and Equal Splitting
  Widget _buildCalculationSummaryCard(bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPENSE SUMMARY',
                style: AppTextStyles.labelUppercase.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                '${_participants.length} Equal Shares',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Total Trip Expense:',
            CurrencyFormatter.format(_totalTripExpenses),
            isDark,
            isBold: true,
          ),
          _summaryRow(
            'Paid By:',
            _selectedPayer?.name ?? 'Not Selected',
            isDark,
          ),
          _summaryRow(
            'Total Paid:',
            CurrencyFormatter.format(_totalTripExpenses),
            isDark,
          ),
          _summaryRow(
            'Participants:',
            '${_participants.length}',
            isDark,
          ),
          const Divider(height: 14),
          _summaryRow(
            'Individual Share:',
            CurrencyFormatter.format(_individualShare),
            isDark,
            isBold: true,
            highlightColor:
                isDark ? AppColors.appleBlue : AppColors.royalIndigo,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isBold ? 13 : 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: highlightColor ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 5: Two Final Options (Save as PDF & View Now)
  Widget _buildTwoFinalActions(bool isDark) {
    return Row(
      children: [
        // Button 1: Save as PDF
        Expanded(
          child: GlassButton(
            label: 'Save as PDF',
            icon: CupertinoIcons.arrow_down_doc_fill,
            isLoading: _isSavingPdf,
            isDark: isDark,
            onPressed: _handleSaveAsPdf,
          ),
        ),
        const SizedBox(width: 10),
        // Button 2: View Now
        Expanded(
          child: GlassButton(
            label: 'View Now',
            icon: CupertinoIcons.eye_fill,
            variant: GlassButtonVariant.secondary,
            isDark: isDark,
            onPressed: _handleViewNow,
          ),
        ),
      ],
    );
  }
}
