import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Slice 5 — the attempt at a background session, and its honest fallback.
/// spec.md > File Structure, spec.md > Important Failure Modes.
///
/// Android only grants an app the right to read the microphone in the
/// background while a microphone-typed foreground service is up, so the whole
/// contract with the platform is one boolean: did the service come up?
///
/// Every call here is best-effort and **never throws**. Three ways the answer
/// can be "no", and all three mean the same thing to the session:
///   - the platform refused (microphone-typed starts are foreground-only),
///   - MIUI/HyperOS killed or blocked the service,
///   - the channel does not exist (tests, non-Android targets).
/// In every case the session simply keeps running with the app in front —
/// the fallback the PRD approved before any of this was written.
class BackgroundSession {
  static const MethodChannel _channel = MethodChannel('soundscape/background');
  static const EventChannel _state = EventChannel('soundscape/background_state');

  /// Starts the foreground service. False ⇒ run in front.
  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException catch (e) {
      debugPrint('BG start refused: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Ends the foreground service. Idempotent and silent — stopping a session
  /// must never fail because nothing was running.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      debugPrint('BG stop: $e');
    }
  }

  /// The platform's own answer, used when the app returns to the foreground:
  /// the service may have died while nobody was watching.
  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } catch (e) {
      debugPrint('BG isRunning: $e');
      return false;
    }
  }

  /// Fires only when the service dies while the app is still alive, which is
  /// the one case a foreground poll would have missed. Never throws.
  Stream<bool> get stateChanges {
    try {
      return _state.receiveBroadcastStream().map((v) => v == true);
    } catch (e) {
      debugPrint('BG state stream: $e');
      return const Stream<bool>.empty();
    }
  }
}
