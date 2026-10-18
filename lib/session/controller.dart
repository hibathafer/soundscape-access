import 'package:flutter/foundation.dart';

import '../analyze/behavior.dart';

/// One sound detected while the session runs.
/// Ephemeral per prd.md > Data Model: created, consumed by the UI, discarded.
class SoundEvent {
  const SoundEvent({
    required this.strength,
    required this.onset,
    required this.rhythm,
    required this.at,
  });

  /// Loudness at the strike, 0.0 .. 1.0.
  final double strength;
  final Onset onset;
  final Rhythm rhythm;
  final DateTime at;
}

/// Single owner of session state — spec.md > Components > Session Controller.
class SessionController extends ChangeNotifier {
  bool sessionActive = false;
  bool vibrationEnabled = false;

  /// Latest captured level, for the UI to show liveness (slice 1 evidence).
  double currentLevel = 0.0;

  // --- The pulse's live description (the kernel's input) ---
  /// Loudness the pulse should show right now; 0 = nothing sounding.
  double pulseStrength = 0.0;
  Onset pulseOnset = Onset.gradual;
  Rhythm pulseRhythm = Rhythm.continuous;

  /// Increments on every strike (ignition or re-strike); the renderer
  /// re-ignites when it changes.
  int pulseStrike = 0;

  final _analyzer = BehaviorAnalyzer();

  final List<SoundEvent> _events = [];
  List<SoundEvent> get events => List.unmodifiable(_events);

  /// Called by the capture layer ~10 times/second with the live level.
  void onLevel(double level) {
    currentLevel = level;
    final result = _analyzer.feed(level, DateTime.now());

    final active = result.active;
    if (active != null) {
      pulseStrength = active.strength;
      pulseOnset = active.onset;
      pulseRhythm = active.rhythm;
      if (active.strike) {
        pulseStrike++;
        _events.add(SoundEvent(
          strength: active.strength,
          onset: active.onset,
          rhythm: active.rhythm,
          at: DateTime.now(),
        ));
        // Keep only the most recent events; slice 4 owns display logic.
        if (_events.length > 4) _events.removeAt(0);
      }
    } else if (result.ended) {
      // Sound over — the pulse fades to calm (prd.md > Sound pulse).
      pulseStrength = 0.0;
      pulseOnset = Onset.gradual;
      pulseRhythm = Rhythm.continuous;
    }
    notifyListeners();
  }

  void start() {
    sessionActive = true;
    _analyzer.reset();
    pulseStrength = 0.0;
    pulseStrike = 0;
    notifyListeners();
  }

  void stop() {
    sessionActive = false;
    currentLevel = 0.0;
    pulseStrength = 0.0;
    pulseStrike = 0;
    _analyzer.reset();
    _events.clear();
    notifyListeners();
  }

  void setVibration(bool on) {
    vibrationEnabled = on;
    notifyListeners();
  }
}
