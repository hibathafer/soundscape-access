import 'package:flutter_test/flutter_test.dart';
import 'package:soundscape_access/classify/categories.dart';

/// A 521-long score vector with only `index` set high.
List<double> scoresWith(Map<int, double> byIndex) {
  final s = List<double>.filled(521, 0.0);
  byIndex.forEach((i, v) => s[i] = v);
  return s;
}

void main() {
  group('guessesFromScores — mapping', () {
    test('every category can be named by its real YAMNet classes', () {
      // Indices chosen from the actual class map (see assets/model/labels).
      const cases = {
        301: SoundCategory.cars, // Car
        0: SoundCategory.speech, // Speech
        353: SoundCategory.door, // Knock
        393: SoundCategory.alarm, // Smoke detector, smoke alarm
        107: SoundCategory.birds, // Bird vocalization, bird call, bird song
      };

      for (final entry in cases.entries) {
        final g = guessesFromScores(
          scoresWith({entry.key: 0.9}),
        );
        expect(g, hasLength(1), reason: 'single clear class');
        expect(g.first.category, entry.value,
            reason: 'index ${entry.key} must map to ${entry.value.name}');
        expect(g.first.confidence, closeTo(0.9, 1e-9));
      }
    });

    test('below threshold resolves to unknown, never a guess', () {
      final g = guessesFromScores(
        scoresWith({301: kConfidenceThreshold - 0.01, 0: 0.1}),
      );
      expect(g.single.category, SoundCategory.unknown);
    });

    test('unlisted classes resolve to unknown (honest fallback)', () {
      // 69 = Dog: deliberately outside the five promised categories.
      final g = guessesFromScores(scoresWith({69: 0.95}));
      expect(g.single.category, SoundCategory.unknown);
    });

    test('two strong categories at once come back as two guesses', () {
      final g = guessesFromScores(scoresWith({0: 0.8, 107: 0.6}));
      expect(g, hasLength(2));
      expect(g.first.category, SoundCategory.speech); // strongest first
      expect(g.last.category, SoundCategory.birds);
    });

    test('guesses are sorted strongest-first', () {
      final g = guessesFromScores(scoresWith({393: 0.9, 0: 0.7, 353: 0.5}));
      expect(g.map((x) => x.category).toList(), [
        SoundCategory.alarm,
        SoundCategory.speech,
        SoundCategory.door,
      ]);
      for (var i = 1; i < g.length; i++) {
        expect(g[i - 1].confidence >= g[i].confidence, isTrue);
      }
    });

    test('the five category index sets are disjoint', () {
      final seen = <int, SoundCategory>{};
      kCategoryIndexMap.forEach((cat, idxs) {
        for (final i in idxs) {
          expect(seen.containsKey(i), isFalse,
              reason: 'index $i claimed by both '
                  '${seen[i]?.name} and ${cat.name}');
          seen[i] = cat;
        }
      });
      expect(seen.length, greaterThan(100), reason: 'map should be substantial');
    });

    test('guessFromScores returns the strongest single guess', () {
      final g = guessFromScores(scoresWith({301: 0.9, 0: 0.5}));
      expect(g.category, SoundCategory.cars);
    });
  });
}
