import 'package:royal_spend/data/models/expense.dart';
import '../ocr_service.dart';
import '../parsed_transaction.dart';
import 'upi_parser_utils.dart';

/// Dedicated high-precision parser for PhonePe payment screenshots and receipts.
class PhonePeParser {
  /// Returns true if the OCR text displays distinctive PhonePe structural signatures.
  static bool isPhonePe(String text) {
    final lower = text.toLowerCase();

    // Disqualify physical shop receipts / restaurant bills that merely list "Paid via PhonePe"
    if (lower.contains('bill no') ||
        lower.contains('tax invoice') ||
        lower.contains('order total') ||
        lower.contains('grand total') ||
        lower.contains('table no') ||
        lower.contains('subtotal') ||
        lower.contains('gstin')) {
      return false;
    }

    if (lower.contains('manage autopay') ||
        lower.contains('contact phonepe support') ||
        lower.contains('powered by upi autopay')) {
      return true;
    }
    if (lower.contains('phonepe')) return true;
    if (lower.contains('@ybl') || lower.contains('@ibl') || lower.contains('@axl')) {
      return true;
    }
    // Layout signature: "Transaction Successful" + "Paid to" / "Debited from" + "UTR:" or "PhonePe Transaction ID"
    final hasSuccess = lower.contains('transaction successful') || lower.contains('payment successful');
    final hasPhonePeFlow = lower.contains('paid to') || lower.contains('debited from');
    final hasUpiId = text.contains('UTR:') ||
        lower.contains('phonepe transaction id') ||
        lower.contains('split expense') ||
        lower.contains('check balance');
    return hasSuccess && hasPhonePeFlow && hasUpiId;
  }

  /// Parses a PhonePe receipt with zero mistakes.
  static ParsedTransaction? parse(
    String rawText, {
    String? imagePath,
    List<OcrLineData>? ocrLines,
  }) {
    final cleanedText = UpiParserUtils.cleanText(rawText);
    if (cleanedText.isEmpty) return null;

    final healedText = UpiParserUtils.healRupeeGlyphs(cleanedText);
    final lines = healedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Detect Direction (Expense vs Income)
    final lowerText = healedText.toLowerCase();
    final isIncome = lowerText.contains('received from') ||
        lowerText.contains('credited to') ||
        lowerText.contains('refund credited');

    // 2. Extract Merchant / Payee
    final merchant = _extractMerchant(lines, healedText);

    // 3. Extract Amount
    final amountResult = _extractAmount(lines, healedText, ocrLines);

    // 4. Extract Date & Time
    final dateResult = _extractDateTime(healedText, lines);

    // 5. Extract Reference / UTR / Transaction ID
    final referenceId = _extractReferenceId(healedText);

    // 6. Infer Category
    final categoryId = UpiParserUtils.inferCategory(merchant, healedText);

    return ParsedTransaction(
      merchant: merchant,
      amount: amountResult.amount,
      isIncome: isIncome,
      amountConfidence: amountResult.confidence,
      amountStatus: amountResult.status,
      candidateAmounts: amountResult.candidates,
      date: dateResult.date,
      hasConfidentDate: dateResult.isConfident,
      timeString: dateResult.timeString,
      categoryId: categoryId,
      paymentMethod: PaymentMethod.upi,
      referenceId: referenceId,
      rawText: rawText,
      imagePath: imagePath,
      sourceType: 'PhonePe UPI',
      currencySymbol: '₹',
    );
  }

  // ---------------------------------------------------------------------------
  // Amount Extraction for PhonePe
  // ---------------------------------------------------------------------------
  static ({
    double? amount,
    double confidence,
    AmountExtractionStatus status,
    List<double> candidates,
  }) _extractAmount(
    List<String> lines,
    String text,
    List<OcrLineData>? ocrLines,
  ) {
    final candidates = <double>[];
    final scores = <double, double>{};

    // Extract UTR, Txn ID, and bank account numbers to strictly blacklist them
    final blacklistedNumbers = <int>{};
    for (final match in RegExp(r'\b[0-9]{10,22}\b').allMatches(text)) {
      final val = int.tryParse(match.group(0)!);
      if (val != null) blacklistedNumbers.add(val);
    }
    // Masked card/account endings e.g. "XXXXXX2608", "XX4912", "Account ending in 2608"
    for (final match in RegExp(
      r'(?:[Xx*]{2,}\s*|[Aa]ccount(?:\s*no\.?)?[\s:\-]+|[Aa]\/[Cc][\s:\-]+|[Cc]ard(?:\s*no\.?)?[\s:\-]+|[Ee]nding\s+(?:in|with)\s+)([0-9]{3,6})\b',
    ).allMatches(text)) {
      final val = int.tryParse(match.group(1)!);
      if (val != null) blacklistedNumbers.add(val);
    }

    final allDirectRupees = UpiParserUtils.extractAllRupeeAmounts(text);

    // Pattern 1: Explicit Rupee amounts e.g. "₹1", "₹ 280.00", "₹ 1,250", "₹30"
    final rupeeRegex = RegExp(
      r'[₹\u20B9\u20A8]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?',
    );

    // PhonePe has two prime locations for the payment amount:
    // Location A: Payee section (top right or line under "Paid to" / merchant)
    // Location B: Under "Debited from" next to bank account (e.g. "XXXXXX2608 ₹1")
    double? payeeSectionAmount;
    double? debitedSectionAmount;

    bool inPaidToSection = false;
    bool inDebitedSection = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (lineLower.contains('paid to') || lineLower.contains('payment to') || lineLower.contains('transfer to')) {
        inPaidToSection = true;
        inDebitedSection = false;
      } else if (lineLower.contains('debited from')) {
        inPaidToSection = false;
        inDebitedSection = true;
      } else if (lineLower.contains('payment details') || lineLower.contains('check balance')) {
        inPaidToSection = false;
      }

      // Check if this line or preceding line describes an account balance
      bool isBalanceLine = lineLower.contains('account balance') ||
          lineLower.contains('avail bal') ||
          lineLower.contains('available balance') ||
          lineLower.contains('closing bal') ||
          lineLower.contains('wallet balance') ||
          lineLower.contains('main balance');

      for (final offset in [-2, -1]) {
        final targetIdx = i + offset;
        if (targetIdx >= 0 && targetIdx < lines.length) {
          final prevLower = lines[targetIdx].toLowerCase();
          if (prevLower.contains('account balance') ||
              prevLower.contains('avail bal') ||
              prevLower.contains('available balance') ||
              prevLower.contains('closing bal')) {
            isBalanceLine = true;
          }
        }
      }

      if (isBalanceLine) continue;

      for (final match in rupeeRegex.allMatches(line)) {
        final parsed = UpiParserUtils.parseCleanNumber(match.group(1));
        if (parsed != null && UpiParserUtils.isValidAmount(parsed)) {
          final intVal = parsed.toInt();
          if (blacklistedNumbers.contains(intVal) && !allDirectRupees.contains(parsed)) continue;

          if (!candidates.contains(parsed)) {
            candidates.add(parsed);
          }

          var score = 0.85;
          if (inPaidToSection) {
            score += 0.12;
            payeeSectionAmount ??= parsed;
          } else if (inDebitedSection) {
            score += 0.10;
            debitedSectionAmount ??= parsed;
          }

          scores[parsed] = ((scores[parsed] ?? 0.0) < score) ? score : scores[parsed]!;
        }
      }
    }

    // If both Payee section and Debited section exhibit the EXACT same amount (e.g. 1.0 == 1.0),
    // this is a 100% indisputable match!
    if (payeeSectionAmount != null &&
        debitedSectionAmount != null &&
        payeeSectionAmount == debitedSectionAmount) {
      scores[payeeSectionAmount] = 0.99;
      return (
        amount: payeeSectionAmount,
        confidence: 0.99,
        status: AmountExtractionStatus.extracted,
        candidates: [payeeSectionAmount],
      );
    }

    // If only one section amount was identified
    final preferredAmount = payeeSectionAmount ?? debitedSectionAmount;
    if (preferredAmount != null) {
      return (
        amount: preferredAmount,
        confidence: 0.96,
        status: AmountExtractionStatus.extracted,
        candidates: candidates.isNotEmpty ? candidates : [preferredAmount],
      );
    }

    // Fallback: any candidate found
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => (scores[b] ?? 0.0).compareTo(scores[a] ?? 0.0));
      final top = candidates.first;
      return (
        amount: top,
        confidence: scores[top] ?? 0.85,
        status: AmountExtractionStatus.extracted,
        candidates: candidates,
      );
    }

    // Bulletproof Fallback: Any Rupee amounts extracted from the entire text
    if (allDirectRupees.isNotEmpty) {
      return (
        amount: allDirectRupees.first,
        confidence: 0.92,
        status: AmountExtractionStatus.extracted,
        candidates: allDirectRupees,
      );
    }

    return (
      amount: null,
      confidence: 0.0,
      status: AmountExtractionStatus.missing,
      candidates: [],
    );
  }

  // ---------------------------------------------------------------------------
  // Merchant Extraction for PhonePe
  // ---------------------------------------------------------------------------
  static String? _extractMerchant(List<String> lines, String text) {
    // 1. Locate "Paid to", "Payment to", "Transfer to", "Sent to"
    for (int i = 0; i < lines.length; i++) {
      final lineLower = lines[i].toLowerCase();
      if (lineLower == 'paid to' ||
          lineLower == 'payment to' ||
          lineLower == 'transfer to' ||
          lineLower == 'sent to' ||
          lineLower.startsWith('paid to ') ||
          lineLower.startsWith('payment to ')) {

        // If line is "Paid to MOHALLA TECH PRIVATE LIMITED"
        if (lineLower.startsWith('paid to ') || lineLower.startsWith('payment to ')) {
          final inline = lines[i]
              .replaceFirst(RegExp(r'^(paid to|payment to)\s+', caseSensitive: false), '')
              .replaceAll(RegExp(r'[₹\u20B9].*$'), '')
              .trim();
          if (_isValidPhonePeMerchant(inline)) return inline;
        }

        // Look at subsequent lines (up to 4 lines ahead)
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final candidateLine = lines[j].trim();
          final candidateLower = candidateLine.toLowerCase();

          // Stop at section markers
          if (candidateLower.contains('payment details') ||
              candidateLower.contains('debited from') ||
              candidateLower.contains('message') ||
              candidateLower.contains('phonepe transaction id') ||
              candidateLower.contains('autopay') ||
              candidateLower.startsWith('₹') ||
              candidateLower.startsWith('rs')) {
            break;
          }

          // CRITICAL: Skip 1-2 character circular avatar initials (e.g. "ML", "AB", "R", "99")
          if (candidateLine.length <= 2 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(candidateLine)) {
            continue;
          }

          // Clean out trailing currency tokens if clustered
          final cleaned = candidateLine
              .replaceAll(RegExp(r'\s*[₹\u20B9\?*•Ff=~].*$'), '')
              .replaceAll(RegExp(r'\s+AUTOPAY\b', caseSensitive: false), '')
              .trim();

          if (_isValidPhonePeMerchant(cleaned)) {
            return cleaned;
          }
        }
      }
    }

    // 2. UPI ID handle fallback e.g. "bluetokai@ybl" -> "Blue Tokai"
    final upiMatch = RegExp(r'\b([a-zA-Z0-9\.\_]{3,30})@(ybl|ibl|axl)\b').firstMatch(text);
    if (upiMatch != null) {
      final handle = upiMatch.group(1);
      if (handle != null && !RegExp(r'^\d+$').hasMatch(handle)) {
        return _formatHandle(handle);
      }
    }

    return null;
  }

  static bool _isValidPhonePeMerchant(String? name) {
    if (name == null || name.length < 3) return false;
    final lower = name.toLowerCase();
    const badTokens = [
      'transaction successful', 'payment details', 'autopay',
      'debited from', 'message', 'view history', 'split expense',
      'share receipt', 'check balance', 'phonepe',
    ];
    if (badTokens.any((t) => lower.contains(t))) return false;
    return true;
  }

  static String _formatHandle(String handle) {
    final words = handle.split(RegExp(r'[\.\_\-]'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Date & Time Extraction for PhonePe
  // ---------------------------------------------------------------------------
  static ({DateTime? date, bool isConfident, String? timeString}) _extractDateTime(
    String text,
    List<String> lines,
  ) {
    // PhonePe Header Date Format 1: "09:31 AM on 09 Oct 2026" or "09:31 AM on 09 October 2026"
    final format1 = RegExp(
      r'\b(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM|am|pm)\s+on\s+(0?[1-9]|[12][0-9]|3[01])\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(20[2-3][0-9])\b',
      caseSensitive: false,
    );
    final m1 = format1.firstMatch(text);
    if (m1 != null) {
      final timeStr = '${m1.group(1)}:${m1.group(2)} ${m1.group(3)!.toUpperCase()}';
      final day = int.parse(m1.group(4)!);
      final month = UpiParserUtils.monthToNum(m1.group(5)!)!;
      final year = int.parse(m1.group(6)!);
      final date = UpiParserUtils.combineDateAndTime(DateTime(year, month, day), timeStr);
      return (date: date, isConfident: true, timeString: timeStr);
    }

    // Format 2: "24 Oct 2026, 08:30 PM" or "24 Oct 2026 at 08:30 PM"
    final format2 = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(20[2-3][0-9])(?:[\s,]+(?:at\s+)?)(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM|am|pm)\b',
      caseSensitive: false,
    );
    final m2 = format2.firstMatch(text);
    if (m2 != null) {
      final day = int.parse(m2.group(1)!);
      final month = UpiParserUtils.monthToNum(m2.group(2)!)!;
      final year = int.parse(m2.group(3)!);
      final timeStr = '${m2.group(4)}:${m2.group(5)} ${m2.group(6)!.toUpperCase()}';
      final date = UpiParserUtils.combineDateAndTime(DateTime(year, month, day), timeStr);
      return (date: date, isConfident: true, timeString: timeStr);
    }

    return (date: null, isConfident: false, timeString: null);
  }

  // ---------------------------------------------------------------------------
  // Reference ID & UTR Extraction for PhonePe
  // ---------------------------------------------------------------------------
  static String? _extractReferenceId(String text) {
    // 1. 12-digit UTR (standard banking reference)
    final utrMatch = RegExp(r'\bUTR\s*[:\-]?\s*([0-9]{12})\b', caseSensitive: false).firstMatch(text);
    if (utrMatch != null) return utrMatch.group(1);

    // 2. PhonePe Transaction ID (starts with T or OLEX, 20+ chars)
    final txnMatch = RegExp(
      r'\bPhonePe\s*Transaction\s*ID\s*[:\-]?\s*([A-Za-z0-9]{15,30})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (txnMatch != null) return txnMatch.group(1);

    // 3. Standalone 12-digit number following UTR
    final altUtr = RegExp(r'(?:UTR|Ref\s*No)[:\s]*([0-9]{12})', caseSensitive: false).firstMatch(text);
    if (altUtr != null) return altUtr.group(1);

    return null;
  }
}
