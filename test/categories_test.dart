import 'package:flutter_test/flutter_test.dart';
import 'package:soundscape_access/classify/categories.dart';
import 'package:soundscape_access/classify/yamnet.dart';

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

    test('skipped inference is distinct from a genuine unknown result', () {
      expect(guessesFromNullableScores(null), isNull);
      final result = guessesFromNullableScores(scoresWith({69: 0.95}));
      expect(result?.single.category, SoundCategory.unknown);
    });

    test('diagnostic peaks and top labels report the real score vector', () {
      final classifier = YamnetClassifier()
        ..labels = List<String>.generate(521, (i) => 'label-$i');
      final scores = scoresWith({
        301: 0.82,
        0: 0.42,
        353: 0.61,
        393: 0.50,
        107: 0.29,
      });

      final summary = classifier.diagnosticSummary(scores);

      expect(
        summary,
        'CLS_DIAG top=[301:label-301=0.820, 353:label-353=0.610, '
        '393:label-393=0.500, 0:label-0=0.420, 107:label-107=0.290] '
        'category_peaks=[cars=0.820, speech=0.420, door=0.610, '
        'alarm=0.500, birds=0.290, unknown=fallback]',
      );
    });

    test('one qualifying Knock window does not confirm Door', () {
      final confirmation = DoorKnockConfirmation();
      final scores = scoresWith({353: 0.148, 348: 0.109});

      expect(confirmation.addScores(scores), isNull);
      expect(guessesFromScores(scores).single.category, SoundCategory.unknown);
    });

    test('two qualifying Knock windows among three confirm Door once', () {
      final confirmation = DoorKnockConfirmation();
      final knock = scoresWith({353: 0.148, 348: 0.109, 354: 0.082});
      final other = scoresWith({465: 0.8});

      expect(confirmation.addScores(knock), isNull);
      expect(confirmation.addScores(other), isNull);
      expect(confirmation.addScores(knock)?.category, SoundCategory.door);
      expect(confirmation.addScores(knock), isNull);
    });

    test('repeated Tap or Bouncing without Knock does not confirm Door', () {
      final confirmation = DoorKnockConfirmation();
      final tap = scoresWith({354: 0.3});
      final bounce = scoresWith({465: 0.8});

      expect(confirmation.addScores(tap), isNull);
      expect(confirmation.addScores(bounce), isNull);
      expect(confirmation.addScores(tap), isNull);
      expect(confirmation.addScores(bounce), isNull);
      expect(guessesFromScores(tap).single.category, SoundCategory.unknown);
      expect(guessesFromScores(bounce).single.category, SoundCategory.unknown);
    });

    test('rolling three-window rule expires candidates outside the window', () {
      final confirmation = DoorKnockConfirmation();
      final knock = scoresWith({353: 0.148, 354: 0.082});
      final other = scoresWith({465: 0.8});

      expect(confirmation.addScores(knock), isNull);
      expect(confirmation.addScores(other), isNull);
      expect(confirmation.addScores(other), isNull);
      expect(confirmation.addScores(knock), isNull);
      expect(confirmation.addScores(knock)?.category, SoundCategory.door);
    });

    test('unconfirmed fallback preserves normal category outputs', () {
      final confirmation = DoorKnockConfirmation();
      final scores = scoresWith({301: 0.8, 353: 0.148, 354: 0.082});

      expect(confirmation.addScores(scores), isNull);
      expect(guessesFromScores(scores).map((guess) => guess.category), [
        SoundCategory.cars,
      ]);
    });

    test('reset clears Door history and re-arms its confirmation edge', () {
      final confirmation = DoorKnockConfirmation();
      final knock = scoresWith({353: 0.148, 354: 0.082});

      expect(confirmation.addScores(knock), isNull);
      expect(confirmation.addScores(knock)?.category, SoundCategory.door);
      confirmation.reset();
      expect(confirmation.addScores(knock), isNull);
      expect(confirmation.addScores(knock)?.category, SoundCategory.door);
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
