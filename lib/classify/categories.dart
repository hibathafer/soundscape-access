import 'package:flutter/foundation.dart';

/// The five categories the app may name — prd.md > Sound capture and
/// classification. Exactly these; nothing else is promised to the user, and
/// anything the model can't place here becomes [SoundCategory.unknown].
enum SoundCategory {
  cars('Cars / traffic'),
  speech('Speech / human voices'),
  door('Door / knocking'),
  alarm('Alarm / bell / beep'),
  birds('Birds / nature'),
  unknown('Unknown');

  const SoundCategory(this.label);
  final String label;
}

/// A guess for one audio window: which category, and how confident.
class CategoryGuess {
  const CategoryGuess(this.category, this.confidence);
  final SoundCategory category;

  /// Model confidence for the winning category, 0.0 .. 1.0.
  final double confidence;
}

/// Confidence at (or above) which a guess is believed; below it the sound is
/// named [SoundCategory.unknown]. Implementation constant (spec.md > Sound
/// Classifier), tuned during the build against real sounds — not a learner
/// decision. YAMNet scores are uncalibrated, so this is a pragmatic cut.
const double kConfidenceThreshold = 0.35;

/// Lower candidate floor for the Knock label, confirmed across a rolling
/// three-window history before it can add a Door event.
const double kKnockCandidateThreshold = 0.12;

/// YAMNet output index -> the category that index belongs to. Built by hand
/// from the real `yamnet_class_map.csv` display names (assets/model/labels.txt,
/// verified index-aligned to the model at build time) so the mapping is
/// reviewable and testable without running the model.
///
/// Each index appears in at most one set. Indices not listed here simply
/// cannot name a sound, so a window whose only energy sits in unlisted
/// classes resolves to [SoundCategory.unknown] — the honest fallback
/// (prd.md > Unknown sounds).
const Set<int> _speechIdx = {
  // 0..35 — human vocal sounds: speech, shouts, whispers, laughter, crying,
  // singing, humming, whistling.
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
  // Human presence as voices in a group.
  63, 64, 65, 66, // Chatter, Crowd, Hubbub, Children playing
};

const Set<int> _carsIdx = {
  // Road vehicles, horns, engines, traffic, rail, and aircraft.
  294, 300, 301, 302, 303, 305, 306, 307, 308, 309, 310, 311, 312, 315, 316,
  317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331,
  332, 333, 334, 335, 337, 338, 342, 343, 344, 345, 346, 347,
};

const Set<int> _doorIdx = {
  348, 349, 351, 352, 353, 354, // Door, Doorbell, Sliding door, Slam, Knock, Tap
};

const Set<int> _alarmIdx = {
  // Bells, chimes, rings, alarms, sirens-as-alerts, beeps.
  195, 196, 197, 198, 200, 201, 202, // Bell .. Change ringing
  304, 313, 350, // Car alarm, Reversing beeps, Ding-dong
  382, 383, 384, 385, 389, 390, 391, 392, 393, 394, 395, // Alarm .. Foghorn
  475, 477, // Beep, bleep / Ding
};

const Set<int> _birdsIdx = {
  // Birds and poultry — Fowl .. Bird flight (93..116, minus none): they are
  // literally birds, so they honestly carry the birds/nature icon.
  93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 106, 107, 108, 109, 110, 111,
  112, 113, 114, 115, 116,
  // Wild animals (not pets): they belong to the natural world.
  103, 104, 105, // Wild animals, Roaring cats, Roar
  // Insects, amphibians, reptiles, whale.
  121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131,
  // Weather and natural wind/water.
  277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291,
  // Deliberately EXCLUDED: domestic pets (Dog 69, Cat 76, rodents 117..120)
  // and livestock (81..92). Neither is "birds/nature" — a bark under a leaf
  // icon would name the sound wrongly, so they honestly stay unknown
  // (prd.md > Unknown sounds).
};

/// The one place a YAMNet score vector becomes categories.
///
/// Takes the strongest score among each category's member indices, then
/// returns every category that clears [kConfidenceThreshold], strongest
/// first — that is how two simultaneous sounds (speech while a car passes)
/// yield two bubbles (prd.md > Sound-type bubbles). If nothing clears it we
/// honestly return a single [SoundCategory.unknown] rather than inventing a
/// name (prd.md > Unknown sounds).
List<CategoryGuess> guessesFromScores(List<double> scores) {
  final ranked = <CategoryGuess>[];

  final peaks = categoryPeaksFromScores(scores);
  for (final entry in peaks.entries) {
    if (entry.value >= kConfidenceThreshold) {
      ranked.add(CategoryGuess(entry.key, entry.value));
    }
  }

  if (ranked.isEmpty) {
    return const [CategoryGuess(SoundCategory.unknown, 0.0)];
  }
  ranked.sort((a, b) => b.confidence.compareTo(a.confidence));
  return ranked;
}

/// Preserves a skipped inference as no result; a real score vector with no
/// category above threshold still resolves to the usual Unknown fallback.
List<CategoryGuess>? guessesFromNullableScores(List<double>? scores) =>
    scores == null ? null : guessesFromScores(scores);

/// Peak model score for each named app category. Unknown is a fallback rather
/// than a model class, so it is intentionally absent from this map.
Map<SoundCategory, double> categoryPeaksFromScores(List<double> scores) {
  final peaks = <SoundCategory, double>{};
  for (final cat in const [
    SoundCategory.cars,
    SoundCategory.speech,
    SoundCategory.door,
    SoundCategory.alarm,
    SoundCategory.birds,
  ]) {
    var peak = 0.0;
    for (final i in _membersOf(cat)) {
      if (i < scores.length && scores[i] > peak) peak = scores[i];
    }
    peaks[cat] = peak;
  }
  return peaks;
}

/// Confirms repeated wooden-knock evidence without changing normal category
/// thresholds or mappings. Returns a Door guess only when confirmation first
/// begins.
class DoorKnockConfirmation {
  final List<bool> _candidates = [];
  bool _confirmed = false;

  CategoryGuess? addScores(List<double> scores) {
    const knockIndex = 353;
    const tapIndex = 354;
    final knock = knockIndex < scores.length ? scores[knockIndex] : 0.0;
    final tap = tapIndex < scores.length ? scores[tapIndex] : 0.0;
    _candidates.add(
      knock >= kKnockCandidateThreshold && knock > tap,
    );
    if (_candidates.length > 3) _candidates.removeAt(0);

    final confirmed = _candidates.where((candidate) => candidate).length >= 2;
    final newlyConfirmed = confirmed && !_confirmed;
    _confirmed = confirmed;
    return newlyConfirmed ? CategoryGuess(SoundCategory.door, knock) : null;
  }

  void reset() {
    _candidates.clear();
    _confirmed = false;
  }
}

/// The strongest single category, or unknown when nothing clears the
/// threshold — the convenience view of [guessesFromScores].
CategoryGuess guessFromScores(List<double> scores) => guessesFromScores(scores).first;

Set<int> _membersOf(SoundCategory cat) => switch (cat) {
      SoundCategory.cars => _carsIdx,
      SoundCategory.speech => _speechIdx,
      SoundCategory.door => _doorIdx,
      SoundCategory.alarm => _alarmIdx,
      SoundCategory.birds => _birdsIdx,
      SoundCategory.unknown => const {},
    };

/// The five-category member map, exposed for tests and tuning review.
@visibleForTesting
Map<SoundCategory, Set<int>> get kCategoryIndexMap => {
      SoundCategory.cars: _carsIdx,
      SoundCategory.speech: _speechIdx,
      SoundCategory.door: _doorIdx,
      SoundCategory.alarm: _alarmIdx,
      SoundCategory.birds: _birdsIdx,
    };
