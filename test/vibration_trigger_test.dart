import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundscape_access/classify/categories.dart';
import 'package:soundscape_access/session/controller.dart';
import 'package:soundscape_access/session/vibration_service.dart';
import 'package:soundscape_access/ui/home_screen.dart';

/// Ends any sound still sounding, then lands one clean bang — the same shape
/// behavior_test.dart uses to ignite the analyzer. Produces exactly one
/// [SoundEvent] whether or not a sound was already open, so each call stands
/// for "one captured event". [level] is how loud that bang is (0.4+ registers).
void bang(SessionController c, {double level = 0.9}) {
  c.onLevel(0.1);
  c.onLevel(0.1);
  c.onLevel(level);
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
  final List<double> strengths = [];

  /// Calls that would really move the motor.
  int get buzzes => asked.where((enabled) => enabled).length;

  /// The lengths those buzzes would have run, in milliseconds.
  List<int> get durations => [
        for (final s in strengths) VibrationService.durationForStrength(s),
      ];

  @override
  Future<void> buzzOnEvent(bool enabled, {double strength = 1.0}) async {
    asked.add(enabled);
    strengths.add(strength);
  }
}

void main() {
  group('vibration events (session controller)', () {
    test('one bang arms exactly one pending event', () {
      final c = SessionController()..start();

      bang(c);

      expect(c.pendingEventCount, 1);
      expect(c.consumeEvents(), hasLength(1));
      expect(c.pendingEventCount, 0);
    });

    test('re-notifying a listener cannot re-arm a consumed event', () {
      final c = SessionController()..start();
      bang(c);
      expect(c.consumeEvents(), hasLength(1));

      // Every tick notifies listeners, but nothing new was captured.
      sustain(c, ticks: 10);

      expect(c.pendingEventCount, 0);
      expect(c.consumeEvents(), isEmpty);
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
      expect(c.consumeEvents(), isEmpty); // stop dropped what was armed

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

    testWidgets('a louder sound buzzes for longer than a quiet one',
        (tester) async {
      final vibration = _RecordingVibration();
      final session = SessionController();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(session: session, vibration: vibration),
      ));

      session.start();
      session.setVibration(true);

      bang(session, level: 0.45); // just over the 0.4 threshold
      bang(session, level: 0.95); // a hard strike
      await tester.pump();

      expect(vibration.strengths, hasLength(2));
      final quiet = vibration.durations.first;
      final loud = vibration.durations.last;

      expect(vibration.strengths.first, closeTo(0.45, 1e-9));
      expect(vibration.strengths.last, closeTo(0.95, 1e-9));
      expect(quiet, lessThan(loud), reason: 'loudness must reach the motor');
      // Both stay inside the documented bounds — one pulse, never a pattern.
      expect(quiet, greaterThanOrEqualTo(VibrationService.minDurationMs));
      expect(loud, lessThanOrEqualTo(VibrationService.maxDurationMs));
    });
  });

  group('loudness → buzz length (vibration service)', () {
    test('the quietest sound still buzzes for the documented minimum', () {
      expect(VibrationService.durationForStrength(0),
          VibrationService.minDurationMs);
      // The quiet strike our analyzer can still register (just over the 0.4
      // threshold) has to be noticeably longer than silence's floor.
      expect(VibrationService.durationForStrength(0.4),
          greaterThan(VibrationService.minDurationMs));
    });

    test('buzz length rises with loudness and stops at the maximum', () {
      final quiet = VibrationService.durationForStrength(0.5);
      final mid = VibrationService.durationForStrength(0.75);
      final loud = VibrationService.durationForStrength(1.0);

      expect(quiet, lessThan(mid));
      expect(mid, lessThan(loud));
      expect(loud, VibrationService.maxDurationMs);
    });

    test('out-of-range loudness is clamped, never a wild duration', () {
      expect(VibrationService.durationForStrength(-1),
          VibrationService.minDurationMs);
      expect(VibrationService.durationForStrength(9),
          VibrationService.maxDurationMs);
    });
  });
}
