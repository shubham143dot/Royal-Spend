import 'package:royal_spend/data/models/expense.dart';
import 'ocr_service.dart';
import 'parsed_transaction.dart';
import 'parsers/google_pay_parser.dart';
import 'parsers/navi_parser.dart';
import 'parsers/phonepe_parser.dart';
import 'parsers/upi_parser_utils.dart';

/// Intelligent heuristic, spatial geometry, and regular expression parser for financial
/// transactions, physical receipts, card slips, and Indian UPI payment screenshots.
class ReceiptParser {
  /// Parses raw OCR text and optional physical line bounding boxes into a structured [ParsedTransaction].
  static ParsedTransaction parse(
    String rawText, {
    String? imagePath,
    List<OcrLineData>? ocrLines,
  }) {
    final cleanedText = rawText.trim();
    if (cleanedText.isEmpty) {
      return ParsedTransaction(
        categoryId: 'other',
        paymentMethod: PaymentMethod.other,
        rawText: '',
        imagePath: imagePath,
      );
    }

    // 0. Dedicated zero-mistake parsers for PhonePe, Navi, and Google Pay
    if (PhonePeParser.isPhonePe(cleanedText)) {
      final phonePeResult = PhonePeParser.parse(
        cleanedText,
        imagePath: imagePath,
        ocrLines: ocrLines,
      );
      if (phonePeResult != null && phonePeResult.amount != null) {
        return phonePeResult;
      }
    }

    if (NaviParser.isNavi(cleanedText)) {
      final naviResult = NaviParser.parse(
        cleanedText,
        imagePath: imagePath,
        ocrLines: ocrLines,
      );
      if (naviResult != null && naviResult.amount != null) {
        return naviResult;
      }
    }

    if (GooglePayParser.isGooglePay(cleanedText)) {
      final gPayResult = GooglePayParser.parse(
        cleanedText,
        imagePath: imagePath,
        ocrLines: ocrLines,
      );
      if (gPayResult != null && gPayResult.amount != null) {
        return gPayResult;
      }
    }

    // 1. Clean, repair kerning spaces in numbers, and pre-merge split currency lines
    final lines = _cleanAndPrepareLines(cleanedText, ocrLines: ocrLines);

    // 2. Detect Source Type (PhonePe, Google Pay, Paytm, CRED, Card Slip, POS, etc.)
    final sourceType = _detectSourceType(cleanedText);

    // 3. Detect Amount & Alternative Candidates with Visual Geometry
    final amountResult = _extractAmount(
      lines,
      cleanedText,
      sourceType,
      ocrLines: ocrLines,
    );

    // 4. Detect Date & Time
    final dateResult = _extractDateTime(cleanedText, lines);

    // 5. Detect Merchant / Payee
    final merchant = _extractMerchant(lines, cleanedText, sourceType);

    // 6. Detect Reference / UTR / Invoice Number
    final referenceId = _extractReferenceId(cleanedText, lines);

    // 7. Infer Payment Method
    final paymentMethod = _detectPaymentMethod(cleanedText, sourceType);

    // 8. Infer Category
    final categoryId = _inferCategory(merchant, cleanedText);

    // 9. Detect Currency Symbol ('₹', '$', '€', '£')
    final currencySymbol = _detectCurrencySymbol(cleanedText);

    var primaryAmount = amountResult.primaryAmount;
    var amountStatus = amountResult.status;
    var candidateAmounts = amountResult.candidates;
    var confidence = amountResult.confidence;

    // Direct Rupee Fallback: If amount wasn't extracted, but the text contains any ₹ with a number,
    // extract it if there is a single clear amount. If multiple amounts exist without a clear total,
    // mark as ambiguous to allow manual correction rather than blindly guessing the first number.
    if (primaryAmount == null &&
        amountStatus != AmountExtractionStatus.invalid &&
        amountStatus != AmountExtractionStatus.ambiguous) {
      final lower = cleanedText.toLowerCase();
      final isPromoOrBal = lower.contains('cashback') ||
          lower.contains('reward') ||
          lower.contains('balance') ||
          lower.contains('scratch card');
      if (!isPromoOrBal) {
        final directRupees = UpiParserUtils.extractAllRupeeAmounts(cleanedText);
        if (directRupees.length == 1) {
          primaryAmount = directRupees.first;
          amountStatus = AmountExtractionStatus.extracted;
          confidence = 0.90;
          candidateAmounts = directRupees;
        } else if (directRupees.length > 1) {
          primaryAmount = null;
          amountStatus = AmountExtractionStatus.ambiguous;
          confidence = 0.50;
          candidateAmounts = directRupees;
        }
      }
    }

    return ParsedTransaction(
      merchant: merchant,
      amount: primaryAmount,
      isIncome: _isIncomingTransaction(cleanedText),
      amountConfidence: confidence,
      amountStatus: amountStatus,
      candidateAmounts: candidateAmounts,
      date: dateResult.date,
      hasConfidentDate: dateResult.isConfident,
      timeString: dateResult.timeString,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      referenceId: referenceId,
      rawText: cleanedText,
      imagePath: imagePath,
      sourceType: sourceType,
      currencySymbol: currencySymbol,
    );
  }

  static String _detectCurrencySymbol(String text) {
    if (text.contains('\$') ||
        RegExp(r'\b(?:USD|US\$)\b', caseSensitive: false).hasMatch(text)) {
      return '\$';
    }
    if (text.contains('€') ||
        RegExp(r'\bEUR\b', caseSensitive: false).hasMatch(text)) {
      return '€';
    }
    if (text.contains('£') ||
        RegExp(r'\bGBP\b', caseSensitive: false).hasMatch(text)) {
      return '£';
    }
    return '₹';
  }

  // ---------------------------------------------------------------------------
  // Text Preprocessing & OCR Artifact Healing
  // ---------------------------------------------------------------------------
  static List<String> _cleanAndPrepareLines(
    String rawText, {
    List<OcrLineData>? ocrLines,
  }) {
    // 0. Clean invisible and non-breaking Unicode characters, repair kerning & pre-merge split lines
    var text = UpiParserUtils.cleanText(rawText);

    // 1. Heal all Rupee symbol representations and misreads into clean standard "₹ <number>"
    text = UpiParserUtils.healRupeeGlyphs(text);

    // 2. Normalize spacing between currency and digits: "₹ 500", "$ 45.50", "USD 100"
    text = text.replaceAllMapped(
      RegExp(
        r'''([₹\u20B9\u20A8\$€£]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?)[ \t]{2,}''',
        caseSensitive: false,
      ),
      (m) => '${m[1]} ',
    );

    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 4. Pre-merge split currency and amount lines
    // In Google ML Kit, the currency symbol (₹, $, Rs, USD) is sometimes on line i, and amount on line i+1.
    final List<String> merged = [];
    for (int i = 0; i < rawLines.length; i++) {
      final current = rawLines[i];

      // If current line is ONLY currency symbol/punctuation and next line starts with a number
      if (RegExp(
            r'^(?:[₹\u20B9\u20A8\$€£\?¿*•Ff=~rR]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?)\s*$',
            caseSensitive: false,
          ).hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (RegExp(r'^[0-9]').hasMatch(next)) {
          merged.add('$current $next');
          i++; // skip next line since merged
          continue;
        }
      }

      // If current line ends with a currency symbol (e.g. "Total ₹" or "Amount Paid (₹)" or "Paid: ₹")
      if (RegExp(
            r'(?:[₹\u20B9\u20A8\$€£]|Rs\.?|RS\.?|INR|USD|EUR|GBP|\(₹\)|\(Rs\.?\))\s*$',
            caseSensitive: false,
          ).hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (RegExp(r'^[0-9]').hasMatch(next)) {
          merged.add('$current $next');
          i++; // skip next line
          continue;
        }
      }

      // If current line ends with a number and next line is ONLY currency symbol
      if (RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (RegExp(
          r'^(?:[₹\u20B9\u20A8\$€£\?¿*•Ff=~]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?)\s*$',
          caseSensitive: false,
        ).hasMatch(next)) {
          merged.add('$next $current');
          i++; // skip next line
          continue;
        }
      }

      // If current line ends with a number and next line is just a trailing slash "/-" or "/="
      if (RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (next == '/-' ||
            next == '/' ||
            next == '/ -' ||
            next == '/=' ||
            next == '=') {
          merged.add('$current/-');
          i++; // skip next line
          continue;
        }
      }

      merged.add(current);
    }

    // 5. Merge visually clustered reading rows from ocrLines if provided
    if (ocrLines != null && ocrLines.isNotEmpty) {
      for (final visualLine in ocrLines) {
        final vt = visualLine.text.trim();
        if (vt.isEmpty) continue;
        if (RegExp(r'[0-9]').hasMatch(vt) &&
            !merged.contains(vt) &&
            (vt.contains('   ') || RegExp(r'[a-zA-Z]').hasMatch(vt))) {
          merged.add(vt);
        }
      }
    }

    return merged;
  }

  // ---------------------------------------------------------------------------
  // Source Type Identification
  // ---------------------------------------------------------------------------
  static String _detectSourceType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('phonepe') ||
        lower.contains('ybl') ||
        lower.contains('ibl')) {
      return 'PhonePe UPI';
    }
    if (lower.contains('google pay') ||
        lower.contains('gpay') ||
        lower.contains('okhdfcbank') ||
        lower.contains('oksbi') ||
        lower.contains('okaxis')) {
      return 'Google Pay';
    }
    if (lower.contains('paytm') || lower.contains('@paytm')) {
      return 'Paytm';
    }
    if (lower.contains('cred') || lower.contains('@axisbank')) {
      return 'CRED UPI';
    }
    if (lower.contains('navi')) {
      return 'Navi UPI';
    }
    if (lower.contains('pine labs') ||
        lower.contains('pos sale') ||
        lower.contains('batch no') ||
        lower.contains('tid:') ||
        lower.contains('mid:')) {
      return 'Card Payment Slip';
    }
    if (lower.contains('bhim') ||
        lower.contains('super.money') ||
        lower.contains('tata neu') ||
        lower.contains('whatsapp') ||
        lower.contains('upi transaction id') ||
        lower.contains('upi ref') ||
        lower.contains('money transfer') ||
        lower.contains('payment successful')) {
      return 'UPI Payment';
    }
    if (lower.contains('tax invoice') ||
        lower.contains('bill no') ||
        lower.contains('gstin') ||
        lower.contains('pos receipt')) {
      return 'Store Receipt';
    }
    if (lower.contains('table no') ||
        lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('kfc') ||
        lower.contains('subtotal')) {
      return 'Restaurant Bill';
    }
    return 'Receipt / Screenshot';
  }

  // ---------------------------------------------------------------------------
  // Amount Extraction (Multi-Strategy, Visual Geometry & Scored Heuristics)
  // ---------------------------------------------------------------------------
  static _AmountResult _extractAmount(
    List<String> lines,
    String text,
    String sourceType, {
    List<OcrLineData>? ocrLines,
  }) {
    // Accept standard Western and Indian grouping. Whitespace is deliberately
    // not accepted inside numbers because it may separate adjacent OCR items.
    const amountToken =
        r'(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,8})(?:\.[0-9]{1,2})?';

    // 1. Currency prefixes pattern: ₹, INR, Rs., Rs, RS, Re., $, USD, US$, and OCR misread glyphs (?, *, •, F, f, =, ~, +)
    final currencyPattern = RegExp(
      r'''(?:[₹\u20B9\u20A8\$€£]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?|(?<=^|[\s\+:\-])[\?¿*•Ff=~]\s*|(?:\+\s*[₹\u20B9\u20A8\$€£\?¿*])|(?<=^|[\s:])r)\s*[:\-]?\s*(''' +
          amountToken +
          r''')(?![0-9.,])''',
      caseSensitive: false,
    );

    // 2. Trailing currency / slash pattern (e.g. 500/-, 1250/-, 500/=, 450.00 Rs, 50 USD, 24.99 $)
    final trailingCurrencyPattern = RegExp(
      r'''(?:^|[\s:\(])(''' +
          amountToken +
          r''')[ \t]*(?:[₹\u20B9\u20A8\$€£]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?|\/\-|\/[ \t]*\-|\/=)''',
      caseSensitive: false,
    );

    // 3. Standalone number line pattern (e.g. line that contains only "500", "₹500", "$45.50", "? 280", "1,250")
    final standaloneNumberLinePattern = RegExp(
      r'''^[^\w\d]*(''' + amountToken + r''')[^\w\d]*$''',
    );

    // 4. General number pattern anywhere in a line (optional decimals: 500, 280, 1250.00)
    final generalNumberPattern = RegExp(
      r'''(?:\b|^)(''' + amountToken + r''')\b''',
    );

    // Final payable keywords (Requirement 1: "Grand Total", "Total Amount", "Amount Paid", "Net Amount", "Total Payable")
    final finalPayableKeywords = [
      'grand total',
      'total amount',
      'amount paid',
      'net amount',
      'total payable',
      'net payable',
      'final total',
      'total due',
      'total paid',
      'paid amount',
      'bill total',
      'bill amount',
      'net bill',
      'total bill',
      'amount due',
      'you paid',
      'amount debited',
      'debited amount',
      'total sale',
      'net total',
    ];

    // Subtotal and pre-tax/discount breakdown keywords (must not beat final payable totals)
    final subtotalKeywords = [
      'sub total',
      'subtotal',
      'sub-total',
      'base amount',
      'item total',
      'items total',
      'gross amount',
      'gross total',
      'order total',
    ];

    // General total and payment amount keywords
    final generalTotalKeywords = [
      'total',
      'amount',
      'payable',
      'paid',
      'sale',
      'bill',
    ];

    // Primary High confidence keywords that announce transaction amounts
    final primaryAmountKeywords = [
      'amount paid',
      'transaction amount',
      'transfer amount',
      'amount received',
      'received amount',
      'amount credited',
      'credited amount',
      'amount debited',
      'amount sent',
      'received from',
      'you received',
      'payment received',
      'money received',
      'credited to',
      'debited to',
      'refund amount',
      'refund credited',
      'paid',
      'sent',
      'debited',
      'credited',
      'received',
      'total paid',
      'paid to',
      'paid amount',
      'grand total',
      'net amount',
      'total payable',
      'net payable',
      'bill amount',
      'final total',
      'paid by card',
      'paid by upi',
      'paid by cash',
      'amount debited',
      'debited amount',
      'debited with',
      'you paid',
      'payment of',
      'paid successfully',
      'payment successful',
      'transaction successful',
      'money sent',
      'money transfer successful',
      'total amount',
      'bill total',
      'sale amount',
      'transferred to',
      'sent to',
      'payment to',
    ];

    final mediumConfidenceKeywords = [
      'total',
      'amount',
      'payable',
      'sale',
      'bill',
    ];

    // Bank Account Source Keywords (indicate source account/card, NOT payment amount)
    final accountSourceKeywords = [
      'debited from',
      'paid from',
      'paid using',
      'from account',
      'transferred from',
      'debit from',
      'account ending',
      'card ending',
    ];

    // Bank balance keywords (disqualifies account balance from winning)
    final balanceKeywords = [
      'balance',
      'bank balance',
      'account balance',
      'available balance',
      'wallet balance',
      'closing balance',
      'closing bal',
      'avail bal',
      'bal:',
      'check balance',
      'balance inquiry',
      'main balance',
    ];

    // Promotional & reward keywords (disqualifies referral banners and scratch cards)
    final promotionalKeywords = [
      'cashback',
      'cash back',
      'reward',
      'rewards',
      'scratch card',
      'scratchcard',
      'invite',
      'referral',
      'refer',
      'earn',
      'earning',
      'earned',
      'won',
      'win',
      'upto',
      'up to',
      'coins',
      'cred coins',
      'neucoins',
      'supercash',
      'super cash',
      'coupon',
      'voucher',
      'discount voucher',
      'offer',
      'claim reward',
      'save ₹',
      'save \$',
    ];

    // Tendered cash on receipts (customer gave 500 for a 456 bill)
    final cashTenderedKeywords = [
      'tendered',
      'cash tendered',
      'cash received',
      'cash given',
    ];

    // Change returned to customer
    final changeKeywords = ['change', 'change due', 'return change'];

    // Terminal identifiers on EDC slips
    final terminalKeywords = [
      'tid:',
      'tid ',
      'mid:',
      'mid ',
      'batch no',
      'batch:',
      'invoice no',
      'inv no',
      'inv:',
      'stan:',
      'stan ',
      'auth code',
      'auth:',
      'rrn:',
      'rrn ',
      'roc:',
      'app code',
    ];

    // Taxes
    final taxKeywords = [
      'tax',
      'cgst',
      'sgst',
      'igst',
      'vat',
      'service charge',
    ];

    // Discounts
    final discountKeywords = [
      'discount',
      'savings',
      'saved',
      'flat ₹',
      'flat \$',
      'off on',
    ];

    // Item quantities & rates
    final itemCountKeywords = [
      'total items',
      'total qty',
      'item count',
      'no of items',
      'qty',
      'rate',
      'volume',
      'density',
    ];

    final isUpiOrDigital =
        sourceType.contains('UPI') ||
        sourceType.contains('Google Pay') ||
        sourceType.contains('PhonePe') ||
        sourceType.contains('Paytm') ||
        sourceType.contains('CRED') ||
        sourceType.contains('Payment');

    // Compute average line height if physical visual bounding boxes are provided
    double avgLineHeight = 32.0;
    if (ocrLines != null && ocrLines.isNotEmpty) {
      final validHeights = ocrLines
          .map((l) => l.height)
          .where((h) => h > 5)
          .toList();
      if (validHeights.isNotEmpty) {
        avgLineHeight =
            validHeights.reduce((a, b) => a + b) / validHeights.length;
      }
    }
    final visualLines = ocrLines == null
        ? const <OcrLineData?>[]
        : lines.map((line) => _findVisualLine(line, ocrLines)).toList();

    final Map<double, double> scoredCandidates = {};
    final Map<double, bool> hasDirectCurrencyMap = {};
    final Map<double, bool> hasKeywordAnchorMap =
        {}; // True if amount is on a primary-keyword line (Grand Total, Net Amount, etc.)
    final Map<double, bool> hasAmountLabelMap = {};
    final Map<double, bool> hasNearbyAmountLabelMap = {};
    final Map<double, bool> hasEligibleOccurrenceMap = {};
    final Map<double, bool> finalPayableCandidates = {};
    final Map<double, bool> generalTotalCandidates = {};
    final Map<double, bool> subtotalCandidates = {};
    final Set<double> discountAmounts = {};
    final Map<double, OcrLineData> candidateLineData = {};

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i].trim();
      if (rawLine.isEmpty) continue;
      final lineLower = rawLine.toLowerCase();

      // Mask out dates, times, phone numbers, card numbers, UPI handles, and UTRs before extracting numbers
      final String masked = _maskNonAmountTokens(rawLine);

      final isHighKeyword = primaryAmountKeywords.any(
        (k) => lineLower.contains(k),
      );
      final isMediumKeyword = mediumConfidenceKeywords.any(
        (k) => lineLower.contains(k),
      );

      // Check proximity to high/medium keywords on nearby lines (within ±3 lines)
      int? nearbyHighDistance;
      int? nearbyMediumDistance;
      for (final offset in [-3, -2, -1, 1, 2, 3]) {
        final targetIdx = i + offset;
        if (targetIdx >= 0 && targetIdx < lines.length) {
          final nearbyLower = lines[targetIdx].toLowerCase();
          if (ocrLines != null &&
              i < visualLines.length &&
              targetIdx < visualLines.length) {
            final currentGeometry = visualLines[i];
            final nearbyGeometry = visualLines[targetIdx];
            if (currentGeometry != null && nearbyGeometry != null) {
              final averageHeight =
                  (currentGeometry.height + nearbyGeometry.height) / 2;
              final currentCenter =
                  currentGeometry.top + currentGeometry.height / 2;
              final nearbyCenter =
                  nearbyGeometry.top + nearbyGeometry.height / 2;
              if (averageHeight > 0 &&
                  (currentCenter - nearbyCenter).abs() / averageHeight > 2.5) {
                continue;
              }
            }
          }
          if (primaryAmountKeywords.any((k) => nearbyLower.contains(k))) {
            if (nearbyHighDistance == null ||
                offset.abs() < nearbyHighDistance) {
              nearbyHighDistance = offset.abs();
            }
          } else if (mediumConfidenceKeywords.any(
            (k) => nearbyLower.contains(k),
          )) {
            if (nearbyMediumDistance == null ||
                offset.abs() < nearbyMediumDistance) {
              nearbyMediumDistance = offset.abs();
            }
          }
        }
      }

      // MULTI-LINE NEGATIVE PENALTY DETECTION:
      // Check current line AND preceding lines (i - 2, i - 1) for negative labels
      // Note: We only look BEHIND for labels, never ahead (a subsequent line like 'Cash Tendered' or 'Check Balance' describes that next line, not this one).
      // Note: terminalKeywords (TID, MID, INVOICE NO) only penalizes the exact line it appears on, not subsequent lines.
      bool isBalanceLine = balanceKeywords.any((k) => lineLower.contains(k));
      bool isPromotionalLine = promotionalKeywords.any(
        (k) => lineLower.contains(k),
      );
      bool isTenderedLine = cashTenderedKeywords.any(
        (k) => lineLower.contains(k),
      );
      bool isChangeLine = changeKeywords.any((k) => lineLower.contains(k));
      final bool isTerminalLine = terminalKeywords.any(
        (k) => lineLower.contains(k),
      );
      bool isAccountSourceLine = accountSourceKeywords.any(
        (k) => lineLower.contains(k),
      );

      for (final offset in [-2, -1]) {
        final targetIdx = i + offset;
        if (targetIdx >= 0 && targetIdx < lines.length) {
          final prevLower = lines[targetIdx].toLowerCase();
          if (balanceKeywords.any((k) => prevLower.contains(k))) {
            isBalanceLine = true;
          }
          if (promotionalKeywords.any((k) => prevLower.contains(k))) {
            isPromotionalLine = true;
          }
          if (cashTenderedKeywords.any((k) => prevLower.contains(k))) {
            isTenderedLine = true;
          }
          if (changeKeywords.any((k) => prevLower.contains(k))) {
            isChangeLine = true;
          }
          if (accountSourceKeywords.any((k) => prevLower.contains(k))) {
            isAccountSourceLine = true;
          }
        }
      }

      final isTaxLine = taxKeywords.any((k) => lineLower.contains(k));
      final isDiscountLine = discountKeywords.any((k) => lineLower.contains(k));
      final isItemCountLine = itemCountKeywords.any(
        (k) => lineLower.contains(k),
      );

      final bool isStandalone = standaloneNumberLinePattern.hasMatch(rawLine);

      // Helper to check if a line is a pure label line (contains label keyword with no amount digits)
      bool isPureKeywordLine(String line, List<String> keywords) {
        final lower = line.toLowerCase().trim();
        if (!keywords.any((k) => lower.contains(k))) return false;
        final m = _maskNonAmountTokens(line);
        return !currencyPattern.hasMatch(m) &&
            !trailingCurrencyPattern.hasMatch(m) &&
            !generalNumberPattern.hasMatch(m);
      }

      bool associatedFinalPayable = false;
      bool associatedSubtotal = false;
      bool associatedGenTotal = false;

      // Lookbehind: line i - 1, or line i - 2 if i - 1 is a separator
      int? prevLabelIdx;
      if (i > 0) {
        final prev1 = lines[i - 1].trim();
        if (isPureKeywordLine(prev1, finalPayableKeywords) ||
            isPureKeywordLine(prev1, subtotalKeywords) ||
            isPureKeywordLine(prev1, generalTotalKeywords)) {
          prevLabelIdx = i - 1;
        } else if (RegExp(r'^[-=_.*#~]{2,}$').hasMatch(prev1) || prev1.isEmpty) {
          if (i > 1) {
            final prev2 = lines[i - 2].trim();
            if (isPureKeywordLine(prev2, finalPayableKeywords) ||
                isPureKeywordLine(prev2, subtotalKeywords) ||
                isPureKeywordLine(prev2, generalTotalKeywords)) {
              prevLabelIdx = i - 2;
            }
          }
        }
      }

      if (prevLabelIdx != null) {
        final labelText = lines[prevLabelIdx].toLowerCase();
        if (finalPayableKeywords.any((k) => labelText.contains(k))) {
          associatedFinalPayable = true;
        } else if (subtotalKeywords.any((k) => labelText.contains(k))) {
          associatedSubtotal = true;
        } else if (generalTotalKeywords.any((k) => labelText.contains(k))) {
          associatedGenTotal = true;
        }
      }

      // Lookahead: line i + 1 (label below amount)
      if (!associatedFinalPayable && !associatedSubtotal && !associatedGenTotal) {
        if (i + 1 < lines.length) {
          final next1 = lines[i + 1].trim();
          if (isPureKeywordLine(next1, finalPayableKeywords)) {
            associatedFinalPayable = true;
          } else if (isPureKeywordLine(next1, subtotalKeywords)) {
            associatedSubtotal = true;
          } else if (isPureKeywordLine(next1, generalTotalKeywords)) {
            associatedGenTotal = true;
          }
        }
      }

      // Spatial visual line association using Google ML Kit line/block bounding boxes
      if (!associatedFinalPayable && !associatedSubtotal && !associatedGenTotal) {
        if (ocrLines != null && ocrLines.isNotEmpty && i < visualLines.length) {
          final currentGeom = visualLines[i];
          if (currentGeom != null) {
            for (final other in ocrLines) {
              final otherLower = other.text.toLowerCase();
              final isOtherFinal =
                  finalPayableKeywords.any((k) => otherLower.contains(k));
              final isOtherSub =
                  subtotalKeywords.any((k) => otherLower.contains(k));
              final isOtherGen =
                  generalTotalKeywords.any((k) => otherLower.contains(k));

              if (!isOtherFinal && !isOtherSub && !isOtherGen) continue;
              if (isOtherSub && isOtherFinal) continue;

              final isSameRow =
                  (currentGeom.top - other.top).abs() <= avgLineHeight * 0.7 &&
                      currentGeom.left > other.left;
              final isDirectlyAbove = other.top < currentGeom.top &&
                  (currentGeom.top - (other.top + other.height)) <=
                      avgLineHeight * 2.5 &&
                  (currentGeom.left - other.left).abs() <= avgLineHeight * 10;

              if (isSameRow || isDirectlyAbove) {
                if (isOtherFinal) {
                  associatedFinalPayable = true;
                  break;
                } else if (isOtherSub) {
                  associatedSubtotal = true;
                  break;
                } else if (isOtherGen) {
                  associatedGenTotal = true;
                  break;
                }
              }
            }
          }
        }
      }

      void evaluateMatch(
        String? numStr, {
        required bool hasCurrency,
        required bool hasTrailingSlash,
      }) {
        final parsed = _parseCleanNumber(numStr);
        if (parsed == null || !_isValidExpenseAmount(parsed)) return;

        double score = 0.50; // Neutral base score

        // Record whether this amount is directly associated with a currency symbol
        if (hasCurrency || hasTrailingSlash) {
          hasDirectCurrencyMap[parsed] = true;
        } else {
          hasDirectCurrencyMap[parsed] ??= false;
        }

        // Categorize candidate role: Final Payable, Subtotal, or General Total
        bool isFinal = finalPayableKeywords.any((k) => lineLower.contains(k)) ||
            associatedFinalPayable;
        bool isSubtotal = subtotalKeywords.any((k) => lineLower.contains(k)) ||
            associatedSubtotal;
        bool isGenTotal = generalTotalKeywords.any((k) => lineLower.contains(k)) ||
            associatedGenTotal;

        if (isFinal) {
          isSubtotal = false;
        }

        if (isFinal) {
          finalPayableCandidates[parsed] = true;
          hasKeywordAnchorMap[parsed] = true;
          hasAmountLabelMap[parsed] = true;
        } else if (isSubtotal) {
          subtotalCandidates[parsed] = true;
          hasKeywordAnchorMap[parsed] = true;
          hasAmountLabelMap[parsed] = true;
        } else if (isGenTotal) {
          generalTotalCandidates[parsed] = true;
          hasKeywordAnchorMap[parsed] = true;
          hasAmountLabelMap[parsed] = true;
        }

        // Keyword-anchor: amounts on high-confidence keyword lines or associated labels
        // are protected from bare-number elimination, even without a currency symbol.
        if (isHighKeyword || isFinal) {
          hasKeywordAnchorMap[parsed] = true;
        } else {
          hasKeywordAnchorMap[parsed] ??= false;
        }
        if (isHighKeyword ||
            isMediumKeyword ||
            isFinal ||
            isGenTotal ||
            isSubtotal) {
          hasAmountLabelMap[parsed] = true;
        } else {
          hasAmountLabelMap[parsed] ??= false;
        }
        if (nearbyHighDistance != null ||
            nearbyMediumDistance != null ||
            associatedFinalPayable ||
            associatedGenTotal) {
          hasNearbyAmountLabelMap[parsed] = true;
        } else {
          hasNearbyAmountLabelMap[parsed] ??= false;
        }
        if (isDiscountLine) {
          discountAmounts.add(parsed);
        }

        final isDisqualifiedLine =
            isBalanceLine ||
            isPromotionalLine ||
            (isAccountSourceLine && !hasCurrency) ||
            isTerminalLine ||
            isTenderedLine ||
            isChangeLine ||
            isTaxLine ||
            isDiscountLine ||
            isItemCountLine;
        if (!isDisqualifiedLine) hasEligibleOccurrenceMap[parsed] = true;

        // Find visual OCR line geometry:
        // Search ocrLines for this line or any line that contains numStr with maximum height
        OcrLineData? lineData = i < visualLines.length ? visualLines[i] : null;
        if (lineData == null && ocrLines != null && ocrLines.isNotEmpty) {
          final candidates = ocrLines
              .where((o) => o.text.contains(numStr ?? ''))
              .toList();
          if (candidates.isNotEmpty) {
            candidates.sort((a, b) => b.height.compareTo(a.height));
            lineData = candidates.first;
          }
        }

        // 1. Physical Visual Font Size Weighting (Prominent Hero Amounts in UPI Apps)
        if (lineData != null) {
          candidateLineData[parsed] = lineData;
          final fontRatio =
              lineData.height / (avgLineHeight > 0 ? avgLineHeight : 32.0);
          if (fontRatio >= 1.80) {
            score += 0.45; // Hero font size in UPI payment apps!
          } else if (fontRatio >= 1.40) {
            score += 0.30; // Large bold font
          } else if (fontRatio >= 1.15) {
            score += 0.15;
          } else if (fontRatio < 0.70) {
            score -= 0.20; // Fine print / footer footnote
          }
        }

        // 2. Direct Currency indicator bonus (Prioritizing ₹, Rs., INR, $, USD)
        if (hasCurrency) {
          if (rawLine.contains('₹') ||
              lineLower.contains('inr') ||
              lineLower.contains('eur') ||
              lineLower.contains('gbp') ||
              lineLower.contains('rs') ||
              rawLine.contains('\$') ||
              rawLine.contains('€') ||
              rawLine.contains('£') ||
              lineLower.contains('usd')) {
            score += 0.38; // Strong explicit currency symbol bonus
          } else {
            // Misread OCR symbol: ?, *, •, +, F, f
            score += 0.28;
          }
        }

        if (hasTrailingSlash) {
          score += 0.30;
        }

        // 3. Keyword / Label bonus
        if (isFinal) {
          score += 0.50; // Top priority for Grand Total, Total Amount, Net Amount, Amount Paid, etc.
        } else if (isGenTotal) {
          score += 0.35;
        } else if (isHighKeyword) {
          score += 0.40;
        } else if (isMediumKeyword) {
          score += 0.20;
        }

        // Subtotal penalty: ensure Grand Total and general totals beat subtotal
        if (isSubtotal) {
          score -= 0.45;
        }

        // 4. Proximity to keyword on nearby line (lookahead / lookbehind)
        // Subordinate lines (taxes, discounts, balances, change) do not inherit nearby total bonuses
        final isSubordinate =
            isTaxLine ||
            isDiscountLine ||
            isBalanceLine ||
            isTenderedLine ||
            isChangeLine;
        if (!isSubordinate) {
          if (!isHighKeyword && nearbyHighDistance != null) {
            if (nearbyHighDistance == 1) {
              score += 0.40;
            } else if (nearbyHighDistance == 2) {
              score += 0.28;
            } else {
              score += 0.18;
            }
          } else if (!isMediumKeyword && nearbyMediumDistance != null) {
            if (nearbyMediumDistance == 1) {
              score += 0.25;
            } else {
              score += 0.15;
            }
          }
        }

        // 5. Standalone line bonus (centered amount in UPI screenshots)
        if (isStandalone) {
          final hasAnyContext =
              hasCurrency ||
              hasTrailingSlash ||
              isHighKeyword ||
              isMediumKeyword ||
              isFinal ||
              isGenTotal ||
              nearbyHighDistance != null ||
              nearbyMediumDistance != null;
          if (hasAnyContext) {
            score += 0.25;
          }
        }

        // 6. Position bonus: Upper 50% of document is where UPI / payment apps highlight the hero amount
        if (isUpiOrDigital && i < (lines.length * 0.50).ceil()) {
          score += 0.10;
        }

        // 7. Decimals bonus (.00 or .50)
        if (numStr != null && numStr.contains('.')) {
          score += 0.02;
        }

        // 8. Strict Negative keyword disqualifications & penalties (Single & Multi-line)
        if (isBalanceLine) {
          score -= 0.95; // Account/bank balance must NEVER win
        }
        if (isPromotionalLine) {
          score -= 0.85; // Referral/scratch card/cashback banner must NEVER win
        }
        if (isAccountSourceLine && !hasCurrency) {
          score -= 0.85; // Bank card/account ending digits must NEVER win
        }
        if (isTerminalLine) {
          score -= 0.90; // TID/MID/STAN/INVOICE terminal IDs must NEVER win
        }
        if (isTenderedLine) {
          score -= 0.70; // Cash tendered must not beat actual bill total
        }
        if (isChangeLine) {
          score -= 0.70; // Change due must not beat bill total
        }
        if (isTaxLine) {
          score -= 0.55; // CGST/SGST/Tax must not beat grand total
        }
        if (isDiscountLine) {
          score -= 0.50; // Discount must not beat grand total
        }
        if (isItemCountLine) {
          score -= 0.65; // Total items/Qty must not win
        }

        score = score.clamp(0.05, 0.99);

        final currentBest = scoredCandidates[parsed] ?? 0.0;
        if (score > currentBest) {
          scoredCandidates[parsed] = score;
        }
      }

      // 1. Search for currency-prefixed amounts (₹ 500, $45.50, USD 120, Rs 450)
      for (final match in currencyPattern.allMatches(masked)) {
        if (!_hasSafeAmountMatchBoundaries(masked, match)) {
          continue;
        }
        evaluateMatch(
          match.group(1),
          hasCurrency: true,
          hasTrailingSlash: false,
        );
      }

      // 2. Search for trailing currency / slash amounts (e.g. 500/-, 450.00 Rs, 50 USD)
      for (final match in trailingCurrencyPattern.allMatches(masked)) {
        if (!_hasSafeAmountMatchBoundaries(masked, match)) {
          continue;
        }
        evaluateMatch(
          match.group(1),
          hasCurrency: true,
          hasTrailingSlash: true,
        );
      }

      // 3. If line is standalone or has keywords, search general numbers
      if (isStandalone ||
          isHighKeyword ||
          isMediumKeyword ||
          nearbyHighDistance != null ||
          associatedFinalPayable ||
          associatedSubtotal ||
          associatedGenTotal) {
        for (final match in generalNumberPattern.allMatches(masked)) {
          if (!_hasSafeAmountMatchBoundaries(masked, match)) {
            continue;
          }
          evaluateMatch(
            match.group(1),
            hasCurrency: false,
            hasTrailingSlash: false,
          );
        }
      }
    }

    // Fallback pass: scan masked lines for any remaining currency or trailing slash amounts
    if (scoredCandidates.isEmpty) {
      final maskedFullText = lines
          .map((l) => _maskNonAmountTokens(l))
          .join('\n');
      for (final match in currencyPattern.allMatches(maskedFullText)) {
        if (!_hasSafeAmountMatchBoundaries(maskedFullText, match)) {
          continue;
        }
        final parsed = _parseCleanNumber(match.group(1));
        if (parsed != null && _isValidExpenseAmount(parsed)) {
          final curr = scoredCandidates[parsed] ?? 0.0;
          if (0.75 > curr) scoredCandidates[parsed] = 0.75;
          hasDirectCurrencyMap[parsed] = true;
          hasEligibleOccurrenceMap[parsed] = true;
        }
      }

      for (final match in trailingCurrencyPattern.allMatches(maskedFullText)) {
        if (!_hasSafeAmountMatchBoundaries(maskedFullText, match)) {
          continue;
        }
        final parsed = _parseCleanNumber(match.group(1));
        if (parsed != null && _isValidExpenseAmount(parsed)) {
          final curr = scoredCandidates[parsed] ?? 0.0;
          if (0.70 > curr) scoredCandidates[parsed] = 0.70;
          hasDirectCurrencyMap[parsed] = true;
          hasEligibleOccurrenceMap[parsed] = true;
        }
      }
    }

    // =========================================================================
    // STRICT TIER 1+2 PRIORITIZATION (HARD ELIMINATION):
    //
    // TIER 1: Direct currency symbol (₹, Rs, INR, $, USD, /-)
    // TIER 2: Amount on or associated with a primary-keyword line (GRAND TOTAL, NET AMOUNT, AMOUNT PAID, etc.)
    // TIER 3: Bare number with no currency or keyword backing (could be table#, order#, etc.)
    //
    // If ANY Tier-1 or Tier-2 candidate scores >= 0.40, completely remove all Tier-3
    // bare numbers. A bare number like 730, 5, 12 must NEVER win over ₹1,250 or GRAND TOTAL:4620.
    // =========================================================================
    bool isProtected(double k) =>
        hasDirectCurrencyMap[k] == true ||
        hasKeywordAnchorMap[k] == true ||
        finalPayableCandidates[k] == true ||
        generalTotalCandidates[k] == true;

    final bestProtectedScore = scoredCandidates.entries
        .where((e) => isProtected(e.key))
        .fold(0.0, (best, e) => e.value > best ? e.value : best);

    if (bestProtectedScore >= 0.40) {
      // Hard remove all Tier-3 bare numbers — they cannot compete with protected amounts
      scoredCandidates.removeWhere((k, v) => !isProtected(k));
    } else if (bestProtectedScore >= 0.25) {
      // Softer context: floor bare numbers so protected amounts win
      for (final key in scoredCandidates.keys.toList()) {
        if (!isProtected(key)) {
          scoredCandidates[key] = 0.05;
        }
      }
    }

    if (scoredCandidates.isEmpty) {
      final directRupees = UpiParserUtils.extractAllRupeeAmounts(text);
      if (directRupees.isNotEmpty && !_hasMalformedCurrencyAmount(text)) {
        if (directRupees.length > 1) {
          return _AmountResult(
            primaryAmount: null,
            confidence: 0.50,
            candidates: directRupees,
            status: AmountExtractionStatus.ambiguous,
          );
        }
        return _AmountResult(
          primaryAmount: directRupees.first,
          confidence: 0.90,
          candidates: directRupees,
          status: AmountExtractionStatus.extracted,
        );
      }

      return _AmountResult(
        primaryAmount: null,
        confidence: 0.0,
        candidates: [],
        status: _hasMalformedCurrencyAmount(text)
            ? AmountExtractionStatus.invalid
            : AmountExtractionStatus.missing,
      );
    }

    // Mathematical Consistency Bonus for Receipts:
    if (scoredCandidates.length >= 2) {
      final keys = scoredCandidates.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        for (int j = i + 1; j < keys.length; j++) {
          final a = keys[i];
          final b = keys[j];

          // 1. Subtotal + Tax = Grand Total
          final sum = a + b;
          for (final totalKey in keys) {
            if ((sum - totalKey).abs() <= 1.50 &&
                totalKey > a &&
                totalKey > b) {
              if (!discountAmounts.contains(a) &&
                  !discountAmounts.contains(b)) {
                scoredCandidates[totalKey] =
                    ((scoredCandidates[totalKey] ?? 0.5) + 0.35).clamp(
                      0.05,
                      0.99,
                    );
              }
            }
          }

          // 2. Order Total - Discount = Grand Total
          for (final totalKey in keys) {
            if (discountAmounts.contains(b) &&
                (a - b - totalKey).abs() <= 1.50) {
              scoredCandidates[totalKey] =
                  ((scoredCandidates[totalKey] ?? 0.5) + 0.35).clamp(
                    0.05,
                    0.99,
                  );
            } else if (discountAmounts.contains(a) &&
                (b - a - totalKey).abs() <= 1.50) {
              scoredCandidates[totalKey] =
                  ((scoredCandidates[totalKey] ?? 0.5) + 0.35).clamp(
                    0.05,
                    0.99,
                  );
            }
          }
        }
      }
    }

    // Sort candidates using contextual priority rules:
    // 1. Final Payable labels (Grand Total, Total Amount, Net Amount, Amount Paid, Total Payable) strictly take precedence.
    // 2. Non-subtotal candidates strictly take precedence over subtotal candidates.
    // 3. General total candidates take precedence over unlabeled numbers.
    // 4. Significant score difference (> 0.05) decides.
    // 5. In UPI apps, larger font height decides.
    // 6. Natural score comparison (never blindly compare keys to favor the largest number).

    final sortedEntries = scoredCandidates.entries.toList()
      ..sort((a, b) {
        // 1. Final Payable candidate strictly takes precedence
        final aIsFinal = finalPayableCandidates[a.key] == true;
        final bIsFinal = finalPayableCandidates[b.key] == true;
        if (aIsFinal != bIsFinal) {
          return bIsFinal ? 1 : -1;
        }

        // 2. Non-subtotal strictly takes precedence over subtotal
        final aIsSubtotal = subtotalCandidates[a.key] == true;
        final bIsSubtotal = subtotalCandidates[b.key] == true;
        if (aIsSubtotal != bIsSubtotal) {
          return aIsSubtotal ? 1 : -1;
        }

        // 3. General total candidate takes precedence over unlabeled candidate
        final aIsGenTotal = generalTotalCandidates[a.key] == true;
        final bIsGenTotal = generalTotalCandidates[b.key] == true;
        if (aIsGenTotal != bIsGenTotal) {
          return bIsGenTotal ? 1 : -1;
        }

        // 4. Significant score difference (> 0.05)
        final scoreDiff = (b.value - a.value).abs();
        if (scoreDiff > 0.05) {
          return b.value.compareTo(a.value);
        }

        // 5. Visual font height in UPI / digital receipts
        if (isUpiOrDigital) {
          final heightA = candidateLineData[a.key]?.height ?? 0;
          final heightB = candidateLineData[b.key]?.height ?? 0;
          if ((heightB - heightA).abs() > 10) {
            return heightB.compareTo(heightA);
          }
        }

        // 6. Natural score comparison
        return b.value.compareTo(a.value);
      });

    final bestAmount = sortedEntries.isNotEmpty
        ? sortedEntries.first.key
        : null;
    final bestConfidence = sortedEntries.isNotEmpty
        ? sortedEntries.first.value
        : 0.0;

    // Filter candidate amounts so disqualified numbers (balance, rewards) are not exposed as pills
    final candidateAmounts = sortedEntries
        .where(
          (e) => e.value >= 0.35 && hasEligibleOccurrenceMap[e.key] == true,
        )
        .map((e) => e.key)
        .toList();

    final runnerUpScore = candidateAmounts.length > 1
        ? (scoredCandidates[candidateAmounts[1]] ?? 0.0)
        : 0.0;
    final clearScoreLead =
        candidateAmounts.length == 1 || bestConfidence - runnerUpScore >= 0.15;
    final isFinalPayable =
        bestAmount != null && finalPayableCandidates[bestAmount] == true;
    final hasAmountLabel =
        bestAmount != null && hasAmountLabelMap[bestAmount] == true;
    final hasNearbyAmountLabel =
        bestAmount != null && hasNearbyAmountLabelMap[bestAmount] == true;
    final hasExplicitCurrency =
        bestAmount != null && hasDirectCurrencyMap[bestAmount] == true;
    final hasEligibleOccurrence =
        bestAmount != null && hasEligibleOccurrenceMap[bestAmount] == true;

    // Determine if there is genuine ambiguity between top candidates (Requirement 7)
    bool hasAmbiguousCompetingCandidate = false;
    if (candidateAmounts.length >= 2) {
      final runnerUp = candidateAmounts[1];
      final runnerUpScoreVal = scoredCandidates[runnerUp] ?? 0.0;
      final scoreDiff = bestConfidence - runnerUpScoreVal;

      final bestIsFinal = finalPayableCandidates[bestAmount] == true;
      final runnerIsFinal = finalPayableCandidates[runnerUp] == true;
      final runnerIsSubtotal = subtotalCandidates[runnerUp] == true;
      final runnerHasTotalLabel =
          generalTotalCandidates[runnerUp] == true || runnerIsFinal;

      if (bestIsFinal) {
        if (runnerIsFinal) {
          // Both candidates are explicitly labeled Final Payable (e.g. Grand Total vs Net Amount)
          if (scoreDiff < 0.12) {
            hasAmbiguousCompetingCandidate = true;
          }
        } else if (runnerHasTotalLabel && !runnerIsSubtotal) {
          // Best is Final Payable, runner-up is another labeled total with very close score
          if (scoreDiff < 0.08) {
            hasAmbiguousCompetingCandidate = true;
          }
        }
      } else {
        // Best is NOT Final Payable
        if (runnerIsSubtotal) {
          if (scoreDiff < 0.08) {
            hasAmbiguousCompetingCandidate = true;
          }
        } else {
          // Neither is final payable, and runner-up is not a subtotal
          // e.g. Total: 450 vs Total: 500, or ₹12 vs ₹100
          if (scoreDiff < 0.12) {
            hasAmbiguousCompetingCandidate = true;
          }
        }
      }
    }

    final hasReliableEvidence =
        hasEligibleOccurrence &&
        !hasAmbiguousCompetingCandidate &&
        bestConfidence >= 0.50 &&
        (isFinalPayable ||
            hasAmountLabel ||
            hasExplicitCurrency ||
            hasNearbyAmountLabel ||
            clearScoreLead ||
            isUpiOrDigital);

    final isMalformed = _hasMalformedCurrencyAmount(text);
    var selectedAmount =
        (!isMalformed && hasReliableEvidence) ? bestAmount : null;
    if (selectedAmount == null &&
        !isMalformed &&
        bestAmount != null &&
        hasExplicitCurrency &&
        !hasAmbiguousCompetingCandidate &&
        hasEligibleOccurrence &&
        candidateAmounts.length == 1) {
      selectedAmount = bestAmount;
    }
    final status = isMalformed
        ? AmountExtractionStatus.invalid
        : selectedAmount != null
        ? AmountExtractionStatus.extracted
        : candidateAmounts.isNotEmpty
        ? AmountExtractionStatus.ambiguous
        : AmountExtractionStatus.missing;

    return _AmountResult(
      primaryAmount: selectedAmount,
      confidence: bestConfidence,
      candidates: candidateAmounts,
      status: status,
    );
  }

  static double? _parseCleanNumber(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    const validAmount =
        r'^(?:(?:[0-9]{1,3}(?:,[0-9]{3})+)|(?:[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3})|[0-9]{1,8})(?:\.[0-9]{1,2})?$';
    if (!RegExp(validAmount).hasMatch(cleaned)) return null;

    final normalized = cleaned.replaceAll(',', '');
    return double.tryParse(normalized);
  }

  static OcrLineData? _findVisualLine(
    String text,
    List<OcrLineData>? ocrLines,
  ) {
    if (ocrLines == null || ocrLines.isEmpty) return null;
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final normalizedText = normalize(text);
    if (normalizedText.isEmpty) return null;
    OcrLineData? best;
    var bestRatio = 0.0;
    for (final line in ocrLines) {
      final normalizedLine = normalize(line.text);
      if (normalizedLine.isEmpty ||
          !(normalizedLine.contains(normalizedText) ||
              normalizedText.contains(normalizedLine))) {
        continue;
      }
      final ratio =
          (normalizedText.length < normalizedLine.length
              ? normalizedText.length
              : normalizedLine.length) /
          (normalizedText.length > normalizedLine.length
              ? normalizedText.length
              : normalizedLine.length);
      if (ratio > bestRatio) {
        best = line;
        bestRatio = ratio;
      }
    }
    return best;
  }

  static bool _hasSafeAmountTokenBoundaries(String line, int start, int end) {
    bool isNumericPunctuation(String value) =>
        RegExp(r'[0-9,]').hasMatch(value);

    if (start > 0) {
      final prev = line[start - 1];
      if (isNumericPunctuation(prev)) return false;
      if (prev == '.') {
        final beforeDot =
            line.substring(0, start - 1).trimRight().toLowerCase();
        final isCurrencyDot = beforeDot.endsWith('rs') ||
            beforeDot.endsWith('re') ||
            beforeDot.endsWith('₹') ||
            beforeDot.endsWith('inr');
        if (!isCurrencyDot) return false;
      }
    }
    if (end < line.length &&
        (isNumericPunctuation(line[end]) || line[end] == '.')) {
      return false;
    }
    return true;
  }

  static bool _hasSafeAmountMatchBoundaries(String line, RegExpMatch match) {
    final value = match.group(1);
    if (value == null) return false;
    final groupOffset = match.group(0)!.indexOf(value);
    if (groupOffset < 0) return false;
    final start = match.start + groupOffset;
    return _hasSafeAmountTokenBoundaries(line, start, start + value.length);
  }

  static bool _hasMalformedCurrencyAmount(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 1. Currency followed by space-split digits on the same line WITHOUT following context: e.g. "₹1 2" or "You paid ₹1 2"
      final splitDigits = RegExp(
        r'''(?:[₹\u20B9\u20A8\$€£]|INR|USD|US\$|EUR|GBP|Rs\.?|Re\.?)[ \t]*[0-9]+[ \t]+[0-9]+(?!\s*(?:[a-zA-Z]{3,}|AM|PM|am|pm|st|nd|rd|th|items?|qty|rupees?|only))\b''',
        caseSensitive: false,
      );
      if (splitDigits.hasMatch(trimmed)) return true;

      // 2. Currency followed by invalid grouping (1 or 2 digits after comma at end of number): e.g. "₹1,2" or "₹1,23"
      // Must not match valid Indian grouping like "₹ 1,50,000" where a comma is followed by another comma
      final badGrouping = RegExp(
        r'''(?:[₹\u20B9\u20A8\$€£]|INR|USD|US\$|EUR|GBP|Rs\.?|Re\.?)[ \t]*[0-9]+,[0-9]{1,2}(?![0-9,])''',
        caseSensitive: false,
      );
      if (badGrouping.hasMatch(trimmed)) return true;
    }
    return false;
  }

  static bool _isValidExpenseAmount(double value) {
    if (value <= 0) return false;
    // Exclude common years (2020 - 2035) if exact integer
    if (value >= 2020 && value <= 2035 && value.truncateToDouble() == value) {
      return false;
    }
    // Exclude extreme unreasonable amounts
    if (value > 5000000) return false;
    return true;
  }

  static String _maskNonAmountTokens(String rawLine) {
    String masked = rawLine;

    // 0. Mask explicit phone / mobile / landline / contact lines:
    // e.g. "TEL: 080 23456789", "Phone: +91 98765 43210", "Mob: 9876543210", "Contact: 234567"
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Phone|Ph(?:\.|one)?|Tel(?:\.|ephone)?|Mob(?:\.|ile)?|Cell|Contact|WhatsApp|Call|Fax|Helpline|Customer\s*Care)[:\s#\.\-]+[0-9+\s\-()]{5,}\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 1. Mask UPI IDs / VPA handles: 9876543210@paytm, user@okhdfcbank, merchant.12@icici, etc.
    masked = masked.replaceAll(
      RegExp(r'\b[a-zA-Z0-9\._\-]+@[a-zA-Z0-9\._\-]+\b'),
      ' ',
    );

    // 2. Mask transaction IDs, UTRs, order numbers, invoice numbers, reference numbers
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:UPI\s*transaction\s*ID|Google\s*transaction\s*ID|Transaction\s*ID|Txn\s*ID|UTR(?:\s*No)?|UPI\s*Ref(?:\s*No)?|Ref(?:\s*No)?|Reference(?:\s*No)?|Order\s*ID|Bill\s*No|Invoice\s*No|Inv\s*No|Receipt\s*(?:#|No))[:\s\-]*[0-9A-Za-z\-_]+',
        caseSensitive: false,
      ),
      ' ',
    );

    // 2b. Mask other invoice, bill, receipt, order, token numbers e.g. "Invoice: 12345", "Bill # 8812", "Ticket # 9988"
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Invoice|Bill|Receipt|Order|Token|Challan|Memo|Doc|Check|Ticket|Counter|Cashier|POS)(?:\s*(?:No\.?|#|Id|ID|Num|Number|Code))?[:\s\-#]*[0-9A-Za-z\-_]+',
        caseSensitive: false,
      ),
      ' ',
    );

    // 3. Mask dates: DD/MM/YYYY, YYYY-MM-DD, 24 Oct 2026, Oct 24, 2026, Date: 25.10.2026
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Date|Dated|Dt)[:\s\-]*[0-9]{1,4}[\/\-\.][0-9]{1,2}[\/\-\.][0-9]{2,4}\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(0?[1-9]|[12][0-9]|3[01])[\/\-\.](0?[1-9]|1[012])[\/\-\.](20[2-3][0-9]|19[8-9][0-9]|[2-3][0-9])\b',
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(20[2-3][0-9])[\/\-\.](0?[1-9]|1[012])[\/\-\.](0?[1-9]|[12][0-9]|3[01])\b',
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(0?[1-9]|[12][0-9]|3[01])\s*(?:st|nd|rd|th)?[\s\-\,]+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)[\s\-\,]+(20[2-3][0-9])\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?\,?\s+(20[2-3][0-9])\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 4. Mask times: 10:45 AM, 08:30 pm, 14:22:05, 10.45 AM, Time: 15.30
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Time)[:\s\-]*[0-9]{1,2}[:\.][0-9]{2}(?:[:\.][0-9]{2})?\s*(?:AM|PM|am|pm)?\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(0?[1-9]|1[0-2])[\.:]([0-5][0-9])(?::([0-5][0-9]))?\s*(AM|PM|am|pm)\b|\b([01]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))\b',
      ),
      ' ',
    );

    // 5. Mask 10-digit Indian mobile numbers (with or without +91 and spaces/dashes)
    masked = masked.replaceAll(
      RegExp(r'(?:\+91[\-\s]*)?[6-9][0-9]{4}[\-\s]?[0-9]{5}\b'),
      ' ',
    );
    masked = masked.replaceAll(RegExp(r'(?:\+91[\-\s]*)?[6-9][0-9]{9}\b'), ' ');
    masked = masked.replaceAll(RegExp(r'\b0[6-9][0-9]{9}\b'), ' ');
    masked = masked.replaceAll(RegExp(r'\b0[1-9][0-9]{1,3}[\-\s]?[0-9]{6,8}\b'), ' ');
    masked = masked.replaceAll(RegExp(r'\b1800[\-\s]?[0-9]{3}[\-\s]?[0-9]{4}\b'), ' ');
    // International phone numbers: +1 (555) 234-5678, (555) 234-5678
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:\+?1[\-\s]?)?\(?[2-9][0-9]{2}\)?[\-\s]?[0-9]{3}[\-\s]?[0-9]{4}\b',
      ),
      ' ',
    );

    // 6. Mask 12-digit UTRs & transaction reference IDs (with or without spaces/dashes)
    masked = masked.replaceAll(
      RegExp(r'\b[0-9]{4}[\s\-][0-9]{4}[\s\-][0-9]{4}\b'),
      ' ',
    );
    masked = masked.replaceAll(RegExp(r'\b[0-9]{12}\b'), ' ');

    // 7. Mask alphanumeric transaction IDs: T261026..., CICAg...
    masked = masked.replaceAll(
      RegExp(r'\b(?:T[0-9]{15,22}|CICAg[A-Za-z0-9_\-]+)\b'),
      ' ',
    );

    // 8. Mask masked card/bank account patterns: XX4912, ****4921, XXXXXX1234
    masked = masked.replaceAll(RegExp(r'(?:[Xx*]{2,}\s*[0-9]{3,6})\b'), ' ');

    // 9. Mask "ending in 4912", "a/c no. 4912", "card ending 4912"
    masked = masked.replaceAll(
      RegExp(
        r'(?:ending\s+(?:in|with)|a\/c(?:\s*no\.?)?|card|account)\s*(?:no\.?)?[:\s\-]*([0-9]{3,6})\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 10. Mask bank names followed by account digits: "SBI - 4912", "HDFC Bank - 5678"
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:sbi|hdfc|icici|axis|kotak|pnb|bob|canara|union|idbi|yes\s*bank|indusind)[\s\w\-]*?[:\s\-]+[Xx*]*([0-9]{3,6})\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 11. Mask POS terminal fields: TID, MID, BATCH, INVOICE, AUTH CODE, STAN, ROC, RRN, EXP
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:TID|MID|BATCH(?:\s*NO)?|INV(?:OICE)?(?:\s*NO)?|AUTH(?:\s*CODE)?|APP(?:\s*CODE)?|STAN|ROC|RRN|EXP(?:\s*DATE)?|AID|AC|TC|TRACE|SEQ(?:\s*NO)?)[:\s\-]+[0-9A-Za-z]+',
        caseSensitive: false,
      ),
      ' ',
    );

    // 12. Mask bill item counts and rates: "Total Items: 5", "Qty: 2", "Rate: 150"
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Total\s+Items?|Total\s+Qty|No\.?\s*of\s+Items?|Item\s+Count|Qty|Quantity|Pcs|Pieces|Items?)[:\s]+[0-9]+(?:\.[0-9]+)?\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(r'\bRate[:\s]+[0-9]+(?:\.[0-9]+)?\b', caseSensitive: false),
      ' ',
    );

    // 12b. Mask table numbers, seat numbers, floor numbers, order numbers, etc.
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:Table\s*(?:No\.?|#|:)?|Seat\s*(?:No\.?|#|:)?|Floor\s*(?:No\.?|#|:)?|Cover\s*(?:No\.?|#|:)?|Pax\s*(?:No\.?|#|:)?|Counter\s*(?:No\.?|#|:)?|Meter\s*(?:No\.?|#|:)?|Folio\s*(?:No\.?|#|:)?)[:\s\-#]*[0-9A-Za-z]+',
        caseSensitive: false,
      ),
      ' ',
    );

    // 12c. Mask GST/GSTIN numbers: 27AABCU9603R1ZX
    masked = masked.replaceAll(
      RegExp(
        r'\b[0-9]{2}[A-Za-z]{5}[0-9]{4}[A-Za-z][0-9A-Za-z]Z[0-9A-Za-z]\b',
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:GSTIN|GST(?:\s*No)?|TIN|CIN|PAN(?:\s*No)?)[:\s\-]*[0-9A-Za-z\-_]+',
        caseSensitive: false,
      ),
      ' ',
    );

    // 12d. Mask FSSAI numbers (14-digit)
    masked = masked.replaceAll(RegExp(r'\b[0-9]{14}\b'), ' ');

    // 13. Mask network speeds, battery percentages, and connectivity indicators
    masked = masked.replaceAll(
      RegExp(
        r'\b[0-9]+(?:\.[0-9]+)?\s*(?:kb|mb|gb|k|m)\/s\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(RegExp(r'\b[0-9]+\s*%\b'), ' ');
    masked = masked.replaceAll(
      RegExp(r'\b(?:5g|4g|3g|lte|volte|wifi)\b', caseSensitive: false),
      ' ',
    );

    // 14. Mask percentages: 5%, 2.5%, 18%
    masked = masked.replaceAll(RegExp(r'\b[0-9]+(?:\.[0-9]+)?%'), ' ');

    // 15. Mask postal pincodes and zip codes: "PIN 560001", "ZIP 94103"
    masked = masked.replaceAll(
      RegExp(
        r'\b(?:PIN(?:\s*CODE)?|POSTAL|ZIP(?:\s*CODE)?|PINCODE)[:\s\-]*\b[1-9][0-9]{5}\b',
        caseSensitive: false,
      ),
      ' ',
    );
    masked = masked.replaceAll(
      RegExp(r'\bZIP[:\s\-]*[0-9]{5}(?:-[0-9]{4})?\b', caseSensitive: false),
      ' ',
    );

    // 16. Mask very small standalone numbers (1–9) when they are isolated non-currency labels
    masked = masked.replaceAll(
      RegExp(
        r'(?<!Rs)(?<!Re)(?<!INR)(?<!USD)(?<!US\$)(?<!EUR)(?<!GBP)(?<![₹\u20B9\u20A8\$€£\d,\.\?\*•Ff=~])\s\b([1-9])\b(?!\s*[₹\u20B9\u20A8\$€£]|\.[0-9]|,[0-9])',
        caseSensitive: false,
      ),
      ' ',
    );

    return masked;
  }

  // ---------------------------------------------------------------------------
  // Date & Time Extraction
  // ---------------------------------------------------------------------------
  static _DateResult _extractDateTime(String text, List<String> lines) {
    DateTime? extractedDate;
    bool isConfident = false;
    String? extractedTime;

    // Time regex: e.g. 10:45 AM, 08:30 pm, 14:22:05, 9:15am
    final timeRegex = RegExp(
      r'\b(0?[1-9]|1[0-2]):([0-5][0-9])(?::([0-5][0-9]))?\s*(AM|PM|am|pm)\b|\b([01]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))\b',
    );
    final timeMatch = timeRegex.firstMatch(text);
    if (timeMatch != null) {
      extractedTime = timeMatch.group(0)?.trim();
    }

    // Date Pattern 1: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    final numericDateRegex = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])[\/\-\.](0?[1-9]|1[012])[\/\-\.](20[2-3][0-9]|19[8-9][0-9]|[2-3][0-9])\b',
    );

    // Date Pattern 2: YYYY-MM-DD
    final isoDateRegex = RegExp(
      r'\b(20[2-3][0-9])[\/\-\.](0?[1-9]|1[012])[\/\-\.](0?[1-9]|[12][0-9]|3[01])\b',
    );

    // Date Pattern 3: Textual Month (e.g. 24 Oct 2026, 24 October 2026, Oct 24, 2026, 24-Oct-2026)
    final textualDateRegex = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s*(?:st|nd|rd|th)?[\s\-\,]+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)[\s\-\,]+(20[2-3][0-9])\b',
      caseSensitive: false,
    );

    final textualDateReverseRegex = RegExp(
      r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?\,?\s+(20[2-3][0-9])\b',
      caseSensitive: false,
    );

    // Priority 1: Check textual date (highest reliability in UPI screenshots)
    final textMatch = textualDateRegex.firstMatch(text);
    if (textMatch != null) {
      final day = int.tryParse(textMatch.group(1)!);
      final month = _monthStringToNum(textMatch.group(2)!);
      final year = int.tryParse(textMatch.group(3)!);
      if (day != null &&
          month != null &&
          year != null &&
          _isValidDate(year, month, day)) {
        extractedDate = DateTime(year, month, day);
        isConfident = true;
      }
    }

    if (extractedDate == null) {
      final revMatch = textualDateReverseRegex.firstMatch(text);
      if (revMatch != null) {
        final month = _monthStringToNum(revMatch.group(1)!);
        final day = int.tryParse(revMatch.group(2)!);
        final year = int.tryParse(revMatch.group(3)!);
        if (day != null &&
            month != null &&
            year != null &&
            _isValidDate(year, month, day)) {
          extractedDate = DateTime(year, month, day);
          isConfident = true;
        }
      }
    }

    // Priority 2: ISO Date (YYYY-MM-DD)
    if (extractedDate == null) {
      final isoMatch = isoDateRegex.firstMatch(text);
      if (isoMatch != null) {
        final year = int.tryParse(isoMatch.group(1)!);
        final month = int.tryParse(isoMatch.group(2)!);
        final day = int.tryParse(isoMatch.group(3)!);
        if (year != null &&
            month != null &&
            day != null &&
            _isValidDate(year, month, day)) {
          extractedDate = DateTime(year, month, day);
          isConfident = true;
        }
      }
    }

    // Priority 3: Numeric DD/MM/YYYY or DD-MM-YYYY
    if (extractedDate == null) {
      final numMatch = numericDateRegex.firstMatch(text);
      if (numMatch != null) {
        final day = int.tryParse(numMatch.group(1)!);
        final month = int.tryParse(numMatch.group(2)!);
        var year = int.tryParse(numMatch.group(3)!);
        if (year != null && year < 100) year += 2000;
        if (day != null &&
            month != null &&
            year != null &&
            _isValidDate(year, month, day)) {
          extractedDate = DateTime(year, month, day);
          isConfident = true;
        }
      }
    }

    // If time was also found, combine hours & minutes
    if (extractedDate != null && extractedTime != null) {
      final parsedTime = _parseTimeOfDay(extractedTime);
      if (parsedTime != null) {
        extractedDate = DateTime(
          extractedDate.year,
          extractedDate.month,
          extractedDate.day,
          parsedTime.hour,
          parsedTime.minute,
        );
      }
    }

    return _DateResult(
      date: extractedDate,
      isConfident: isConfident,
      timeString: extractedTime,
    );
  }

  static bool _isValidDate(int year, int month, int day) {
    if (year < 2018 || year > DateTime.now().year + 1) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    return true;
  }

  static int? _monthStringToNum(String monthStr) {
    final m = monthStr.toLowerCase();
    if (m.startsWith('jan')) return 1;
    if (m.startsWith('feb')) return 2;
    if (m.startsWith('mar')) return 3;
    if (m.startsWith('apr')) return 4;
    if (m.startsWith('may')) return 5;
    if (m.startsWith('jun')) return 6;
    if (m.startsWith('jul')) return 7;
    if (m.startsWith('aug')) return 8;
    if (m.startsWith('sep')) return 9;
    if (m.startsWith('oct')) return 10;
    if (m.startsWith('nov')) return 11;
    if (m.startsWith('dec')) return 12;
    return null;
  }

  static ({int hour, int minute})? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');

      final parts = clean.replaceAll(RegExp(r'[A-Za-z]'), '').trim().split(':');
      if (parts.length >= 2) {
        var hour = int.parse(parts[0].trim());
        final min = int.parse(parts[1].trim());
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return (hour: hour, minute: min);
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Merchant / Payee Detection
  // ---------------------------------------------------------------------------
  static String? _extractMerchant(
    List<String> lines,
    String text,
    String sourceType,
  ) {
    // Pattern 1A: Multi-line UPI: Line i has "Paid to" / "Payment to", subsequent lines contain merchant name
    for (int i = 0; i < lines.length - 1; i++) {
      final lineLower = lines[i].trim().toLowerCase();
      if (lineLower == 'paid to' ||
          lineLower == 'payment to' ||
          lineLower == 'transfer to' ||
          lineLower == 'sent to' ||
          lineLower == 'to' ||
          lineLower == 'to:') {
        for (int k = 1; k <= 3 && i + k < lines.length; k++) {
          final candidateLine = lines[i + k].trim();
          if (candidateLine.length <= 2 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(candidateLine)) {
            continue; // Skip 1-2 letter avatar initials (e.g. "ML")
          }
          if (!RegExp(r'^[₹\u20B9\?*•Ff\d\+]').hasMatch(candidateLine)) {
            final candidate = _cleanMerchantName(candidateLine);
            if (_isValidMerchant(candidate)) {
              return candidate;
            }
          }
        }
      }
    }

    // Pattern 1B: UPI "Paid to [Merchant]", "To [Merchant]", "Payment to [Merchant]"
    final paidToRegex = RegExp(
      r'''(?:Paid to|Payment to|Transfer to|Sent to|To:?)\s+([A-Za-z0-9\ \t\.\&\@\(\)\-'\’]{3,40})''',
      caseSensitive: false,
    );

    final match = paidToRegex.firstMatch(text);
    if (match != null) {
      final candidate = _cleanMerchantName(match.group(1));
      if (_isValidMerchant(candidate)) {
        return candidate;
      }
    }

    // Famous brands dictionary
    final brandNames = [
      'Starbucks',
      'Blue Tokai',
      'Third Wave Coffee',
      'Cafe Coffee Day',
      'McDonald\'s',
      'KFC',
      'Burger King',
      'Subway',
      'Domino\'s',
      'Pizza Hut',
      'Haldiram',
      'Barbeque Nation',
      'Swiggy',
      'Zomato',
      'Blinkit',
      'Zepto',
      'Instamart',
      'BigBasket',
      'DMart',
      'Spencer\'s',
      'Nature\'s Basket',
      'Uber',
      'Ola',
      'Rapido',
      'Indian Oil',
      'Bharat Petroleum',
      'HPCL',
      'Shell',
      'Amazon',
      'Flipkart',
      'Myntra',
      'Zara',
      'H&M',
      'Uniqlo',
      'Decathlon',
      'Croma',
      'Reliance Digital',
      'Apple Store',
      'Airtel',
      'Jio',
      'Vi',
      'BookMyShow',
      'PVR Cinemas',
      'INOX',
      'Cinepolis',
      'Apollo Pharmacy',
      'MedPlus',
      '1mg',
      'Pharmeasy',
      'IndiGo',
      'Air India',
      'Vistara',
      'MakeMyTrip',
    ];

    for (final brand in brandNames) {
      if (brand.length <= 4) {
        if (RegExp(
          r'\b' + RegExp.escape(brand) + r'\b',
          caseSensitive: false,
        ).hasMatch(text)) {
          return brand;
        }
      } else {
        if (text.toLowerCase().contains(brand.toLowerCase())) {
          return brand;
        }
      }
    }

    // Pattern 2: UPI ID extraction (e.g. merchant@icici -> merchant)
    final upiIdRegex = RegExp(
      r'\b([a-zA-Z0-9\.\_]{3,30})@(okhdfcbank|oksbi|okaxis|okicici|paytm|ybl|ibl|upi|axl)\b',
    );
    final upiMatch = upiIdRegex.firstMatch(text);
    if (upiMatch != null) {
      final handle = upiMatch.group(1);
      if (handle != null &&
          handle.length > 3 &&
          !handle.contains(RegExp(r'^\d+$'))) {
        final formatted = _formatHandleToName(handle);
        if (_isValidMerchant(formatted)) {
          return formatted;
        }
      }
    }

    // Pattern 3: Paper receipts - usually lines 0 to 3 contain merchant name
    final noisyLines = [
      'tax invoice',
      'cash memo',
      'invoice',
      'receipt',
      'retail invoice',
      'welcome',
      'thank you',
      'original',
      'duplicate',
      'bill',
      'pos receipt',
      'order',
      'table',
      'guest',
      'gstin',
      'fssai',
      'tel',
      'phone',
      'date',
      'time',
      'payment successful',
      'transaction successful',
      'paid successfully',
      'google pay',
      'phonepe',
      'paytm',
      'bhim',
      'upi',
      'completed',
    ];

    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i].trim();
      final lineLower = line.toLowerCase();

      final isNoisy = noisyLines.any((n) => lineLower.contains(n));
      final hasNumbers = RegExp(r'^\d+').hasMatch(line);

      if (!isNoisy && !hasNumbers && line.length >= 3 && line.length <= 40) {
        return _cleanMerchantName(line);
      }
    }

    return null;
  }

  static String? _cleanMerchantName(String? raw) {
    if (raw == null) return null;
    return raw
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(
          RegExp(r'^(to|paid to|sent to)\s+', caseSensitive: false),
          '',
        )
        .trim();
  }

  static bool _isValidMerchant(String? name) {
    if (name == null || name.length < 3) return false;
    final lower = name.toLowerCase();
    final invalidExact = [
      'payment successful',
      'transaction successful',
      'payment completed',
      'paid successfully',
      'transaction details',
      'upi transaction id',
      'google pay',
      'phonepe',
      'paytm',
      'completed',
      'successful',
      'debited from',
      'view details',
      'check balance',
      'share',
    ];
    if (invalidExact.contains(lower)) return false;
    return true;
  }

  static String _formatHandleToName(String handle) {
    // Convert "bluetokai.coffee" or "starbucks_retail" to "Bluetokai Coffee"
    final words = handle.split(RegExp(r'[\.\_\-]'));
    return words
        .where((w) => w.isNotEmpty)
        .map(
          (w) =>
              w[0].toUpperCase() +
              (w.length > 1 ? w.substring(1).toLowerCase() : ''),
        )
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Reference / UTR Number
  // ---------------------------------------------------------------------------
  static String? _extractReferenceId(String text, List<String> lines) {
    // 1. UPI Ref / UTR (12 digits)
    final utrRegex = RegExp(
      r'(?:UTR|UPI Ref(?:erence)?(?:\s*No)?|Txn\s*ID|Transaction\s*ID)[:\s]+([0-9A-Za-z]{9,22})',
      caseSensitive: false,
    );
    final utrMatch = utrRegex.firstMatch(text);
    if (utrMatch != null) {
      return utrMatch.group(1)?.trim();
    }

    // 2. 12-digit UTR standalone
    final standaloneUtr = RegExp(r'\b(UPI\s*Ref(?:\s*No)?:?\s*)?([0-9]{12})\b');
    final match = standaloneUtr.firstMatch(text);
    if (match != null) {
      return match.group(2)?.trim();
    }

    // 3. Invoice No / Bill No
    final billRegex = RegExp(
      r'(?:Bill\s*No|Invoice\s*No|Receipt\s*#)[:\s]+([A-Za-z0-9\-\/]+)',
      caseSensitive: false,
    );
    final billMatch = billRegex.firstMatch(text);
    if (billMatch != null) {
      return billMatch.group(1)?.trim();
    }

    return null;
  }

  static bool _isIncomingTransaction(String text) {
    final explicitIncomingLabel = RegExp(
      r'\b(?:payment received|money received|amount received|received from|you received|amount credited|credited to|credited from|refund(?:ed)?\s+(?:credited|received|amount|successful|processed|initiated|to|₹|Rs\.?|INR))\b',
      caseSensitive: false,
    );
    if (explicitIncomingLabel.hasMatch(text)) return true;

    final standaloneIncomingStatus = RegExp(
      r'^\s*(?:received|credited)\s*$',
      caseSensitive: false,
      multiLine: true,
    );
    final incomingStatusWithAmount = RegExp(
      r'^\s*(?:received|credited)\s+(?:(?:₹|Rs\.?|INR)\s*)?[0-9]|^\s*(?:(?:₹|Rs\.?|INR)\s*)?[0-9][0-9,]*(?:\.[0-9]{1,2})?\s+(?:received|credited)\b',
      caseSensitive: false,
      multiLine: true,
    );
    final hasAmount = RegExp(
      r'(?:₹|Rs\.?|INR)\s*[0-9]',
      caseSensitive: false,
    ).hasMatch(text);
    return hasAmount &&
        (standaloneIncomingStatus.hasMatch(text) ||
            incomingStatusWithAmount.hasMatch(text));
  }

  // ---------------------------------------------------------------------------
  // Payment Method
  // ---------------------------------------------------------------------------
  static PaymentMethod _detectPaymentMethod(String text, String sourceType) {
    final lower = text.toLowerCase();

    // Check UPI
    if (sourceType.contains('UPI') ||
        sourceType.contains('Google Pay') ||
        sourceType.contains('PhonePe') ||
        sourceType.contains('Paytm') ||
        lower.contains('upi') ||
        lower.contains('vpa') ||
        lower.contains('utr') ||
        lower.contains('@ok') ||
        lower.contains('@ybl')) {
      return PaymentMethod.upi;
    }

    // Check Cards
    if (lower.contains('credit card') ||
        lower.contains('card ending') ||
        lower.contains('visa') ||
        lower.contains('mastercard') ||
        lower.contains('amex')) {
      return PaymentMethod.creditCard;
    }
    if (lower.contains('debit card') ||
        lower.contains('rupay') ||
        lower.contains('pos sale') ||
        lower.contains('swipe')) {
      return PaymentMethod.debitCard;
    }

    // Check Cash
    if (lower.contains('cash tendered') ||
        lower.contains('cash payment') ||
        lower.contains('paid by cash') ||
        lower.contains('cash receipt')) {
      return PaymentMethod.cash;
    }

    // Check Bank Transfer
    if (lower.contains('neft') ||
        lower.contains('imps') ||
        lower.contains('rtgs') ||
        lower.contains('bank transfer') ||
        lower.contains('net banking')) {
      return PaymentMethod.bankTransfer;
    }

    return PaymentMethod
        .upi; // Default in Indian digital transactions, editable in preview
  }

  // ---------------------------------------------------------------------------
  // Category Suggestion
  // ---------------------------------------------------------------------------
  static String _inferCategory(String? merchant, String fullText) {
    final text = '${merchant ?? ""} $fullText'.toLowerCase();

    // Food & Dining
    if (_matchesKeywords(text, [
      'food',
      'restaurant',
      'cafe',
      'coffee',
      'dining',
      'kitchen',
      'bistro',
      'swiggy',
      'zomato',
      'starbucks',
      'blue tokai',
      'third wave',
      'mcdonald',
      'kfc',
      'burger',
      'pizza',
      'domino',
      'biryani',
      'chai',
      'tea',
      'subway',
      'haldiram',
      'barbeque',
      'bakery',
      'sweets',
      'snack',
      'canteen',
      'dhaba',
      'meal',
      'lunch',
      'dinner',
      'breakfast',
      'bar',
      'brewery',
      'pub',
    ])) {
      return 'food';
    }

    // Groceries
    if (_matchesKeywords(text, [
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'dmart',
      'supermarket',
      'grocery',
      'groceries',
      'provisions',
      'kirana',
      'vegetables',
      'fruits',
      'milk',
      'dairy',
      'country delight',
      'nature\'s basket',
      'hypermarket',
      'ration',
      'spencer',
    ])) {
      return 'groceries';
    }

    // Transportation
    if (_matchesKeywords(text, [
      'uber',
      'ola',
      'rapido',
      'cab',
      'taxi',
      'auto',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'shell',
      'hpcl',
      'bpcl',
      'iocl',
      'indian oil',
      'fastag',
      'toll',
      'parking',
      'cng',
      'commute',
    ])) {
      return 'transport';
    }

    // Shopping
    if (_matchesKeywords(text, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'zara',
      'h&m',
      'uniqlo',
      'retail',
      'mall',
      'croma',
      'reliance digital',
      'apple',
      'shoes',
      'footwear',
      'clothes',
      'apparel',
      'fashion',
      'decathlon',
      'sports',
      'westside',
      'shoppers stop',
      'store',
      'electronics',
    ])) {
      return 'shopping';
    }

    // Bills & Utilities
    if (_matchesKeywords(text, [
      'electricity',
      'bescom',
      'cesc',
      'tata power',
      'airtel',
      'jio',
      'vodafone',
      'vi bill',
      'vi recharge',
      'water bill',
      'gas',
      'cylinder',
      'indane',
      'bharat gas',
      'wifi',
      'broadband',
      'act fibernet',
      'recharge',
      'utility',
      'postpaid',
      'prepaid',
      'maintenance',
    ])) {
      return 'bills';
    }

    // Health & Wellness
    if (_matchesKeywords(text, [
      'pharmacy',
      'apollo',
      'medplus',
      '1mg',
      'pharmeasy',
      'netmeds',
      'hospital',
      'clinic',
      'doctor',
      'dental',
      'diagnostics',
      'lab',
      'medicine',
      'pharma',
      'healthcare',
      'dentist',
      'optical',
      'lenskart',
    ])) {
      return 'health';
    }

    // Entertainment
    if (_matchesKeywords(text, [
      'bookmyshow',
      'pvr',
      'inox',
      'cinepolis',
      'cinema',
      'movie',
      'netflix',
      'spotify',
      'prime video',
      'disney',
      'hotstar',
      'youtube',
      'gaming',
      'steam',
      'concert',
      'show',
      'amusement',
      'bowling',
    ])) {
      return 'entertainment';
    }

    // Travel & Trips
    if (_matchesKeywords(text, [
      'indigo',
      'air india',
      'vistara',
      'akasa',
      'flight',
      'airline',
      'irctc',
      'railway',
      'train',
      'makemytrip',
      'goibibo',
      'cleartrip',
      'hotel',
      'resort',
      'hostel',
      'airbnb',
      'agoda',
      'booking.com',
      'travel',
      'trip',
      'stay',
    ])) {
      return 'travel';
    }

    // Education
    if (_matchesKeywords(text, [
      'udemy',
      'coursera',
      'bookstore',
      'crossword',
      'books',
      'stationery',
      'university',
      'college',
      'school',
      'tuition',
      'coaching',
      'fees',
      'academy',
      'course',
    ])) {
      return 'education';
    }

    return 'other';
  }

  static bool _matchesKeywords(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (!kw.contains(' ') || kw.length <= 6) {
        if (RegExp(
          r'\b' + RegExp.escape(kw) + r'\b',
          caseSensitive: false,
        ).hasMatch(text)) {
          return true;
        }
      } else {
        if (text.contains(kw)) return true;
      }
    }
    return false;
  }
}

class _AmountResult {
  final double? primaryAmount;
  final double confidence;
  final List<double> candidates;
  final AmountExtractionStatus status;

  const _AmountResult({
    required this.primaryAmount,
    required this.confidence,
    required this.candidates,
    required this.status,
  });
}

class _DateResult {
  final DateTime? date;
  final bool isConfident;
  final String? timeString;

  const _DateResult({
    required this.date,
    required this.isConfident,
    this.timeString,
  });
}
