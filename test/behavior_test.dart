import 'package:flutter_test/flutter_test.dart';

import 'package:soundscape_access/analyze/behavior.dart';

/// Synthetic level streams for the Sound Behavior Analyzer —
/// checklist slice 3: "analyzer tests pass (sudden vs gradual streams,
/// repeated peaks vs sustained, decay)".
///
/// The real capture feeds ~10 samples/second; these tests build the same
/// shape by hand, so the analyzer's logic is proven without a microphone.
void main() {
  // Feed a stream of (level, milliseconds-from-start) pairs.
  List<FeedResult> run(
    BehaviorAnalyzer analyzer,
    List<(double, int)> stream,
  ) =>
      stream
          .map((s) => analyzer.feed(s.$1, DateTime(2026).add(Duration(milliseconds: s.$2))))
          .toList();

  group('onset classification (rise rate)', () {
    test('a sudden bang (big jump in one feed) is onset=sudden', () {
      final a = BehaviorAnalyzer();
      // Silence, then one huge jump: 0.1 -> 0.9 in 100 ms.
      final results = run(a, [(0.1, 0), (0.9, 100)]);

      final ignition = results[1].active!;
      expect(ignition.strike, isTrue);
      expect(ignition.onset, Onset.sudden);
      expect(ignition.strength, closeTo(0.9, 0.001));
    });

    test('a gradual rise (small steps) is onset=gradual', () {
      final a = BehaviorAnalyzer();
      // Climbing ~0.15 per feed — under the suddenRise threshold.
      final results = run(a, [
        (0.1, 0),
        (0.25, 100),
        (0.45, 200), // crosses threshold by climbing, not jumping
      ]);

      final ignition = results[2].active!;
      expect(ignition.strike, isTrue);
      expect(ignition.onset, Onset.gradual);
    });
  });

  group('rhythm classification (strike intervals)', () {
    test('three evenly spaced strikes are rhythm=repeating', () {
      final a = BehaviorAnalyzer();
      // Three knocks, each: bang + dip below threshold between knocks.
      final results = run(a, [
        (0.8, 0), (0.2, 100), (0.1, 200), // knock 1 + decay
        (0.8, 600), (0.2, 700), (0.1, 800), // knock 2 (gap ~600 ms)
        (0.8, 1200), (0.2, 1300), (0.1, 1400), // knock 3 (gap ~600 ms)
      ]);

      final strikes = results
          .where((r) => r.active?.strike ?? false)
          .map((r) => r.active!)
          .toList();
      expect(strikes, hasLength(3));
      // The gaps are similar (~600 ms each) → after the third strike
      // the analyzer sees the pattern.
      expect(strikes[2].rhythm, Rhythm.repeating);
    });

    test('irregular gaps do NOT become repeating', () {
      final a = BehaviorAnalyzer();
      // Each knock: bang + two feeds below threshold (the sound genuinely
      // ends between knocks — same shape as the repeating test above).
      final results = run(a, [
        (0.8, 0), (0.1, 100), (0.1, 200),
        (0.8, 500), (0.1, 600), (0.1, 700), // gap 500 ms
        (0.8, 2000), (0.1, 2100), (0.1, 2200), // gap 1500 ms — very different
      ]);

      final strikes = results
          .where((r) => r.active?.strike ?? false)
          .map((r) => r.active!)
          .toList();
      expect(strikes, hasLength(3));
      expect(strikes.last.rhythm, isNot(Rhythm.repeating));
    });

    test('one continuous sound stays rhythm=continuous', () {
      final a = BehaviorAnalyzer();
      final results = run(a, [
        (0.8, 0), (0.75, 100), (0.85, 200), (0.8, 300), (0.7, 400),
      ]);

      final strikes = results
          .where((r) => r.active?.strike ?? false)
          .map((r) => r.active!)
          .toList();
      expect(strikes, hasLength(1)); // one ignition, then sustain
      expect(strikes.single.rhythm, Rhythm.continuous);
      // Sustain feeds keep reporting the live strength without re-striking.
      expect(results[3].active!.strike, isFalse);
      expect(results[3].active!.strength, closeTo(0.8, 0.001));
    });
  });

  group('sustain, decay, and silence', () {
    test('a brief dip inside a sound does not end it', () {
      final a = BehaviorAnalyzer();
      final results = run(a, [
        (0.8, 0),
        (0.2, 100), // dip — still within endHoldFeeds
        (0.8, 200), // back up
      ]);

      expect(results[1].ended, isFalse); // dip: still sounding
      expect(results[1].active, isNotNull);
      expect(results[2].active!.strike, isFalse); // not a new strike
    });

    test('level staying below threshold ends the sound exactly once', () {
      final a = BehaviorAnalyzer();
      final results = run(a, [
        (0.8, 0),
        (0.1, 100), (0.1, 200), (0.1, 300), // below threshold, held
      ]);

      expect(results.where((r) => r.ended), hasLength(1));
      expect(results.last.active, isNull); // silence afterwards
    });

    test('a loud sound is reported with its full strength', () {
      final a = BehaviorAnalyzer();
      final results = run(a, [(0.1, 0), (0.95, 100)]);

      expect(results[1].active!.strength, closeTo(0.95, 0.001));
    });

    test('reset clears state for a new session', () {
      final a = BehaviorAnalyzer();
      run(a, [(0.8, 0), (0.8, 100)]);
      expect(a.active, isTrue);

      a.reset();
      expect(a.active, isFalse);

      // A fresh strike after reset is a fresh ignition.
      final r = a.feed(0.8, DateTime(2026).add(const Duration(seconds: 5)));
      expect(r.active!.strike, isTrue);
    });
  });
}
