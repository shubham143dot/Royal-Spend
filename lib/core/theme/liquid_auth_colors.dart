import 'package:flutter/material.dart';

/// Sophisticated Neutral Liquid Glass color palette for Royal Spend Authentication.
///
/// STRICT DESIGN CONSTRAINTS (per MASTER IMPLEMENTATION PROMPT):
/// - Absolutely ZERO BLUE (#0000FF, #115BFF, #1677FF, #36D9FF, #050B1A, etc.).
/// - Absolutely ZERO GOLDEN (#D4AF37, #FFD700, #F5A623, etc.).
/// - No yellow/gold gradients.
/// - No conventional neon gaming aesthetics.
///
/// Neutral Color System:
/// - Transparent white
/// - Soft silver
/// - Graphite
/// - Charcoal
/// - Neutral grey
/// - Subtle white highlights
abstract class LiquidAuthColors {
  // Pure dark obsidian & charcoal backdrops (pure neutral, 0% color cast)
  static const Color charcoalDark = Color(0xFF090A0D);
  static const Color charcoalSurface = Color(0xFF111317);
  static const Color graphite = Color(0xFF1E2127);
  static const Color graphiteLight = Color(0xFF2C3038);

  // Pure optical liquid glass surfaces (neutral translucent white over video)
  static const Color glassSurface = Color(0x14FFFFFF); // 8% optical water glass
  static const Color glassSurfaceElevated = Color(0x1FFFFFFF); // 12% glass
  static const Color glassSurfaceRecessed = Color(0x0DFFFFFF); // 5% recessed glass
  static const Color glassInputFill = Color(0x10FFFFFF); // 6% input fill
  static const Color glassInputFillFocused = Color(0x1CFFFFFF); // 11% focused fill

  // Molded specular highlights (pure white, soft silver, and liquid platinum)
  static const Color specularWhite = Color(0xFFFFFFFF);
  static const Color specularRim = Color(0x73FFFFFF); // 45% white
  static const Color specularHairline = Color(0x38FFFFFF); // 22% white
  static const Color softSilver = Color(0xFFE2E8F0); // Platinum silver highlight
  static const Color liquidPlatinum = Color(0xFFF1F5F9); // Crisp platinum
  static const Color liquidMercury = Color(0xFFD4D8E2); // Liquid mercury finish
  static const Color auroraLilac = Color(0xFFE2E8F0); // Soft silver sheen
  static const Color mistLavender = Color(0xFFF1F5F9); // Light platinum sheen
  static const Color neutralGrey = Color(0xFF94A3B8); // Slate neutral grey

  // Primary action resin: Pure Liquid Mercury / Monochromatic Glass
  static const Color primaryActionFill = Color(0xE6FFFFFF); // 90% white liquid glass button
  static const Color primaryActionText = Color(0xFF090A0D); // Deep charcoal text on light glass
  static const Color primaryActionGradientStart = Color(0xFFFFFFFF);
  static const Color primaryActionGradientEnd = Color(0xFFD4D8E2); // Liquid mercury finish

  // Secondary & Text tokens (Contrast-protected)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1); // Soft silver
  static const Color textMuted = Color(0xFF94A3B8); // Neutral grey
  static const Color textDisabled = Color(0x52FFFFFF);

  // Focus & Accent: Ethereal Silver-White Sheen (No neon, no color tint)
  static const Color focusSheen = Color(0xFFF8FAFC);
  static const Color focusGlow = Color(0x40FFFFFF); // 25% white glow

  // Neutral Feedback states (Clean, non-neon)
  static const Color errorRed = Color(0xFFF43F5E); // Neutral rose error
  static const Color successGreen = Color(0xFF10B981); // Neutral emerald success
  static const Color errorBg = Color(0x26F43F5E);
  static const Color successBg = Color(0x2610B981);

  // Scrim tokens for video background overlay (Pure neutral black/charcoal)
  static const Color scrimTop = Color(0x52000000); // 32% black
  static const Color scrimMid = Color(0x1F000000); // 12% black
  static const Color scrimBottom = Color(0x6B000000); // 42% black
}
