import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/trip_expense_report.dart';

/// Professional PDF generator and exporter for Royal Spend Trip Expense Reports.
class TripExpensePdfService {
  TripExpensePdfService._();
  static final TripExpensePdfService instance = TripExpensePdfService._();

  static const String appName = 'Royal Spend: Expense Tracker & Travel Planner';
  static const String reportTitle = 'TRIP EXPENSE REPORT';

  // Professional Financial Palette
  static final PdfColor primaryIndigo = PdfColor.fromInt(0xFF2E1065);
  static final PdfColor royalAccent = PdfColor.fromInt(0xFF4F46E5);
  static final PdfColor slateDark = PdfColor.fromInt(0xFF0F172A);
  static final PdfColor slateMuted = PdfColor.fromInt(0xFF64748B);
  static final PdfColor surfaceLight = PdfColor.fromInt(0xFFF8FAFC);
  static final PdfColor borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static final PdfColor emeraldGreen = PdfColor.fromInt(0xFF059669);

  /// Generates a complete, multi-page branded PDF report.
  Future<Uint8List> generatePdf(TripExpenseReport report) async {
    final pdf = pw.Document(
      title: '$appName - $reportTitle',
      author: appName,
      creator: appName,
    );

    // Attempt to load application logo asset safely
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final iconBytes = await rootBundle.load('assets/icons/app_icon.png');
        logoImage = pw.MemoryImage(iconBytes.buffer.asUint8List());
      } catch (_) {}
    }

    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

    // Build multi-page document with header, content sections, and footer
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        header: (context) => _buildPdfHeader(context, logoImage, report),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          // Section 1: Trip Information Overview Card
          _buildTripOverviewSection(report),
          pw.SizedBox(height: 18),

          // Section 2: Dedicated "PAID BY" Highlighted Section
          _buildPayerHighlightSection(report),
          pw.SizedBox(height: 18),

          // Section 3: Complete Participant Details & Equal Split Shares
          _buildParticipantsSection(report),
          pw.SizedBox(height: 22),

          // Section 4: Complete Transaction History Table
          _buildTransactionHistorySection(report, dateFmt, timeFmt),
          pw.SizedBox(height: 20),

          // Section 5: Final Financial Summary & Reconciliation Table
          _buildFinalFinancialSummary(report),
        ],
      ),
    );

    return pdf.save();
  }

  /// Builds the persistent branded header on every page.
  pw.Widget _buildPdfHeader(
    pw.Context context,
    pw.MemoryImage? logoImage,
    TripExpenseReport report,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: royalAccent, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 38,
                  height: 38,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logoImage),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    appName,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryIndigo,
                    ),
                  ),
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: royalAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Report Date: ${_clean(report.generatedAtFormatted)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: slateMuted,
                ),
              ),
              pw.Text(
                'Trip: ${_clean(report.tripTitle)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: slateDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the persistent footer on every page.
  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderLight, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            appName,
            style: pw.TextStyle(
              fontSize: 8,
              color: slateMuted,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Section A: Trip Information Overview Card
  pw.Widget _buildTripOverviewSection(TripExpenseReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: surfaceLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderLight, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TRIP INFORMATION',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: royalAccent,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _clean(report.tripTitle),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Destination: ${_clean(report.destination)}',
                      style: pw.TextStyle(fontSize: 10, color: slateMuted),
                    ),
                    pw.Text(
                      'Travel Dates: ${_clean(report.dateRangeFormatted)}',
                      style: pw.TextStyle(fontSize: 10, color: slateMuted),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Trip Expenditure',
                      style: pw.TextStyle(fontSize: 9, color: slateMuted),
                    ),
                    pw.Text(
                      'Rs. ${_formatAmount(report.totalExpenses)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryIndigo,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${report.totalTransactions} Transactions',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: emeraldGreen,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section B: Dedicated "PAID BY" Highlighted Section
  pw.Widget _buildPayerHighlightSection(TripExpenseReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEEF2FF), // Soft Indigo tint
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: royalAccent, width: 1.2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: royalAccent,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'PAID BY',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    _clean(report.payer.name),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryIndigo,
                    ),
                  ),
                ],
              ),
              if (report.payer.email != null &&
                  report.payer.email!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Email: ${_clean(report.payer.email!)}',
                  style: pw.TextStyle(fontSize: 9, color: slateMuted),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                'Paid all expenses for this report - Settled in full',
                style: pw.TextStyle(fontSize: 9, color: slateMuted),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Total Amount Paid',
                style: pw.TextStyle(fontSize: 9, color: slateMuted),
              ),
              pw.Text(
                'Rs. ${_formatAmount(report.totalExpenses)}',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: royalAccent,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${report.totalTransactions} of ${report.totalTransactions} Transactions Included',
                style: pw.TextStyle(fontSize: 8, color: slateMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section C: Complete Participant Details & Equal Split Shares
  pw.Widget _buildParticipantsSection(TripExpenseReport report) {
    final reconciled = report.reconciledShares;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PARTICIPANT BREAKDOWN & EQUAL SHARES',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: royalAccent,
                letterSpacing: 1.0,
              ),
            ),
            pw.Text(
              'Total Participants: ${report.totalParticipants}',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: slateMuted,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.6),
          columnWidths: {
            0: const pw.FixedColumnWidth(32),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: surfaceLight),
              children: [
                _tableHeaderCell('#', align: pw.TextAlign.center),
                _tableHeaderCell('Participant Name'),
                _tableHeaderCell('Email / Reference'),
                _tableHeaderCell('Individual Share', align: pw.TextAlign.right),
              ],
            ),
            // Rows
            ...report.participants.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final share = reconciled[p.id] ?? report.individualShare;
              final isPayer = p.id == report.payer.id;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isPayer
                      ? PdfColor.fromInt(0xFFF5F3FF)
                      : (idx % 2 == 0 ? surfaceLight : PdfColors.white),
                ),
                children: [
                  _tableCell('$idx', align: pw.TextAlign.center),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          _clean(p.name),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: isPayer
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                            color: slateDark,
                          ),
                        ),
                        if (isPayer) ...[
                          pw.SizedBox(width: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: pw.BoxDecoration(
                              color: royalAccent,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(3)),
                            ),
                            child: pw.Text(
                              'Payer',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _tableCell(
                    (p.email != null && p.email!.isNotEmpty)
                        ? _clean(p.email!)
                        : '-',
                  ),
                  _tableCell(
                    'Rs. ${_formatAmount(share)}',
                    align: pw.TextAlign.right,
                    bold: true,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Section D: Complete Transaction History Table
  pw.Widget _buildTransactionHistorySection(
    TripExpenseReport report,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'COMPLETE TRANSACTION HISTORY',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: royalAccent,
                letterSpacing: 1.0,
              ),
            ),
            pw.Text(
              '${report.totalTransactions} Transactions Included',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: slateMuted,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (report.expenses.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: surfaceLight,
              border: pw.Border.all(color: borderLight, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'No eligible transactions recorded for this trip.',
              style: pw.TextStyle(fontSize: 10, color: slateMuted),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: borderLight, width: 0.6),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(3.5),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(1.6),
              5: const pw.FlexColumnWidth(2.0),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceLight),
                children: [
                  _tableHeaderCell('#', align: pw.TextAlign.center),
                  _tableHeaderCell('Expense Title / Description'),
                  _tableHeaderCell('Category'),
                  _tableHeaderCell('Date & Time'),
                  _tableHeaderCell('Method'),
                  _tableHeaderCell('Amount', align: pw.TextAlign.right),
                ],
              ),
              // Transaction Rows
              ...report.expenses.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final e = entry.value;
                final dateStr =
                    '${dateFmt.format(e.date)}\n${timeFmt.format(e.date)}';
                final desc = (e.notes != null && e.notes!.trim().isNotEmpty)
                    ? '${e.title}\n(${e.notes!.trim()})'
                    : e.title;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: idx % 2 == 0 ? surfaceLight : PdfColors.white,
                  ),
                  children: [
                    _tableCell('$idx', align: pw.TextAlign.center),
                    _tableCell(_clean(desc)),
                    _tableCell(_clean(e.category.name)),
                    _tableCell(dateStr),
                    _tableCell(_clean(e.paymentMethod.displayName)),
                    _tableCell(
                      'Rs. ${_formatAmount(e.amount)}',
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  /// Section E: Final Financial Summary & Reconciliation Table
  pw.Widget _buildFinalFinancialSummary(TripExpenseReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: surfaceLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderLight, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FINAL FINANCIAL SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: primaryIndigo,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Total Trip Expenditure',
                  'Rs. ${_formatAmount(report.totalExpenses)}'),
              _summaryItem(
                  'Total Transactions', '${report.totalTransactions}'),
              _summaryItem('Total Participants', '${report.totalParticipants}'),
              _summaryItem('Payer (100% Paid)', _clean(report.payer.name)),
              _summaryItem('Equal Share / Person',
                  'Rs. ${_formatAmount(report.individualShare)}'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: slateMuted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: slateDark,
          ),
        ),
      ],
    );
  }

  pw.Widget _tableHeaderCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: slateDark,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: slateDark,
        ),
      ),
    );
  }

  static String _clean(String input) {
    return input
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('•', '|')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('”', '"')
        .replaceAll('“', '"')
        .replaceAll('₹', 'Rs. ');
  }

  static String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,##0.00');
    return formatter.format(amount);
  }

  /// Saves the PDF to temporary storage and invokes the native OS share/save sheet.
  Future<void> saveAndSharePdf(TripExpenseReport report) async {
    final pdfBytes = await generatePdf(report);
    final sanitizedDate = DateFormat('yyyy-MM-dd').format(report.generatedAt);
    final filename = 'RoyalSpend_TripExpense_Report_$sanitizedDate.pdf';

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes, flush: true);
    } catch (_) {}

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
}
