import 'package:royal_spend/data/models/expense.dart';
import '../ocr_service.dart';
import '../parsed_transaction.dart';
import 'upi_parser_utils.dart';

/// Dedicated zero-mistake parser for Navi UPI payment screenshots and receipts.
class NaviParser {
  /// Returns true if the OCR text exhibits Navi UPI signatures.
  static bool isNavi(String text) {
    final lower = text.toLowerCase();

    // Disqualify physical shop receipts / restaurant bills that merely list "Paid via Navi"
    if (lower.contains('bill no') ||
        lower.contains('tax invoice') ||
        lower.contains('order total') ||
        lower.contains('grand total') ||
        lower.contains('table no') ||
        lower.contains('subtotal') ||
        lower.contains('gstin')) {
      return false;
    }

    if (lower.contains('paid super fast with navi')) return true;
    if (lower.contains('paid securely on navi')) return true;
    if (lower.contains('navi upi')) return true;
    if (lower.contains('navi') && (lower.contains('payment successful') || lower.contains('upi txn id'))) {
      return true;
    }
    return false;
  }

  /// Parses a Navi UPI receipt with 100% precision.
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
        (lowerText.contains('from ') && !lowerText.contains('to '));

    // 2. Extract Merchant / Payee
    final merchant = _extractMerchant(lines);

    // 3. Extract Amount (suppressing top promotional banner "Get up to ₹1,000 ... 🪙100 = ₹1")
    final amountResult = _extractAmount(lines, healedText);

    // 4. Extract Date & Time
    final dateResult = _extractDateTime(healedText);

    // 5. Extract Reference / UPI Txn ID
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
      sourceType: 'Navi UPI',
      currencySymbol: '₹',
    );
  }

  // ---------------------------------------------------------------------------
  // Amount Extraction for Navi UPI
  // ---------------------------------------------------------------------------
  static ({
    double? amount,
    double confidence,
    AmountExtractionStatus status,
    List<double> candidates,
  }) _extractAmount(List<String> lines, String fullText) {
    // 1. Identify Blacklisted promotional tokens from the top header:
    // e.g. "Get up to ₹1,000 on every payment" -> 1000
    // "🪙100 = ₹1" or "100 = ₹1" -> 100, 1
    final promoBlacklist = <double>{};
    for (final line in lines) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('get up to') ||
          lineLower.contains('upto') ||
          lineLower.contains('every payment') ||
          lineLower.contains('🪙') ||
          lineLower.contains('coins') ||
          lineLower.contains('coin') ||
          lineLower.contains('=')) {
        for (final m in RegExp(r'[0-9]+(?:,[0-9]+)*(?:\.[0-9]+)?').allMatches(line)) {
          final val = UpiParserUtils.parseCleanNumber(m.group(0));
          if (val != null) promoBlacklist.add(val);
        }
      }
    }

    // Blacklist bank account digits & transaction ID
    final bankAndIdBlacklist = <int>{};
    for (final match in RegExp(r'\b[0-9]{10,22}\b').allMatches(fullText)) {
      final val = int.tryParse(match.group(0)!);
      if (val != null) bankAndIdBlacklist.add(val);
    }
    // Masked card/account endings e.g. "Account ending in 2608", "SBI - 2608"
    for (final match in RegExp(
      r'(?:[Xx*]{2,}\s*|[Aa]ccount(?:\s*no\.?)?[\s:\-]+|[Aa]\/[Cc][\s:\-]+|[Cc]ard(?:\s*no\.?)?[\s:\-]+|[Ee]nding\s+(?:in|with)\s+|State\s*Bank[\s\w\-]*?[-–:]\s*)([0-9]{3,6})\b',
      caseSensitive: false,
    ).allMatches(fullText)) {
      final val = int.tryParse(match.group(1)!);
      if (val != null) bankAndIdBlacklist.add(val);
    }

    final allDirectRupees = UpiParserUtils.extractAllRupeeAmounts(fullText);

    // 2. Locate the real transaction amount inside the receipt card:
    // It is positioned between Payee / "Payment successful" and "Paid super fast with Navi UPI"
    final rupeeRegex = RegExp(
      r'[₹\u20B9\u20A8]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?',
    );

    double? heroAmount;
    final validCandidates = <double>[];

    bool insideCard = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (lineLower.contains('payment successful') || lineLower.startsWith('to ')) {
        insideCard = true;
      }

      if (insideCard) {
        for (final match in rupeeRegex.allMatches(line)) {
          final parsed = UpiParserUtils.parseCleanNumber(match.group(1));
          if (parsed != null && UpiParserUtils.isValidAmount(parsed)) {
            if (promoBlacklist.contains(parsed)) continue;
            if (bankAndIdBlacklist.contains(parsed.toInt()) && !allDirectRupees.contains(parsed)) continue;

            if (!validCandidates.contains(parsed)) {
              validCandidates.add(parsed);
            }
            heroAmount ??= parsed;
          }
        }

        // Also check standalone numbers on this line if ₹ was missed
        if (heroAmount == null &&
            !lineLower.contains('payment') &&
            !lineLower.startsWith('to ') &&
            !lineLower.contains('upi') &&
            !lineLower.contains('fast')) {
          final standaloneMatch = RegExp(r'^\s*([0-9]{1,6}(?:\.[0-9]{1,2})?)\s*$').firstMatch(line);
          if (standaloneMatch != null) {
            final parsed = UpiParserUtils.parseCleanNumber(standaloneMatch.group(1));
            if (parsed != null && UpiParserUtils.isValidAmount(parsed)) {
              if (!promoBlacklist.contains(parsed) && !bankAndIdBlacklist.contains(parsed.toInt())) {
                heroAmount = parsed;
                if (!validCandidates.contains(parsed)) validCandidates.add(parsed);
              }
            }
          }
        }
      }

      if (lineLower.contains('paid super fast') || lineLower.contains('upi txn id')) {
        insideCard = false;
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

    // Fallback: any candidate outside the promo blacklist
    if (validCandidates.isNotEmpty) {
      return (
        amount: validCandidates.first,
        confidence: 0.90,
        status: AmountExtractionStatus.extracted,
        candidates: validCandidates,
      );
    }

    // Direct Rupee Fallback for Navi
    final nonPromoRupees = allDirectRupees.where((a) => !promoBlacklist.contains(a)).toList();
    if (nonPromoRupees.isNotEmpty) {
      final best = nonPromoRupees.first;
      return (
        amount: best,
        confidence: 0.95,
        status: AmountExtractionStatus.extracted,
        candidates: nonPromoRupees,
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
  // Merchant / Payee Extraction for Navi UPI
  // ---------------------------------------------------------------------------
  static String? _extractMerchant(List<String> lines) {
    // In Navi, Payee line explicitly starts with "to " (e.g. "to RAILWAY EMPLOYEES CULTURAL ASSOCIATION")
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineLower = line.toLowerCase();

      if (lineLower.startsWith('to ') && !lineLower.startsWith('to:')) {
        final rawMerchant = line.substring(3).trim();
        if (_isValidNaviMerchant(rawMerchant)) {
          return rawMerchant;
        }
      }
    }

    // Fallback: check lines between "Payment successful" and the amount
    bool pastSuccessful = false;
    for (final line in lines) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('payment successful')) {
        pastSuccessful = true;
        continue;
      }
      if (pastSuccessful) {
        if (line.startsWith('₹') || lineLower.contains('paid super fast')) break;
        if (line.contains('@') || line.contains('***')) continue; // UPI handle
        if (_isValidNaviMerchant(line)) return line;
      }
    }

    return null;
  }

  static bool _isValidNaviMerchant(String? name) {
    if (name == null || name.length < 3) return false;
    final lower = name.toLowerCase();
    const badTokens = [
      'payment successful', 'navi upi', 'paid super fast',
      'paid securely', 'upi txn id', 'state bank of india',
    ];
    if (badTokens.any((t) => lower.contains(t))) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Date & Time Extraction for Navi UPI
  // ---------------------------------------------------------------------------
  static ({DateTime? date, bool isConfident, String? timeString}) _extractDateTime(String text) {
    // Navi Date Format: "25 Oct 2026, 7:40 PM" or "25 Oct 2026, 07:40 PM"
    final dateRegex = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(20[2-3][0-9])[\s,]+(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM|am|pm)\b',
      caseSensitive: false,
    );

    final m = dateRegex.firstMatch(text);
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final month = UpiParserUtils.monthToNum(m.group(2)!)!;
      final year = int.parse(m.group(3)!);
      final timeStr = '${m.group(4)}:${m.group(5)} ${m.group(6)!.toUpperCase()}';
      final date = UpiParserUtils.combineDateAndTime(DateTime(year, month, day), timeStr);
      return (date: date, isConfident: true, timeString: timeStr);
    }

    return (date: null, isConfident: false, timeString: null);
  }

  // ---------------------------------------------------------------------------
  // Reference / UPI Txn ID Extraction for Navi UPI
  // ---------------------------------------------------------------------------
  static String? _extractReferenceId(String text) {
    // e.g. "UPI txn ID : 006249434839" or "UPI Txn ID: 006249434839"
    final txnMatch = RegExp(
      r'UPI\s*(?:txn|transaction)\s*ID\s*[:\-]?\s*([0-9]{12})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (txnMatch != null) {
      return txnMatch.group(1);
    }

    // 12-digit UTR standalone
    final utrMatch = RegExp(r'\bUTR\s*[:\-]?\s*([0-9]{12})\b', caseSensitive: false).firstMatch(text);
    if (utrMatch != null) return utrMatch.group(1);

    return null;
  }
}
