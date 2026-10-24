import 'package:vibration/vibration.dart';

/// Thin wrapper per spec.md > Components > Vibration Service:
/// one buzz per captured event while the toggle is ON — no patterns.
///
/// How *long* the phone rings follows how loud the sound actually was: a soft
/// rustle is a light tap, a car horn is a firm press. It is still a single
/// pulse each time — what `scope.md > Explicitly Cut` ruled out was patterns,
/// not the strength of the feedback.
class VibrationService {
  /// The floor. Even the quietest detected sound has to be findable in a
  /// pocket; below this a buzz is easy to miss entirely.
  static const int minDurationMs = 80;

  /// The ceiling. Loud enough to be unmistakable, short enough that a burst
  /// of sounds never smears into the continuous hum the learner called
  /// annoying (checklist.md > Product Decisions).
  static const int maxDurationMs = 250;

  bool _hasVibrator = true;

  /// Loudness (0 silent .. 1 very loud) → how long to ring, scaled linearly
  /// between the two bounds. Public so the mapping can be tested on its own.
  static int durationForStrength(double strength) {
    final s = strength.clamp(0.0, 1.0).toDouble();
    return (minDurationMs + s * (maxDurationMs - minDurationMs)).round();
  }

  /// [strength] is the sound's loudness at the moment it was detected; it
  /// sets the length of the buzz. Anything that goes wrong here is swallowed
  /// — haptics must never take the session down with them.
  Future<void> buzzOnEvent(bool enabled, {double strength = 1.0}) async {
    if (!enabled) return;
    try {
      // Kept inside the guard below on purpose: an unavailable vibrator API
      // must degrade to "no buzz", never to an unhandled async error.
      if (_hasVibrator) {
        final has = await Vibration.hasVibrator();
        if (!has) {
          _hasVibrator = false;
          return;
        }
      }
      await Vibration.vibrate(duration: durationForStrength(strength));
    } catch (_) {
      // Never let haptics break the session (spec.md > Failure Modes).
    }
  }
}
