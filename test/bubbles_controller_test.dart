import 'package:flutter_test/flutter_test.dart';
import 'package:soundscape_access/classify/categories.dart';
import 'package:soundscape_access/session/controller.dart';

void main() {
  group('sound bubbles (session rules)', () {
    test('a named sound creates one bubble', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.cars, 0.8, 0.6);

      expect(c.bubbles, hasLength(1));
      expect(c.bubbles.single.category, SoundCategory.cars);
      expect(c.bubbles.single.confidence, closeTo(0.8, 1e-9));
      expect(c.bubbles.single.strength, closeTo(0.6, 1e-9));
    });

    test('the same category refreshes its bubble instead of duplicating', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.speech, 0.5, 0.4);
      c.onSound(SoundCategory.speech, 0.9, 0.8);

      expect(c.bubbles, hasLength(1));
      expect(c.bubbles.single.confidence, closeTo(0.9, 1e-9));
      expect(c.bubbles.single.strength, closeTo(0.8, 1e-9));
    });

    test('two different sounds at once show two bubbles', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.speech, 0.8, 0.5);
      c.onSound(SoundCategory.cars, 0.7, 0.6);

      expect(c.bubbles, hasLength(2));
      expect(c.bubbles.map((b) => b.category),
          containsAll([SoundCategory.speech, SoundCategory.cars]));
    });

    test('unknown is its own bubble, kept apart from named ones', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.unknown, 0.0, 0.5);
      c.onSound(SoundCategory.unknown, 0.0, 0.7);
      c.onSound(SoundCategory.door, 0.6, 0.5);

      expect(c.bubbles, hasLength(2));
      expect(c.bubbles.where((b) => b.category == SoundCategory.unknown),
          hasLength(1));
    });

    test('a stopped session never accepts a bubble', () {
      final c = SessionController();
      c.onSound(SoundCategory.cars, 0.9, 0.9);
      expect(c.bubbles, isEmpty);
    });

    test('swipe dismiss removes exactly that bubble', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.cars, 0.8, 0.6);
      c.onSound(SoundCategory.door, 0.8, 0.6);
      expect(c.bubbles, hasLength(2));

      c.dismissBubble(c.bubbles.first.id);
      expect(c.bubbles, hasLength(1));
      expect(c.bubbles.single.category, SoundCategory.door);
    });

    test('stop clears every bubble', () {
      final c = SessionController()..start();
      c.onSound(SoundCategory.cars, 0.8, 0.6);
      c.onSound(SoundCategory.speech, 0.8, 0.6);
      expect(c.bubbles, hasLength(2));

      c.stop();
      expect(c.bubbles, isEmpty);
    });

    test('bubble count never exceeds the cap', () {
      final c = SessionController()..start();
      // More distinct categories than the cap allows (cap is a const; use
      // repeated distinct ids via unknown-then-named to force growth is not
      // possible, so assert the cap directly).
      for (final cat in SoundCategory.values) {
        c.onSound(cat, 0.9, 0.9);
      }
      expect(c.bubbles.length, lessThanOrEqualTo(SessionController.maxBubbles));
    });
  });
}
