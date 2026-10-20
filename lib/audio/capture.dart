import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../session/controller.dart';

/// Keeps the microphone open for the session and turns loudness into
/// events — spec.md > Components > Audio Capture Service.
///
/// Slice 1 uses the amplitude stream as the live level. Slice 2 adds the
/// per-microphone probe, and slice 4 switches the payload to 16 kHz PCM
/// slices fed to YAMNet (see spec.md > File Structure).
class AudioCapture {
  AudioCapture(this._session);
  final SessionController _session;

  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  bool _running = false;
  bool get isRunning => _running;

  Future<bool> start() async {
    if (_running) return true;
    if (!await _recorder.hasPermission()) return false;

    // Level meter is enough for slice 1's live session evidence.
    await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000, // YAMNet's expected input rate (spec.md > Stack)
        numChannels: 1,
      ),
    );
    _running = true;

    // The stream itself carries PCM; level comes from amplitude updates.
    // (PCM payload is consumed from slice 4 on — see spec.md > Components.)

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // record reports dBFS in [-160, 0]; map to 0..1 for the controller.
      final db = amp.current;
      final level = ((db + 60) / 60).clamp(0.0, 1.0);
      debugPrint('CAP db=$db level=${level.toStringAsFixed(2)}');
      _session.onLevel(level.toDouble());
    });
    return true;
  }

  Future<void> stop() async {
    // Report silence first, before any await (dispose is synchronous and
    // may run while we are parked on an await below).
    _session.onLevel(0);
    await _ampSub?.cancel();
    _ampSub = null;
    if (_running) {
      await _recorder.stop();
      _running = false;
    }
  }
}
