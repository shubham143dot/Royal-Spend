import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/reports/trip_expense_pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../data/models/trip_expense_report.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';

/// In-app comprehensive preview screen for Royal Spend Trip Expense Reports.
class TripExpenseReportPreviewScreen extends StatefulWidget {
  final TripExpenseReport report;
  final bool isDark;

  const TripExpenseReportPreviewScreen({
    super.key,
    required this.report,
    required this.isDark,
  });

  static Future<void> navigate(
    BuildContext context, {
    required TripExpenseReport report,
    required bool isDark,
  }) {
    HapticHelper.mediumImpact();
    return Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => TripExpenseReportPreviewScreen(
          report: report,
          isDark: isDark,
        ),
      ),
    );
  }

  @override
  State<TripExpenseReportPreviewScreen> createState() =>
      _TripExpenseReportPreviewScreenState();
}

class _TripExpenseReportPreviewScreenState
    extends State<TripExpenseReportPreviewScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _handleSaveAsPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    HapticHelper.mediumImpact();

    try {
      await TripExpensePdfService.instance.saveAndSharePdf(widget.report);
      HapticHelper.success();
    } catch (e) {
      debugPrint('[TripExpenseReportPreview] PDF export error: $e');
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
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final report = widget.report;
    final reconciled = report.reconciledShares;
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Expense Report',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              TripExpensePdfService.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _handleSaveAsPdf,
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      CupertinoIcons.share,
                      size: 16,
                      color: isDark
                          ? AppColors.appleBlue
                          : AppColors.royalIndigo,
                    ),
              label: Text(
                'Save as PDF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.appleBlue
                      : AppColors.royalIndigo,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Branded Header Card
              _buildBrandedHeaderCard(report, isDark),
              const SizedBox(height: 14),

              // 2. High-Level KPI Summary Grid
              _buildMetricsGrid(report, isDark),
              const SizedBox(height: 14),

              // 3. Dedicated PAID BY Section
              _buildPayerCard(report, isDark),
              const SizedBox(height: 14),

              // 4. Participant Breakdown & Equal Split Shares
              _buildParticipantsCard(report, reconciled, isDark),
              const SizedBox(height: 18),

              // 5. Complete Transaction History Section
              _buildTransactionHistorySection(report, dateFmt, timeFmt, isDark),
              const SizedBox(height: 18),

              // 6. Final Financial Reconciliation Summary
              _buildFinancialSummaryCard(report, isDark),
              const SizedBox(height: 24),

              // 7. Save as PDF Action Button
              GlassButton(
                label: 'Save as PDF',
                icon: CupertinoIcons.arrow_down_doc_fill,
                isLoading: _isGeneratingPdf,
                isDark: isDark,
                onPressed: _handleSaveAsPdf,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Branded Header Card
  Widget _buildBrandedHeaderCard(TripExpenseReport report, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
              : [const Color(0xFF312E81), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        size: 16,
                        color: Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        TripExpensePdfService.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'OFFICIAL REPORT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.tripTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(CupertinoIcons.placemark_fill,
                  size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.destination,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Dates: ${report.dateRangeFormatted}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
              Text(
                'Generated: ${report.generatedAtFormatted}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. KPI Metrics Grid
  Widget _buildMetricsGrid(TripExpenseReport report, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            label: 'TOTAL EXPENDITURE',
            value: CurrencyFormatter.format(report.totalExpenses),
            icon: CupertinoIcons.money_dollar,
            color: AppColors.appleBlue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            label: 'EQUAL SHARE / PERSON',
            value: CurrencyFormatter.format(report.individualShare),
            icon: CupertinoIcons.person_2_fill,
            color: AppColors.applePurple,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Dedicated PAID BY Section
  Widget _buildPayerCard(TripExpenseReport report, bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.appleBlue, AppColors.royalIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                report.payer.name.isNotEmpty
                    ? report.payer.name[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.appleBlue
                                : AppColors.royalIndigo)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PAID BY',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.appleBlue
                              : AppColors.royalIndigo,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.payer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (report.payer.email != null &&
                    report.payer.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    report.payer.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  'Settled all ${report.totalTransactions} transactions in full',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.appleGreen
                        : const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Paid',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.format(report.totalExpenses),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Participant Breakdown & Equal Split Shares
  Widget _buildParticipantsCard(
    TripExpenseReport report,
    Map<String, double> reconciled,
    bool isDark,
  ) {
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
              Expanded(
                child: Text(
                  'PARTICIPANT BREAKDOWN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${report.totalParticipants} People',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.appleBlue : AppColors.royalIndigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.participants.length,
            separatorBuilder: (_, _) => Divider(
              height: 14,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
            itemBuilder: (context, index) {
              final p = report.participants[index];
              final share = reconciled[p.id] ?? report.individualShare;
              final isPayer = p.id == report.payer.id;

              return Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isPayer
                        ? AppColors.appleBlue
                        : (isDark
                            ? AppColors.darkSurface
                            : Colors.black.withValues(alpha: 0.06)),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPayer
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isPayer
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            if (isPayer) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.appleBlue
                                          : AppColors.royalIndigo)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Payer',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.appleBlue
                                        : AppColors.royalIndigo,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (p.email != null && p.email!.isNotEmpty)
                          Text(
                            p.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(share),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'Equal Share',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 5. Complete Transaction History Section
  Widget _buildTransactionHistorySection(
    TripExpenseReport report,
    DateFormat dateFmt,
    DateFormat timeFmt,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'TRANSACTION HISTORY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${report.totalTransactions} Items Included',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (report.expenses.isEmpty)
          GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Center(
              child: Text(
                'No transactions recorded for this trip.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.expenses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = report.expenses[index];
              final category = e.category;

              return GlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon circle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        category.icon,
                        size: 16,
                        color: category.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title, notes, and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (e.notes != null && e.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              e.notes!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Date pill
                              _badgePill(
                                icon: CupertinoIcons.calendar,
                                text: dateFmt.format(e.date),
                                isDark: isDark,
                              ),
                              // Payment method pill
                              _badgePill(
                                icon: e.paymentMethod.icon,
                                text: e.paymentMethod.displayName,
                                isDark: isDark,
                              ),
                              // Category name pill
                              _badgePill(
                                icon: CupertinoIcons.tag,
                                text: category.name,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Amount
                    Text(
                      CurrencyFormatter.format(e.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _badgePill({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 9.5,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Final Financial Reconciliation Summary
  Widget _buildFinancialSummaryCard(TripExpenseReport report, bool isDark) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINANCIAL RECONCILIATION SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Total Trip Expenses',
              CurrencyFormatter.format(report.totalExpenses), isDark,
              isBold: true),
          _summaryRow('Selected Payer', report.payer.name, isDark),
          _summaryRow('Amount Paid by Payer',
              CurrencyFormatter.format(report.totalExpenses), isDark),
          _summaryRow(
              'Total Participants', '${report.totalParticipants}', isDark),
          _summaryRow('Equal Share Per Person',
              CurrencyFormatter.format(report.individualShare), isDark,
              isBold: true, highlightColor: AppColors.appleBlue),
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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
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
                fontSize: 12.5,
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
}
