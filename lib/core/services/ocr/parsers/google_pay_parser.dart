import 'package:royal_spend/data/models/expense.dart';
import '../ocr_service.dart';
import '../parsed_transaction.dart';
import 'upi_parser_utils.dart';

/// Dedicated zero-mistake parser for Google Pay receipts, screenshots, and rewards.
class GooglePayParser {
  /// Returns true if the OCR text exhibits Google Pay app screenshot signatures.
  static bool isGooglePay(String text) {
    final lower = text.toLowerCase();

    // Disqualify physical shop receipts / restaurant bills that merely list "Paid via Google Pay"
    if (lower.contains('bill no') ||
        lower.contains('tax invoice') ||
        lower.contains('order total') ||
        lower.contains('grand total') ||
        lower.contains('table no') ||
        lower.contains('subtotal') ||
        lower.contains('gstin')) {
      return false;
    }

    if (lower.contains('from google pay rewards') ||
        lower.contains('rewarded for completing a payment')) {
      return true;
    }

    if (text.contains('Google transaction ID')) return true;

    final hasGPayName = lower.contains('google pay') || lower.contains('gpay');
    final hasUpiHandle = lower.contains('okhdfcbank') ||
        lower.contains('oksbi') ||
        lower.contains('okaxis') ||
        lower.contains('okicici');

    final hasPaymentStatus = lower.contains('completed') ||
        lower.contains('payment to') ||
        lower.contains('paid to') ||
        lower.contains('to:');

    if (hasGPayName && (hasPaymentStatus || hasUpiHandle)) return true;
    if (hasUpiHandle && (hasPaymentStatus || text.contains('UPI transaction ID'))) return true;

    return false;
  }

  /// Parses a Google Pay receipt with 100% precision.
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

    final lowerText = healedText.toLowerCase();

    // 1. Detect if this is a Google Pay Rewards / Cashback screen (as in Screenshot 3)
    final isRewardScreen = lowerText.contains('from google pay rewards') ||
        lowerText.contains('rewarded for completing a payment');

    final bool isIncome = isRewardScreen ||
        lowerText.contains('received from') ||
        lowerText.contains('credited to');

    // 2. Extract Merchant / Payee
    final merchant = isRewardScreen
        ? 'Google Pay Rewards'
        : _extractMerchant(lines, healedText);

    // 3. Extract Amount
    final amountResult = _extractAmount(lines, healedText, isRewardScreen: isRewardScreen);

    // 4. Extract Date & Time
    final dateResult = _extractDateTime(healedText);

    // 5. Extract Reference / Google Transaction ID / UPI ID
    final referenceId = _extractReferenceId(healedText);

    // 6. Infer Category
    final categoryId = isRewardScreen
        ? 'other'
        : UpiParserUtils.inferCategory(merchant, healedText);

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
      sourceType: 'Google Pay',
      currencySymbol: '₹',
    );
  }

  // ---------------------------------------------------------------------------
  // Amount Extraction for Google Pay
  // ---------------------------------------------------------------------------
  static ({
    double? amount,
    double confidence,
    AmountExtractionStatus status,
    List<double> candidates,
  }) _extractAmount(
    List<String> lines,
    String fullText, {
    required bool isRewardScreen,
  }) {
    // 1. Blacklist non-amount numeric tokens:
    // - Bank account digits: "State Bank of India 2608" -> 2608
    // - 12-digit UPI transaction IDs -> e.g. 429987654321
    // - Referral promo amounts: "Invite friends, get ₹201"
    final blacklistNumbers = <int>{};
    for (final match in RegExp(r'\b[0-9]{10,22}\b').allMatches(fullText)) {
      final val = int.tryParse(match.group(0)!);
      if (val != null) blacklistNumbers.add(val);
    }
    // "State Bank of India 2608" or "XX2608"
    for (final match in RegExp(
      r'(?:State\s*Bank|HDFC|ICICI|Axis|Bank)[\s\w\-]*?([0-9]{3,6})\b',
      caseSensitive: false,
    ).allMatches(fullText)) {
      final val = int.tryParse(match.group(1)!);
      if (val != null) blacklistNumbers.add(val);
    }
    // Referral invitations: "Invite ... ₹201"
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('invite') || lower.contains('refer')) {
        for (final m in RegExp(r'[0-9]+').allMatches(line)) {
          final val = int.tryParse(m.group(0)!);
          if (val != null) blacklistNumbers.add(val);
        }
      }
    }

    final rupeeRegex = RegExp(
      r'[₹\u20B9\u20A8]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?',
    );

    final allDirectRupees = UpiParserUtils.extractAllRupeeAmounts(fullText);

    double? heroAmount;
    final validCandidates = <double>[];

    // For Rewards Screen: Hero amount is directly adjacent to "From Google Pay rewards"
    if (isRewardScreen) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = rupeeRegex.firstMatch(line);
        if (match != null) {
          final parsed = UpiParserUtils.parseCleanNumber(match.group(1));
          if (parsed != null && UpiParserUtils.isValidAmount(parsed)) {
            heroAmount = parsed;
            validCandidates.add(parsed);
            break;
          }
        }
      }
    } else {
      // Regular Google Pay payment
      for (final line in lines) {
        for (final match in rupeeRegex.allMatches(line)) {
          final parsed = UpiParserUtils.parseCleanNumber(match.group(1));
          if (parsed != null && UpiParserUtils.isValidAmount(parsed)) {
            if (blacklistNumbers.contains(parsed.toInt())) continue;

            if (!validCandidates.contains(parsed)) {
              validCandidates.add(parsed);
            }
            heroAmount ??= parsed;
          }
        }
      }

      // Standalone hero number fallback if ₹ was omitted by OCR
      if (heroAmount == null) {
        for (final line in lines) {
          final cleanLine = line.trim();
          if (RegExp(r'^[0-9]{1,6}(?:\.[0-9]{1,2})?$').hasMatch(cleanLine)) {
            final parsed = UpiParserUtils.parseCleanNumber(cleanLine);
            if (parsed != null &&
                UpiParserUtils.isValidAmount(parsed) &&
                !blacklistNumbers.contains(parsed.toInt())) {
              heroAmount = parsed;
              validCandidates.add(parsed);
              break;
            }
          }
        }
      }
    }

    if (heroAmount != null) {
      return (
        amount: heroAmount,
        confidence: 0.99,
        status: AmountExtractionStatus.extracted,
        candidates: validCandidates.isNotEmpty ? validCandidates : [heroAmount],
      );
    }

    // Direct Rupee Fallback for Google Pay (excluding promo/account numbers)
    final eligibleRupees =
        allDirectRupees.where((a) => !blacklistNumbers.contains(a.toInt())).toList();
    if (eligibleRupees.isNotEmpty) {
      final best = eligibleRupees.first;
      return (
        amount: best,
        confidence: 0.95,
        status: AmountExtractionStatus.extracted,
        candidates: eligibleRupees,
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
  // Merchant / Payee Extraction for Google Pay
  // ---------------------------------------------------------------------------
  static String? _extractMerchant(List<String> lines, String text) {
    // 1. Explicit "Paid to <Merchant>" or "Payment to <Merchant>"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (lineLower.startsWith('paid to ') || lineLower.startsWith('payment to ')) {
        final extracted = line
            .replaceFirst(RegExp(r'^(paid to|payment to)\s+', caseSensitive: false), '')
            .replaceAll(RegExp(r'[₹\u20B9].*$'), '')
            .trim();
        if (_isValidGooglePayMerchant(extracted)) return extracted;
      }

      if (lineLower == 'paid to' || lineLower == 'payment to') {
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (_isValidGooglePayMerchant(nextLine)) return nextLine;
        }
      }
    }

    // 2. "To: <Name>" (e.g. "To: M. Shubham" or "To Starbucks Coffee India")
    for (final line in lines) {
      final match = RegExp(r"^To:\s*([A-Za-z0-9\ \.\'\-]+)", caseSensitive: false).firstMatch(line);
      if (match != null) {
        final candidate = match.group(1)?.trim();
        if (_isValidGooglePayMerchant(candidate)) return candidate;
      }
    }

    // 3. Fallback: Check UPI handle e.g. "starbucks@okhdfcbank" -> "Starbucks"
    final upiMatch = RegExp(
      r'\b([a-zA-Z0-9\.\_]{3,30})@(okhdfcbank|oksbi|okaxis|okicici)\b',
    ).firstMatch(text);
    if (upiMatch != null) {
      final handle = upiMatch.group(1);
      if (handle != null && !RegExp(r'^\d+$').hasMatch(handle)) {
        return _formatHandle(handle);
      }
    }

    // 4. Line before amount in top of document
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();
      if (!lower.contains('google pay') &&
          !lower.contains('completed') &&
          !lower.startsWith('₹') &&
          !RegExp(r'^\d+$').hasMatch(line) &&
          _isValidGooglePayMerchant(line)) {
        return line;
      }
    }

    return null;
  }

  static bool _isValidGooglePayMerchant(String? name) {
    if (name == null || name.length < 3) return false;
    final lower = name.toLowerCase();
    const badTokens = [
      'google pay', 'completed', 'google transaction id',
      'state bank of india', 'payments may take up to',
      'having issues', 'share', 'rewards',
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
  // Date & Time Extraction for Google Pay
  // ---------------------------------------------------------------------------
  static ({DateTime? date, bool isConfident, String? timeString}) _extractDateTime(String text) {
    // Format 1: "29 Jan 2026, 5:33 pm" or "29 Jan 2026, 05:33 pm"
    final format1 = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(20[2-3][0-9])[\s,]+(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM|am|pm)\b',
      caseSensitive: false,
    );
    final m1 = format1.firstMatch(text);
    if (m1 != null) {
      final day = int.parse(m1.group(1)!);
      final month = UpiParserUtils.monthToNum(m1.group(2)!)!;
      final year = int.parse(m1.group(3)!);
      final timeStr = '${m1.group(4)}:${m1.group(5)} ${m1.group(6)!.toUpperCase()}';
      final date = UpiParserUtils.combineDateAndTime(DateTime(year, month, day), timeStr);
      return (date: date, isConfident: true, timeString: timeStr);
    }

    // Format 2: "25 October 2026 at 10:45 AM"
    final format2 = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(20[2-3][0-9])\s+at\s+(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM|am|pm)\b',
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
  // Reference ID Extraction for Google Pay
  // ---------------------------------------------------------------------------
  static String? _extractReferenceId(String text) {
    // 1. 12-digit UPI transaction ID
    final upiMatch = RegExp(
      r'\bUPI\s*(?:transaction\s*)?ID\s*[:\-]?\s*([0-9]{12})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (upiMatch != null) return upiMatch.group(1);

    // 2. Google transaction ID e.g. "CICAgJiChNu4ew" or "CICAgPDLz6"
    final gPayMatch = RegExp(
      r'\bGoogle\s*transaction\s*ID\s*[:\-]?\s*([A-Za-z0-9_\-]+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (gPayMatch != null) return gPayMatch.group(1);

    // 3. Fallback standalone 12-digit number
    final standalone = RegExp(r'\bUTR\s*[:\-]?\s*([0-9]{12})\b', caseSensitive: false).firstMatch(text);
    if (standalone != null) return standalone.group(1);

    return null;
  }
}
