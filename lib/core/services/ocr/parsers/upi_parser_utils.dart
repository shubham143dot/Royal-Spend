import 'package:royal_spend/core/constants/default_categories.dart';

/// Common parsing helpers, regexes, and cleanups for UPI receipts (PhonePe, Navi, Google Pay).
class UpiParserUtils {
  /// Normalizes and cleans raw OCR text by removing invisible Unicode characters,
  /// repairing kerning spaces, merging split currency lines, and standardizing line breaks.
  static String cleanText(String rawText) {
    var text = rawText
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ') // narrow no-break space (frequent in Android/ML Kit)
        .replaceAll('\u2007', ' ') // figure space
        .replaceAll('\u2002', ' ')
        .replaceAll('\u2003', ' ')
        .replaceAll('\u2004', ' ')
        .replaceAll('\u2005', ' ')
        .replaceAll('\u2006', ' ')
        .replaceAll('\u2008', ' ')
        .replaceAll('\u2009', ' ') // thin space
        .replaceAll('\u200A', ' ') // hair space
        .replaceAll('\u200E', '')  // LTR mark
        .replaceAll('\u200F', '')  // RTL mark
        .replaceAll('\u200B', '')  // zero-width space
        .replaceAll('\uFEFF', '')  // BOM
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Repair spaces inside numbers caused by OCR font kerning (e.g. "1, 250" -> "1,250", "450 . 00" -> "450.00")
    text = text
        .replaceAllMapped(
          RegExp(r'([0-9]),\s+([0-9])'),
          (m) => '${m[1]},${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([0-9])\s+\.\s*([0-9])'),
          (m) => '${m[1]}.${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([0-9])\.\s+([0-9])'),
          (m) => '${m[1]}.${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'([0-9])\s+,\s*([0-9])'),
          (m) => '${m[1]},${m[2]}',
        );

    // Pre-merge split currency lines (e.g. line i is "₹" or ends with "₹", line i+1 is "500")
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<String> merged = [];
    for (int i = 0; i < rawLines.length; i++) {
      final current = rawLines[i];

      // If current line is ONLY currency symbol or ends with currency symbol
      if (RegExp(
            r'^(?:[₹\u20B9\u20A8\$€£\?¿*•Ff=~+rR]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?|\(₹\)|\(Rs\.?\))\s*$',
            caseSensitive: false,
          ).hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (RegExp(r'^[0-9]').hasMatch(next)) {
          merged.add('$current $next');
          i++;
          continue;
        }
      }

      // If current line ends with a number and next line is ONLY currency symbol or trailing slash
      if (RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(current) &&
          i + 1 < rawLines.length) {
        final next = rawLines[i + 1].trim();
        if (RegExp(
              r'^(?:[₹\u20B9\u20A8\$€£\?¿*•Ff=~+]|INR|USD|US\$|EUR|GBP|Rs\.?|RS\.?|Re\.?|\/\-|\/[ \t]*\-|\/=)\s*$',
              caseSensitive: false,
            ).hasMatch(next)) {
          if (next.startsWith('/') || next.startsWith('=')) {
            merged.add('$current/-');
          } else {
            merged.add('$next $current');
          }
          i++;
          continue;
        }
      }

      merged.add(current);
    }

    return merged.join('\n').trim();
  }

  /// Parses a clean monetary string into double (e.g. "1", "30", "1,250", "450.50").
  static double? parseCleanNumber(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    const validAmount =
        r'^(?:(?:[0-9]{1,3}(?:,[0-9]{3})+)|(?:[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3})|[0-9]{1,8})(?:\.[0-9]{1,2})?$';
    if (!RegExp(validAmount).hasMatch(cleaned)) return null;

    final normalized = cleaned.replaceAll(',', '');
    final parts = normalized.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    final fraction = parts.length == 2
        ? int.tryParse(parts[1].padRight(2, '0'))
        : 0;
    if (fraction == null) return null;
    return whole + (fraction / 100.0);
  }

  /// Checks if an extracted amount is a realistic financial transaction amount.
  static bool isValidAmount(double? amount) {
    if (amount == null || amount <= 0) return false;
    // Disqualify years 2020-2035 when integer
    if (amount >= 2020 && amount <= 2035 && amount.truncateToDouble() == amount) {
      return false;
    }
    // Disqualify absurd numbers
    if (amount > 5000000) return false;
    return true;
  }

  /// Normalizes all Rupee representations into clean `₹ <number>`.
  /// Handles ₹, Rs., Rs, RS, INR, and common OCR misreads like ?, *, •, F, f.
  static String healRupeeGlyphs(String text) {
    var healed = text;

    // A) Explicit Rupee symbol ₹ or ₨ anywhere directly preceding digits, with optional punctuation
    // e.g. "₹500", "₹ 500", "₹:500", "₹.500", "Total:₹500", "Paid₹500", "₹ 1,250.00"
    healed = healed.replaceAllMapped(
      RegExp(
        r'''[₹\u20B9\u20A8][ \t]*[:\.\-]?[ \t]*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?)(?![0-9,.])''',
      ),
      (m) => '₹ ${m[1]}',
    );

    // B) Standard textual Rs/INR/Re variations
    // e.g. "Rs. 500", "Rs 500", "RS. 1,250", "INR 450", "Re 1", "Rs.1500"
    healed = healed.replaceAllMapped(
      RegExp(
        r'''\b(?:Rs\.?|RS\.?|rs\.?|Re\.?|RE\.?|INR|Inr|inr|[रुरू])[ \t]*[:\.\-]?[ \t]*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?)(?![0-9,.])''',
        caseSensitive: false,
      ),
      (m) => '₹ ${m[1]}',
    );

    // C) Trailing Rupee or slash variations: e.g. "500/-", "1250 / -", "500/=", "450 Rs", "450 INR", "500₹"
    healed = healed.replaceAllMapped(
      RegExp(
        r'''(?<=[^0-9,.]|^)((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,8})(?:\.[0-9]{1,2})?)[ \t]*(?:\/\-|\/[ \t]*\-|\/=|Rs\.?|RS\.?|rs\.?|Re\.?|INR|Inr|[₹\u20B9\u20A8])''',
        caseSensitive: false,
      ),
      (m) => '₹ ${m[1]}',
    );

    // D) Misread OCR glyphs directly before a number: ?, ¿, *, •, F, f, ~, =
    // Note: '+' is intentionally excluded because it represents country codes (+91, +1) in phone numbers.
    healed = healed.replaceAllMapped(
      RegExp(
        r'''(?<=^|[ \t:])([?¿*•Ff=~]|(?<=^|[ \t:])r)[ \t]*[:\.\-]?[ \t]*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,8})(?:\.[0-9]{1,2})?)(?![0-9,.])''',
        caseSensitive: false,
      ),
      (m) => '₹ ${m[2]}',
    );

    return healed;
  }

  /// Extracts all valid Rupee amounts from [text] in order of appearance.
  /// Guarantees that any number accompanied by '₹' or 'Rs' or '/-' is discovered.
  static List<double> extractAllRupeeAmounts(String text) {
    final cleaned = cleanText(text);
    final healed = healRupeeGlyphs(cleaned);

    final rupeePattern = RegExp(
      r'[₹\u20B9\u20A8]\s*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3}|[0-9]{1,7})(?:\.[0-9]{1,2})?)',
    );

    final List<double> results = [];
    for (final match in rupeePattern.allMatches(healed)) {
      final parsed = parseCleanNumber(match.group(1));
      if (parsed != null && isValidAmount(parsed)) {
        if (!results.contains(parsed)) {
          results.add(parsed);
        }
      }
    }
    return results;
  }

  /// Combines hours and minutes from an extracted time string into a DateTime.
  static DateTime combineDateAndTime(DateTime date, String timeStr) {
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
        return DateTime(date.year, date.month, date.day, hour, min);
      }
    } catch (_) {}
    return date;
  }

  /// Converts 3-letter month string to 1-12 integer.
  static int? monthToNum(String monthStr) {
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

  /// Infers category ID from merchant and contextual receipt text.
  static String inferCategory(String? merchant, String text) {
    final combined = '${merchant ?? ""} $text'.toLowerCase();

    // Food & Dining
    if (_hasAny(combined, [
      'food', 'restaurant', 'cafe', 'coffee', 'dining', 'swiggy', 'zomato',
      'starbucks', 'blue tokai', 'third wave', 'mcdonald', 'kfc', 'burger',
      'pizza', 'domino', 'biryani', 'chai', 'tea', 'subway', 'bakery',
      'sweets', 'snack', 'dhaba', 'canteen', 'hotel', 'bar', 'kitchen',
    ])) {
      return 'food';
    }

    // Transportation & Fuel
    if (_hasAny(combined, [
      'uber', 'ola', 'rapido', 'metro', 'fuel', 'petrol', 'diesel', 'cng',
      'indian oil', 'bharat petroleum', 'hpcl', 'shell', 'irctc', 'railway',
      'toll', 'fastag', 'auto', 'taxi', 'ride', 'flight', 'indigo', 'vistara',
    ])) {
      return 'transport';
    }

    // Groceries & Supplies
    if (_hasAny(combined, [
      'blinkit', 'zepto', 'instamart', 'bigbasket', 'dmart', 'spencer',
      'nature\'s basket', 'grocery', 'supermarket', 'kirana', 'provisions',
      'dairy', 'milk', 'vegetables', 'fruits',
    ])) {
      return 'groceries';
    }

    // Bills & Utilities & Subscriptions
    if (_hasAny(combined, [
      'electricity', 'bescom', 'tneb', 'water', 'gas', 'broadband', 'wifi',
      'airtel', 'jio', 'vi', 'vodafone', 'recharge', 'subscription',
      'mohalla tech', 'sharechat', 'netflix', 'spotify', 'prime', 'youtube',
      'hotstar', 'maintenance', 'bill payment', 'autopay',
    ])) {
      return 'bills';
    }

    // Shopping
    if (_hasAny(combined, [
      'amazon', 'flipkart', 'myntra', 'zara', 'h&m', 'uniqlo', 'decathlon',
      'croma', 'reliance digital', 'apple store', 'clothing', 'footwear',
      'apparel', 'fashion', 'retail', 'mall',
    ])) {
      return 'shopping';
    }

    // Entertainment
    if (_hasAny(combined, [
      'bookmyshow', 'pvr', 'inox', 'cinepolis', 'cinema', 'movie', 'theatre',
      'amusement', 'gaming', 'bowling', 'club', 'cultural association',
    ])) {
      return 'entertainment';
    }

    // Health
    if (_hasAny(combined, [
      'apollo', 'pharmacy', 'medplus', '1mg', 'pharmeasy', 'hospital',
      'clinic', 'doctor', 'diagnostic', 'pathology', 'lab', 'dental',
    ])) {
      return 'health';
    }

    // Travel
    if (_hasAny(combined, [
      'makemytrip', 'goibibo', 'airbnb', 'oyo', 'hotel', 'resort', 'homestay',
      'cleartrip', 'yatra', 'tour', 'booking.com',
    ])) {
      return 'travel';
    }

    // Default fallback
    return DefaultCategories.categories.first.id; // food
  }

  static bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
