import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'categories.dart';

/// YAMNet loaded on-device: a 0.975 s PCM slice -> 521 scores -> a category.
/// spec.md > Components > Sound Classifier. Fully offline, nothing leaves the
/// phone (prd.md > Data and privacy).
///
/// The model accepts 15600 mono samples @ 16 kHz in [-1.0, 1.0] and returns a
/// 521-long score vector (verified against the model's own embedded metadata
/// at build time). Inference runs in a background isolate so the pulse
/// animation never waits on it — the kernel's smoothness comes first.
class YamnetClassifier {
  Interpreter? _interp;
  IsolateInterpreter? _isolate;

  /// Model class names, index-aligned to the score vector (assets/model/).
  List<String> labels = const [];

  bool _busy = false;
  Future<bool>? _loading;

  /// 0.975 s of 16 kHz audio — the model's fixed window length.
  static const int windowSamples = 15600;
  static const int numClasses = 521;

  bool get isReady => _interp != null;

  /// Load once and reuse; concurrent callers share the same attempt.
  Future<bool> load() => _loading ??= _doLoad();

  Future<bool> _doLoad() async {
    try {
      final interp = await Interpreter.fromAsset(
        'assets/model/yamnet_mediapipe.tflite',
      );
      final isolate = await IsolateInterpreter.create(address: interp.address);

      final raw = await rootBundle.loadString('assets/model/labels.txt');
      final parsed = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);

      _interp = interp;
      _isolate = isolate;
      labels = parsed;

      debugPrint(
        'YAMNET ready in=${interp.getInputTensor(0).shape} '
        'out=${interp.getOutputTensor(0).shape} labels=${labels.length}',
      );
      return true;
    } catch (e) {
      // Honest fallback: no model -> every sound stays unknown (prd.md >
      // Unknown sounds), the pulse keeps working.
      debugPrint('YAMNET load failed: $e');
      return false;
    }
  }

  /// Classify one window. Returns null when the model isn't ready, a call is
  /// already in flight, or inference fails — callers treat null as "no name".
  Future<List<double>?> scores(Float32List window) async {
    final interp = _interp;
    final isolate = _isolate;
    if (interp == null || isolate == null) return null;
    if (_busy || window.length != windowSamples) return null;

    _busy = true;
    try {
      final input = _reshape(window, interp.getInputTensor(0).shape);
      final output = _zeros(interp.getOutputTensor(0).shape);
      await isolate.run(input, output);
      final out = List<double>.filled(numClasses, 0.0);
      _flattenInto(output, out, 0);
      return out;
    } catch (e) {
      debugPrint('YAMNET run failed: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Convenience: window -> every category that clears the threshold
  /// (strongest first), or a single unknown when none does.
  Future<List<CategoryGuess>> guesses(Float32List window) async {
    final s = await scores(window);
    if (s == null) return const [CategoryGuess(SoundCategory.unknown, 0.0)];
    return guessesFromScores(s);
  }

  /// Name of the single strongest class in a score vector (debug/tuning only).
  String topLabel(List<double> s) {
    if (labels.isEmpty || s.isEmpty) return '?';
    var idx = 0;
    for (var i = 1; i < s.length && i < labels.length; i++) {
      if (s[i] > s[idx]) idx = i;
    }
    return '$idx:${labels[idx]}=${s[idx].toStringAsFixed(2)}';
  }

  void dispose() {
    _isolate?.close();
    _interp?.close();
    _isolate = null;
    _interp = null;
    _loading = null;
  }

  // --- shape helpers: the graph's declared shapes win, we never guess ---

  static Object _reshape(Float32List flat, List<int> shape) {
    if (shape.length == 1) return flat;
    if (shape.length == 2) return [flat];
    throw StateError('unexpected input rank ${shape.length}: $shape');
  }

  static Object _zeros(List<int> shape) {
    if (shape.length == 1) return List<double>.filled(shape[0], 0.0);
    return List.generate(shape[0], (_) => _zeros(shape.sublist(1)));
  }

  /// Flatten the graph's (possibly nested) output into `out`, writing at
  /// most `out.length` values from index `i` onward. Extra trailing outputs
  /// (embedding/spectrogram tensors) are ignored — we only want scores.
  static void _flattenInto(Object node, List<double> out, int i) {
    if (i >= out.length) return;
    if (node is List) {
      var next = i;
      for (final child in node) {
        _flattenInto(child, out, next);
        next += _sizeOf(child);
      }
    } else {
      out[i] = (node as num).toDouble();
    }
  }

  static int _sizeOf(Object node) =>
      node is List ? node.fold<int>(0, (n, c) => n + _sizeOf(c)) : 1;
}
