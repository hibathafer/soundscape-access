import 'package:vibration/vibration.dart';

/// Thin wrapper per spec.md > Components > Vibration Service:
/// one buzz per captured event while the toggle is ON — no patterns.
class VibrationService {
  bool _hasVibrator = true;

  Future<void> buzzOnEvent(bool enabled) async {
    if (!enabled) return;
    if (_hasVibrator) {
      final has = await Vibration.hasVibrator();
      if (!has) {
        _hasVibrator = false;
        return;
      }
    }
    try {
      await Vibration.vibrate(duration: 80);
    } catch (_) {
      // Never let haptics break the session (spec.md > Failure Modes).
    }
  }
}
