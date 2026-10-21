import 'dart:async';

import 'package:flutter/services.dart';

/// Dart side of the slice-2 direction probe (spec.md > Direction Estimator).
///
/// Streams per-source levels {bottom: dB, top: dB} from the Kotlin bridge.
/// Used only in the research/debug phase; the production estimator logic
/// is decided by the outcome of this probe.
class MicProbeStream {
  static const _method = MethodChannel('soundscape/mic_probe');
  static const _events = EventChannel('soundscape/mic_levels');

  StreamSubscription? _sub;
  bool get isRunning => _sub != null;

  /// Starts both mic sources. Returns false if the device refused
  /// (either source failed to open) — that is a probe failure, honestly.
  Future<bool> start(void Function(Map<String, double> levels) onLevels) async {
    if (isRunning) return true;
    final ok = await _method.invokeMethod<bool>('start') ?? false;
    if (!ok) return false;
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        onLevels(event.map((k, v) =>
            MapEntry(k.toString(), (v as num).toDouble())));
      }
    });
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _method.invokeMethod('stop');
  }

  /// Round 5: one isolated stereo record. Same event stream, different
  /// native entry point — keys arrive as stL / stR.
  Future<bool> startStereo(
      void Function(Map<String, double> levels) onLevels) async {
    if (isRunning) return true;
    final ok = await _method.invokeMethod<bool>('start_stereo') ?? false;
    if (!ok) return false;
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        onLevels(event.map((k, v) =>
            MapEntry(k.toString(), (v as num).toDouble())));
      }
    });
    return true;
  }
}
