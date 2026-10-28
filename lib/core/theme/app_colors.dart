import 'package:flutter/material.dart';

class AppColors {
  // Brand Royal
  static const Color royalIndigo = Color(0xFF6366F1);
  static const Color royalIndigoLight = Color(0xFF818CF8);
  static const Color electricCyan = Color(0xFF38BDF8);
  static const Color vividMint = Color(0xFF10B981);
  static const Color roseExpense = Color(0xFFF43F5E);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color violetAccent = Color(0xFF8B5CF6);

  // Apple iOS Dark Mode System Tokens (Direct reference to iOS Settings)
  static const Color darkBackground = Color(0xFF000000); // True OLED Pure Black
  static const Color darkBackgroundSecondary = Color(0xFF1C1C1E); // Apple Secondary System Grouped Background
  static const Color darkCard = Color(0xFF1C1C1E); // Grouped Card Surface
  static const Color darkSurface = Color(0xFF2C2C2E); // Apple Tertiary System Fill (Inputs / Inset Rows)
  static const Color darkElevated = Color(0xFF3A3A3C); // Apple Quaternary System Fill
  static const Color darkSeparator = Color(0xFF38383A); // Apple Hairline Separator (0x33545458)
  static const Color darkGlassSurface = Color(0xFF1C1C1E);
  static const Color darkGlassHighlight = Color(0x1FFFFFFF); // Subtle Hairline Specular Rim
  static const Color darkGlassCard = Color(0xFF1C1C1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color darkTextSecondary = Color(0xFF8E8E93); // Apple System Gray (Secondary Label)
  static const Color darkTextMuted = Color(0xFF636366); // Apple System Gray 2 (Tertiary Label)

  // Apple System Vibrant Accents
  static const Color appleBlue = Color(0xFF0A84FF);
  static const Color appleGreen = Color(0xFF30D158);
  static const Color appleRed = Color(0xFFFF453A);
  static const Color appleOrange = Color(0xFFFF9F0A);
  static const Color appleYellow = Color(0xFFFFD60A);
  static const Color applePurple = Color(0xFFBF5AF2);
  static const Color appleIndigo = Color(0xFF5E5CE6);
  static const Color appleTeal = Color(0xFF64D2FF);
  static const Color appleGray = Color(0xFF8E8E93);

  // Light Frosted Palette
  static const Color lightBackground = Color(0xFFF2F2F7); // Apple System Grouped Background Light
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightGlassSurface = Color(0xCCFFFFFF);
  static const Color lightGlassHighlight = Color(0x80FFFFFF);
  static const Color lightGlassCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF6C6C70);
  static const Color lightTextMuted = Color(0xFF8E8E93);

  // Gradients
  static const LinearGradient royalGradient = LinearGradient(
    colors: [royalIndigo, electricCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFB7185), roseExpense],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF34D399), vividMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [
      Color(0x33334155),
      Color(0x1A1E293B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [
      Color(0xE6FFFFFF),
      Color(0xB3F8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
