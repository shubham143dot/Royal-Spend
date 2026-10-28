import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/services/ocr/parsed_transaction.dart';
import 'package:royal_spend/core/services/ocr/smart_import_service.dart';
import 'package:royal_spend/core/theme/app_colors.dart';
import 'package:royal_spend/core/theme/app_text_styles.dart';
import 'package:royal_spend/core/utils/currency_formatter.dart';
import 'package:royal_spend/core/utils/haptic_helper.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import '../liquid_pop.dart';

/// Dedicated Smart Import component supporting gallery upload, camera capture,
/// real-time on-device OCR, duplicate alerts, and candidate amount selection.
class SmartImportSection extends StatefulWidget {
  final bool isDark;
  final ParsedTransaction? parsedTransaction;
  final bool amountManuallyConfirmed;
  final bool isProcessing;
  final ValueChanged<ParsedTransaction> onTransactionParsed;
  final VoidCallback onReset;
  final ValueChanged<double> onSelectCandidateAmount;
  final VoidCallback onFallbackToManual;

  const SmartImportSection({
    super.key,
    required this.isDark,
    required this.parsedTransaction,
    this.amountManuallyConfirmed = false,
    required this.isProcessing,
    required this.onTransactionParsed,
    required this.onReset,
    required this.onSelectCandidateAmount,
    required this.onFallbackToManual,
  });

  @override
  State<SmartImportSection> createState() => _SmartImportSectionState();
}

class _SmartImportSectionState extends State<SmartImportSection> {
  final SmartImportService _importService = SmartImportService();
  String? _errorMessage;
  bool _isSelectingImage = false;
  bool _isLocalProcessing = false;

  @override
  void dispose() {
    _importService.dispose();
    super.dispose();
  }

  Future<void> _handleImageSelection(bool isCamera) async {
    if (_isSelectingImage || _isLocalProcessing) return;

    HapticHelper.mediumImpact();
    setState(() {
      _isSelectingImage = true;
      _errorMessage = null;
    });

    final expenses = context.read<ExpenseProvider>().allExpenses;
    try {
      final pickerResult = isCamera
          ? await _importService.picker.captureFromCamera()
          : await _importService.picker.pickFromGallery();

      if (!mounted || pickerResult.isCancelled) return;

      if (!pickerResult.isSuccess || pickerResult.filePath == null) {
        setState(() {
          _errorMessage =
              pickerResult.errorMessage ?? 'Could not load selected image.';
        });
        HapticHelper.heavyImpact();
        return;
      }

      final imagePath = pickerResult.filePath!;
      setState(() {
        _isSelectingImage = false;
        _isLocalProcessing = true;
      });

      final parsed = await _importService.processReceiptImage(
        imagePath,
        expenses,
      );
      if (!mounted) return;
      HapticHelper.success();
      widget.onTransactionParsed(parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'On-device OCR error: $e';
      });
      HapticHelper.heavyImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingImage = false;
          _isLocalProcessing = false;
        });
      }
    }
  }

  void _showFullImagePreview(String imagePath) {
    HapticHelper.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                color: widget.isDark ? AppColors.darkCard : Colors.white,
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LiquidPop(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isProcessing || _isLocalProcessing) {
      return _buildProcessingState();
    }

    if (widget.parsedTransaction != null) {
      return _buildParsedHeader(widget.parsedTransaction!);
    }

    return _buildSourceSelector();
  }

  // ---------------------------------------------------------------------------
  // 1. Initial Source Selector (Upload Image / Take Photo)
  // ---------------------------------------------------------------------------
  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.roseExpense.withValues(
                alpha: widget.isDark ? 0.2 : 0.12,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.roseExpense.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppColors.roseExpense,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark
                          ? Colors.white
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                LiquidPop(
                  onTap: () => setState(() => _errorMessage = null),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: AppColors.roseExpense,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Two prominent action cards
        Row(
          children: [
            // Upload Image (Gallery)
            Expanded(
              child: _ImportActionCard(
                isDark: widget.isDark,
                title: 'Upload Image',
                subtitle: 'Screenshots & Bills',
                icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                accentColor: AppColors.electricCyan,
                onTap: () => _handleImageSelection(false),
              ),
            ),
            const SizedBox(width: 12),

            // Take Photo (Camera)
            Expanded(
              child: _ImportActionCard(
                isDark: widget.isDark,
                title: 'Take Photo',
                subtitle: 'Scan Physical Receipt',
                icon: CupertinoIcons.camera_viewfinder,
                accentColor: AppColors.vividMint,
                onTap: () => _handleImageSelection(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Helpful Info Pill
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkSurface
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isDark
                  ? AppColors.darkGlassHighlight
                  : Colors.white.withValues(alpha: 0.85),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_shield_fill,
                    color: AppColors.appleBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '100% On-Device & Private',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Financial text extraction runs entirely offline using local ML text recognition. No receipt images or personal data leave your phone.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FormatChip(label: 'PhonePe', isDark: widget.isDark),
                  _FormatChip(label: 'Google Pay', isDark: widget.isDark),
                  _FormatChip(label: 'Paytm', isDark: widget.isDark),
                  _FormatChip(label: 'Restaurant Bills', isDark: widget.isDark),
                  _FormatChip(label: 'Store Receipts', isDark: widget.isDark),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Processing State
  // ---------------------------------------------------------------------------
  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.darkSurface
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.appleBlue.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.appleBlue.withValues(alpha: 0.15),
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.appleBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Scanning Receipt...',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? Colors.white
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Extracting merchant, total amount & date with on-device OCR',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Parsed Receipt Header & Duplicate Alert
  // ---------------------------------------------------------------------------
  Widget _buildParsedHeader(ParsedTransaction parsed) {
    final amountMessage =
        widget.amountManuallyConfirmed &&
            parsed.amountStatus != AmountExtractionStatus.extracted
        ? 'Manually entered amount - review below'
        : switch (parsed.amountStatus) {
            AmountExtractionStatus.extracted =>
              'Extracted ${CurrencyFormatter.format(parsed.amount!, symbol: parsed.currencySymbol)}',
            AmountExtractionStatus.ambiguous =>
              'Amount ambiguous - select a candidate below',
            AmountExtractionStatus.invalid =>
              'Amount unreadable - enter it manually',
            AmountExtractionStatus.missing =>
              'Amount unclear - please verify or enter',
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duplicate Transaction Warning Banner (if detected)
        if (parsed.isDuplicate) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.amberWarning.withValues(
                alpha: widget.isDark ? 0.22 : 0.14,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.amberWarning.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppColors.amberWarning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Possible Duplicate Detected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parsed.duplicateReason ??
                            'A similar transaction was already recorded in your history.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can still save this expense if this is an intentional repeat purchase.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.amberWarning.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Thumbnail + Status Banner Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkSurface
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark
                  ? AppColors.darkGlassHighlight
                  : Colors.white.withValues(alpha: 0.9),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              // Image Thumbnail (tap to enlarge)
              if (parsed.imagePath != null &&
                  File(parsed.imagePath!).existsSync()) ...[
                LiquidPop(
                  onTap: () => _showFullImagePreview(parsed.imagePath!),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(parsed.imagePath!),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.zoom_in,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Info & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.vividMint.withValues(
                              alpha: widget.isDark ? 0.25 : 0.15,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.sparkles,
                                color: AppColors.vividMint,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                parsed.sourceType,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.vividMint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        LiquidPop(
                          onTap: widget.onReset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? AppColors.darkCard
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.isDark
                                    ? AppColors.darkGlassHighlight
                                    : Colors.black12,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_counterclockwise,
                                  size: 11,
                                  color: widget.isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amountMessage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: parsed.amount != null
                            ? (widget.isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary)
                            : AppColors.amberWarning,
                      ),
                    ),
                    if (parsed.isIncome) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Incoming payment detected - this will be recorded as income.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: widget.isDark
                              ? AppColors.vividMint
                              : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Candidate Alternative Amounts (shown if multiple amounts found or if amount is ambiguous)
        if (parsed.candidateAmounts.length > 1 ||
            (parsed.amount == null && parsed.candidateAmounts.isNotEmpty)) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle,
                  size: 13,
                  color: parsed.amount == null
                      ? AppColors.amberWarning
                      : (widget.isDark
                            ? AppColors.appleBlue
                            : AppColors.royalIndigo),
                ),
                const SizedBox(width: 5),
                Text(
                  parsed.amount == null
                      ? 'SELECT DETECTED AMOUNT (TAP TO APPLY)'
                      : 'DETECTED AMOUNT CANDIDATES (TAP TO SWITCH)',
                  style: AppTextStyles.labelUppercase.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: parsed.amount == null
                        ? AppColors.amberWarning
                        : (widget.isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: parsed.candidateAmounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final amount = parsed.candidateAmounts[index];
                final isSelected = parsed.amount == amount;

                return LiquidPop(
                  onTap: () {
                    HapticHelper.selectionClick();
                    widget.onSelectCandidateAmount(amount);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.appleBlue.withValues(
                              alpha: widget.isDark ? 0.35 : 0.20,
                            )
                          : (widget.isDark
                                ? AppColors.darkSurface
                                : Colors.white.withValues(alpha: 0.85)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.appleBlue
                            : (widget.isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.appleBlue.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            CupertinoIcons.checkmark_alt,
                            size: 14,
                            color: AppColors.appleBlue,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          CurrencyFormatter.format(
                            amount,
                            symbol: parsed.currencySymbol,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? (widget.isDark
                                      ? Colors.white
                                      : AppColors.appleBlue)
                                : (widget.isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

class _ImportActionCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ImportActionCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidPop(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark
              ? AppColors.darkSurface
              : Colors.white.withValues(alpha: 0.75),
          border: Border.all(
            color: isDark
                ? AppColors.darkGlassHighlight
                : Colors.white.withValues(alpha: 0.9),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _FormatChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }
}
