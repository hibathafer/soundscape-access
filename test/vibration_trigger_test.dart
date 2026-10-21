import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundscape_access/classify/categories.dart';
import 'package:soundscape_access/session/controller.dart';
import 'package:soundscape_access/session/vibration_service.dart';
import 'package:soundscape_access/ui/home_screen.dart';

/// Ends any sound still sounding, then lands one clean bang — the same shape
/// behavior_test.dart uses to ignite the analyzer. Produces exactly one
/// [SoundEvent] whether or not a sound was already open, so each call stands
/// for "one captured event".
void bang(SessionController c) {
  c.onLevel(0.1);
  c.onLevel(0.1);
  c.onLevel(0.9);
}

/// Sustained level ticks: every one notifies listeners, none is a strike.
void sustain(SessionController c, {int ticks = 5}) {
  for (var i = 0; i < ticks; i++) {
    c.onLevel(0.85);
  }
}

/// Records exactly what the screen asks the vibration service to do.
class _RecordingVibration extends VibrationService {
  final List<bool> asked = [];

  /// Calls that would really move the motor.
  int get buzzes => asked.where((enabled) => enabled).length;

  @override
  Future<void> buzzOnEvent(bool enabled) async {
    asked.add(enabled);
  }
}

void main() {
  group('vibration events (session controller)', () {
    test('one bang arms exactly one pending event', () {
      final c = SessionController()..start();

      bang(c);

      expect(c.pendingEventCount, 1);
      expect(c.consumeEvents(), 1);
      expect(c.pendingEventCount, 0);
    });

    test('re-notifying a listener cannot re-arm a consumed event', () {
      final c = SessionController()..start();
      bang(c);
      expect(c.consumeEvents(), 1);

      // Every tick notifies listeners, but nothing new was captured.
      sustain(c, ticks: 10);

      expect(c.pendingEventCount, 0);
      expect(c.consumeEvents(), 0);
      expect(c.events, hasLength(1)); // the display history is untouched
    });

    test('consuming leaves the visible history and the bubbles intact', () {
      final c = SessionController()..start();
      bang(c);
      c.onSound(SoundCategory.speech, 0.9, 0.7);

      c.consumeEvents();

      expect(c.events, hasLength(1));
      expect(c.bubbles, hasLength(1));
      expect(c.bubbles.single.category, SoundCategory.speech);
    });

    test('levels arriving after stop cannot arm a new event', () {
      final c = SessionController()..start();
      bang(c);
      c.stop();
      expect(c.consumeEvents(), 0); // stop dropped what was armed

      bang(c); // stale post-stop level updates

      expect(c.events, isEmpty);
      expect(c.pendingEventCount, 0);
    });
  });

  group('vibration trigger (screen wiring)', () {
    testWidgets('one strike vibrates once, however many notifications follow',
        (tester) async {
      final vibration = _RecordingVibration();
      final session = SessionController();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(session: session, vibration: vibration),
      ));

      session.start();
      session.setVibration(true);
      bang(session);
      await tester.pump();
      expect(vibration.asked, [true]);

      // The old bug: the rolling history kept re-firing on every tick.
      sustain(session, ticks: 20);
      await tester.pump();
      expect(vibration.buzzes, 1);
      expect(vibration.asked, [true]);
      expect(session.events, hasLength(1)); // history still shown to the UI
    });

    testWidgets(
        'toggle off blocks the buzz, switching it on does not replay old events',
        (tester) async {
      final vibration = _RecordingVibration();
      final session = SessionController();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(session: session, vibration: vibration),
      ));

      session.start();
      session.setVibration(false);
      bang(session);
      await tester.pump();
      expect(vibration.buzzes, 0);
      expect(vibration.asked.where((enabled) => enabled), isEmpty);

      session.setVibration(true);
      await tester.pump();
      expect(vibration.buzzes, 0); // events caught while off are not replayed

      bang(session);
      await tester.pump();
      expect(vibration.buzzes, 1);

      session.setVibration(false);
      bang(session);
      await tester.pump();
      expect(vibration.buzzes, 1); // off again → nothing further
      expect(vibration.asked.last, isFalse);
    });
  });
}
