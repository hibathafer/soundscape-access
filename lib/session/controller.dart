import 'package:flutter/foundation.dart';

import '../analyze/behavior.dart';
import '../classify/categories.dart';

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

/// One floating, swipeable bubble naming a sound type —
/// prd.md > Sound-type bubbles. One per category: a sound that keeps
/// happening refreshes its bubble instead of piling up duplicates.
class SoundBubble {
  SoundBubble({
    required this.id,
    required this.category,
    required this.confidence,
    required this.strength,
    required this.at,
  });

  final int id;
  final SoundCategory category;

  /// Model confidence at the last refresh, 0.0 .. 1.0 (0 for unknown/no model).
  double confidence;

  /// Loudness of the sound, 0.0 .. 1.0 — drives the bubble's red/orange.
  double strength;

  /// Last time a window named this category; a bubble this old expires.
  DateTime at;
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

  // --- The named sounds (slice 4) ---
  /// Live bubbles, one per category — spec.md > Data Model.
  final List<SoundBubble> _bubbles = [];
  List<SoundBubble> get bubbles => List.unmodifiable(_bubbles);
  int _nextBubbleId = 1;

  /// How long a bubble survives without a window re-naming it. A sound that
  /// stops therefore clears its bubble on its own; the screen returns to the
  /// PRD's quiet state (prd.md > Sound capture > quiet session).
  static const Duration bubbleTtl = Duration(seconds: 3);

  /// Hard cap so two-plus simultaneous sounds can never crowd the screen.
  static const int maxBubbles = 4;

  final _analyzer = BehaviorAnalyzer();

  final List<SoundEvent> _events = [];
  List<SoundEvent> get events => List.unmodifiable(_events);

  /// Events captured since the last [consumeEvents]. [events] is rolling
  /// display history and is never drained, so the vibration trigger counts
  /// this instead: one buzz per newly captured event, no matter how many
  /// times listeners are notified in between. Kept as the events themselves,
  /// not a count, so the buzz can follow how loud each sound actually was.
  final List<SoundEvent> _pendingEvents = [];
  int get pendingEventCount => _pendingEvents.length;

  /// Hands over the events captured since the last call and clears the
  /// pending list, so re-notifying a listener cannot replay a buzz. The
  /// visible [events] history is left untouched.
  List<SoundEvent> consumeEvents() {
    final taken = List<SoundEvent>.unmodifiable(_pendingEvents);
    _pendingEvents.clear();
    return taken;
  }

  /// Called by the capture layer ~10 times/second with the live level.
  void onLevel(double level) {
    currentLevel = level;
    final now = DateTime.now();
    final result = _analyzer.feed(level, now);

    final active = result.active;
    if (active != null) {
      pulseStrength = active.strength;
      pulseOnset = active.onset;
      pulseRhythm = active.rhythm;
      // Stale levels can arrive after stop(); only a live session may arm
      // an event (and therefore a buzz).
      if (active.strike && sessionActive) {
        pulseStrike++;
        final event = SoundEvent(
          strength: active.strength,
          onset: active.onset,
          rhythm: active.rhythm,
          at: DateTime.now(),
        );
        _events.add(event);
        _pendingEvents.add(event);
        // Keep only the most recent events; slice 4 owns display logic.
        if (_events.length > 4) _events.removeAt(0);
      }
    } else if (result.ended) {
      // Sound over — the pulse fades to calm (prd.md > Sound pulse).
      pulseStrength = 0.0;
      pulseOnset = Onset.gradual;
      pulseRhythm = Rhythm.continuous;
    }
    // A bubble whose sound went quiet expires here, with no timer needed.
    _expireBubbles(now);
    notifyListeners();
  }

  /// Called by the capture layer when YAMNet names (or fails to name) a
  /// window. One bubble per category: a repeat refreshes it, a different
  /// category becomes a second bubble (two sounds at once -> two bubbles).
  void onSound(SoundCategory category, double confidence, double strength) {
    if (!sessionActive) return;
    final now = DateTime.now();

    SoundBubble? same;
    for (final b in _bubbles) {
      if (b.category == category) {
        same = b;
        break;
      }
    }

    if (same != null) {
      same.confidence = confidence;
      same.strength = strength;
      same.at = now;
    } else {
      _bubbles.add(SoundBubble(
        id: _nextBubbleId++,
        category: category,
        confidence: confidence,
        strength: strength,
        at: now,
      ));
      // Oldest first: the sound nobody is re-confirming leaves first.
      _bubbles.sort((a, b) => a.at.compareTo(b.at));
      if (_bubbles.length > maxBubbles) {
        _bubbles.removeAt(0);
      }
    }
    notifyListeners();
  }

  /// Swipe-down dismisses a bubble — prd.md > Sound-type bubbles.
  void dismissBubble(int id) {
    _bubbles.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  /// Drop bubbles whose sound stopped (called on every level feed, ~10/s, so
  /// the quiet state needs no timer of its own).
  void _expireBubbles(DateTime now) {
    final cutoff = now.subtract(bubbleTtl);
    _bubbles.removeWhere((b) => b.at.isBefore(cutoff));
  }

  void start() {
    sessionActive = true;
    _analyzer.reset();
    pulseStrength = 0.0;
    pulseStrike = 0;
    _bubbles.clear();
    notifyListeners();
  }

  void stop() {
    sessionActive = false;
    currentLevel = 0.0;
    pulseStrength = 0.0;
    pulseStrike = 0;
    _analyzer.reset();
    _events.clear();
    _pendingEvents.clear();
    _bubbles.clear();
    notifyListeners();
  }

  void setVibration(bool on) {
    vibrationEnabled = on;
    notifyListeners();
  }
}
