import 'dart:math' as math;

/// How a sound began — measured from the level's rise rate, never guessed.
/// prd.md > Sound pulse (the visual vocabulary).
enum Onset {
  /// A bang / slam: the level jumps high within one or two feeds.
  sudden,

  /// Speech building up / birds: the level climbs more slowly.
  gradual,
}

/// How the sound behaves over time — measured from strike intervals.
enum Rhythm {
  /// One held sound (engine, speech, wind).
  continuous,

  /// Repeated strikes at similar intervals (knocking, alarm beeps).
  repeating,
}

/// One described sound: the kernel's honest vocabulary.
class SoundBehavior {
  const SoundBehavior({
    required this.strength,
    required this.onset,
    required this.rhythm,
    required this.strike,
  });

  /// Loudness of the sound right now, 0.0 silent .. 1.0 very loud.
  final double strength;
  final Onset onset;
  final Rhythm rhythm;

  /// True on the feed where a new sound ignited (or re-struck) the pulse.
  final bool strike;
}

/// What one feed produced: the active sound (if any) and whether a sound
/// just finished (so the UI can fade to calm).
class FeedResult {
  const FeedResult({this.active, this.ended = false});

  /// Non-null while the sound is above threshold (ignition or sustain).
  final SoundBehavior? active;

  /// True exactly once when a sounding period ends — the fade-out trigger.
  final bool ended;

  static const silence = FeedResult();
}

/// Sound Behavior Analyzer — spec.md > Components.
///
/// Pure Dart, no Flutter, no platform: push the level stream in (the capture
/// layer feeds it ~10 times/second), get the pulse's description out.
///
/// This is where the "measure, don't guess" discipline lives. The direction
/// avenue is closed (four documented rounds — see spec.md > Decisions and
/// Open Issues); what we honestly *can* measure is how a sound behaves in
/// time, and that is what feeds the visual vocabulary.
class BehaviorAnalyzer {
  BehaviorAnalyzer({
    this.threshold = 0.4,
    this.suddenRise = 0.22,
    this.minStrikeGap = const Duration(milliseconds: 120),
    this.maxStrikeGap = const Duration(milliseconds: 2500),
    this.endHoldFeeds = 2,
  });

  /// Level at (or above) which a sound is considered present.
  final double threshold;

  /// Rise within a single feed that counts as a sudden onset.
  final double suddenRise;

  /// Gaps outside [minStrikeGap, maxStrikeGap] reset the rhythm evidence
  /// (a random lone bang is not a pattern).
  final Duration minStrikeGap;
  final Duration maxStrikeGap;

  /// How many consecutive below-threshold feeds end a sounding period.
  /// 2 feeds (~200 ms) keeps brief dips inside continuous sounds from
  /// splitting them, while real gaps between knocks still end the sound
  /// so the next knock re-strikes the pulse.
  final int endHoldFeeds;

  bool _active = false;
  int _below = 0;
  double _prevLevel = 0.0;
  Onset _onset = Onset.gradual;
  Rhythm _rhythm = Rhythm.continuous;
  DateTime? _lastStrikeAt;
  final List<Duration> _gaps = [];

  /// True while a sounding period is open.
  bool get active => _active;

  /// Feed one level sample; [at] is its timestamp.
  FeedResult feed(double level, DateTime at) {
    if (level >= threshold) {
      _below = 0;
      if (!_active) {
        // Ignition: classify how fast it arrived.
        _active = true;
        _onset = (level - _prevLevel) >= suddenRise ? Onset.sudden : Onset.gradual;
        _rememberStrike(at);
        _prevLevel = level;
        return FeedResult(active: SoundBehavior(
          strength: level,
          onset: _onset,
          rhythm: _rhythm,
          strike: true,
        ));
      }
      _prevLevel = level;
      return FeedResult(active: SoundBehavior(
        strength: level,
        onset: _onset,
        rhythm: _rhythm,
        strike: false,
      ));
    }

    // Below threshold.
    _prevLevel = level;
    if (!_active) return FeedResult.silence;

    _below++;
    if (_below < endHoldFeeds) {
      // Brief dip inside a continuing sound — hold the pulse.
      return FeedResult(active: SoundBehavior(
        strength: level,
        onset: _onset,
        rhythm: _rhythm,
        strike: false,
      ));
    }

    // The sounding period is over — the UI fades to calm.
    _active = false;
    return const FeedResult(ended: true);
  }

  /// Forget everything (new session).
  void reset() {
    _active = false;
    _below = 0;
    _prevLevel = 0.0;
    _onset = Onset.gradual;
    _rhythm = Rhythm.continuous;
    _lastStrikeAt = null;
    _gaps.clear();
  }

  /// Track strike timing; repeating = at least three strikes whose last two
  /// gaps are both in range *and* similar to each other (±45%). Speech
  /// pauses are irregular, knocking is regular — the similarity test is
  /// what keeps words from turning into rhythm rings.
  void _rememberStrike(DateTime at) {
    final last = _lastStrikeAt;
    _lastStrikeAt = at;
    if (last == null) return;

    final gap = at.difference(last);
    if (gap < minStrikeGap || gap > maxStrikeGap) {
      _gaps.clear(); // silence too long — this bang starts a fresh pattern
      return;
    }
    _gaps.add(gap);
    if (_gaps.length >= 2) {
      final a = _gaps[_gaps.length - 2].inMilliseconds;
      final b = _gaps.last.inMilliseconds;
      final diff = (a - b).abs();
      if (diff <= 0.45 * math.max(a, b)) _rhythm = Rhythm.repeating;
    }
  }
}
