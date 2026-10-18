import 'package:flutter/material.dart';

/// Color semantics from prd.md > Look and Feel:
/// proximity red = very close, orange = farther, white = unknown.
class SoundscapeColors {
  static const Color background = Color(0xFF0F1720); // near-black, light is the hero
  static const Color surface = Color(0xFF16212E);
  static const Color ink = Color(0xFFE8EEF5);
  static const Color muted = Color(0xFF9DB0C4);
  static const Color accent = Color(0xFF39C6B0);

  static const Color closeRed = Color(0xFFE2574C); // proximity: very close
  static const Color farOrange = Color(0xFFF4B942); // proximity: farther
  static const Color unknownWhite = Color(0xFFFFFFFF); // unknown sound
}

/// Proximity color from a raw level (0.0 silent .. 1.0 very loud).
/// PRD: strength drives both intensity and red/orange choice.
Color proximityColor(double strength) {
  if (strength >= 0.75) return SoundscapeColors.closeRed;
  if (strength >= 0.4) return SoundscapeColors.farOrange;
  return SoundscapeColors.unknownWhite;
}
