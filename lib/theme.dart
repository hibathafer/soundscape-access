import 'package:flutter/material.dart';

/// A bright, calm, welcoming visual system.
///
/// Light neutral canvas, dark readable ink, teal accents. prd.md >
/// Look and Feel keeps its proximity semantics — red = very close,
/// orange = farther, a quiet neutral = unknown — restated for a light
/// canvas, where a pure white "unknown" would simply be invisible.
///
/// Every text colour here is checked against its own background for
/// WCAG AA; values that fall short are documented as fill-only.
class SoundscapeColors {
  /// Canvas. A soft off-white with a faint cool cast — calm, not clinical.
  static const Color background = Color(0xFFF4F7F6);

  /// Raised surfaces: cards, sheets, bubbles.
  static const Color surface = Color(0xFFFFFFFF);

  /// Recessed fills: idle tracks, quiet chips.
  static const Color surfaceMuted = Color(0xFFE8EFED);

  /// Hairlines and card borders.
  static const Color line = Color(0xFFD9E4E1);

  /// Primary text — 14.9:1 on [background].
  static const Color ink = Color(0xFF10201F);

  /// Secondary text — 5.4:1 on [background], AA for body copy.
  static const Color muted = Color(0xFF566866);

  /// The teal accent: primary action, focus, the live state.
  static const Color accent = Color(0xFF0E8C7F);

  /// Darker teal for accent *text* on light surfaces — 6.5:1 on white.
  static const Color accentInk = Color(0xFF0A6A60);

  /// Tinted teal fill for selected and idle states.
  static const Color accentSoft = Color(0xFFD5EDE9);

  // --- Proximity semantics (prd.md > Look and Feel) ---

  /// Very close — 4.7:1 on white, safe as text or fill.
  static const Color closeRed = Color(0xFFCE4338);

  /// Farther away — 3.3:1 on white: a dot/fill colour, not body text.
  static const Color farOrange = Color(0xFFC67C15);

  /// Unknown sound: a quiet neutral, deliberately outside the proximity
  /// scale so it can never read as "close" or "far".
  static const Color unknownGray = Color(0xFF7E9995);
}

/// Proximity colour from a raw level (0.0 silent .. 1.0 very loud).
/// PRD: strength drives both intensity and red/orange choice.
Color proximityColor(double strength) {
  if (strength >= 0.75) return SoundscapeColors.closeRed;
  if (strength >= 0.4) return SoundscapeColors.farOrange;
  return SoundscapeColors.unknownGray;
}
