import 'package:flutter/foundation.dart';

/// One sound detected while the session runs.
/// Ephemeral per prd.md > Data Model: created, consumed by the UI, discarded.
class SoundEvent {
  const SoundEvent({required this.strength, required this.at});
  final double strength; // 0.0 .. 1.0
  final DateTime at;
}

/// Single owner of session state — spec.md > Components > Session Controller.
class SessionController extends ChangeNotifier {
  bool sessionActive = false;
  bool vibrationEnabled = false;

  /// Latest captured level, for the UI to show liveness (slice 1 evidence).
  double currentLevel = 0.0;

  final List<SoundEvent> _events = [];
  List<SoundEvent> get events => List.unmodifiable(_events);

  /// Called by the capture layer when a level crosses the event threshold.
  void onLevel(double level) {
    currentLevel = level;
    if (level >= 0.6) {
      _events.add(SoundEvent(strength: level, at: DateTime.now()));
      // Keep only the most recent event for now; slice 4 owns display logic.
      if (_events.length > 4) _events.removeAt(0);
    }
    notifyListeners();
  }

  void start() {
    sessionActive = true;
    notifyListeners();
  }

  void stop() {
    sessionActive = false;
    currentLevel = 0.0;
    _events.clear();
    notifyListeners();
  }

  void setVibration(bool on) {
    vibrationEnabled = on;
    notifyListeners();
  }
}
