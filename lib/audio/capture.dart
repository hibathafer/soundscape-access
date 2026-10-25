import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../classify/categories.dart';
import '../classify/yamnet.dart';
import '../session/controller.dart';

/// Keeps the microphone open for the session and turns it into two streams:
/// the live level (drives the pulse) and 16 kHz PCM windows (named by YAMNet)
/// — spec.md > Components > Audio Capture Service.
///
/// Either platform stream can end without warning (screen off, the app pushed
/// to the background, an audio-hardware hiccup). That is observed here rather
/// than ignored: the death is logged, then the capture is reopened with
/// backoff while the session still wants sound. A dead microphone must never
/// masquerade as a quiet room — silence is a real measurement, not a fault
/// we paper over.
class AudioCapture {
  AudioCapture(this._session, {YamnetClassifier? classifier})
      : classifier = classifier ?? YamnetClassifier();

  final SessionController _session;

  /// The on-device model; loaded once in [start], reused across sessions.
  final YamnetClassifier classifier;
  final _doorKnockConfirmation = DoorKnockConfirmation();
  int _captureGeneration = 0;

  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<Uint8List>? _pcmSub;

  /// The session wants sound. Cleared by [stop] *before* teardown so any
  /// end-of-stream callback raised by that teardown cannot restart us.
  bool _wantCapture = false;
  bool get isRunning => _wantCapture;

  /// Sliding PCM history: newest samples appended at the end.
  final List<double> _buf = <double>[];

  /// New samples required between classification attempts (0.5 s) — fast
  /// enough that a bubble lands while the sound is still happening.
  static const int _hopSamples = 8000;

  /// Window peak below this is treated as silence: no window, no guess.
  /// Guards CPU on a quiet screen (prd.md > quiet session state).
  static const double _silencePeak = 0.03;

  int _sinceHop = 0;

  // --- Liveness: catch a stream the platform ended without telling us ---
  DateTime _lastPcm = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdog;
  bool _reopening = false;
  int _reopenAttempts = 0;

  /// No PCM for this long means the stream really is gone, not merely quiet.
  /// Comfortably above `record`'s normal ~100 ms chunk cadence.
  static const Duration _staleAfter = Duration(seconds: 3);

  Future<bool> start() async {
    if (_wantCapture) return true;
    _captureGeneration++;
    _doorKnockConfirmation.reset();
    if (!await _recorder.hasPermission()) return false;

    // The model is a bundled asset: this is a local load, never a download.
    // Failure is survivable — sounds then resolve honestly to unknown.
    await classifier.load();

    _wantCapture = true;
    _reopenAttempts = 0;
    if (!await _open()) {
      _wantCapture = false;
      return false;
    }
    _watchdog ??= Timer.periodic(const Duration(seconds: 2), (_) => _checkLiveness());
    return true;
  }

  /// Opens both platform streams. Safe to call again after a teardown.
  Future<bool> _open() async {
    try {
      final pcm = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000, // YAMNet's expected input rate (spec.md > Stack)
          numChannels: 1,
        ),
      );
      _buf.clear();
      _sinceHop = 0;
      _lastPcm = DateTime.now();

      // Level stream drives the pulse's strength/onset/rhythm.
      _ampSub = _recorder.onAmplitudeChanged(
        const Duration(milliseconds: 100),
      ).listen(
        (amp) {
          // record reports dBFS in [-160, 0]; map to 0..1 for the controller.
          final db = amp.current;
          final level = ((db + 60) / 60).clamp(0.0, 1.0);
          _session.onLevel(level.toDouble());
        },
        onDone: () => _streamGone('level stream ended'),
        onError: (Object e) => _streamGone('level stream error: $e'),
        cancelOnError: false,
      );

      // PCM stream feeds YAMNet: int16 LE -> [-1.0, 1.0] sliding window.
      _pcmSub = pcm.listen(
        _onPcm,
        onDone: () => _streamGone('pcm stream ended'),
        onError: (Object e) => _streamGone('pcm stream error: $e'),
        cancelOnError: false,
      );

      debugPrint('CAP opened (pcm + level)');
      return true;
    } catch (e) {
      debugPrint('CAP open failed: $e');
      return false;
    }
  }

  /// The watchdog's question: has real audio actually arrived lately?
  void _checkLiveness() {
    if (!_wantCapture || _reopening) return;
    if (DateTime.now().difference(_lastPcm) < _staleAfter) return;
    _streamGone('no pcm for ${_staleAfter.inSeconds}s');
  }

  /// A stream ended, errored, or went stale: say so, then reopen with backoff
  /// while the session still wants sound.
  Future<void> _streamGone(String detail) async {
    if (!_wantCapture || _reopening) return;
    _reopening = true;
    _reopenAttempts++;

    // Backoff so a permanently-failing microphone logs slowly instead of
    // spinning; capped so a transient hiccup recovers quickly.
    final shift = _reopenAttempts > 4 ? 4 : _reopenAttempts - 1;
    final delayMs = (500 << shift).clamp(500, 8000);
    debugPrint('CAP $detail; reopening in ${delayMs}ms '
        '(attempt $_reopenAttempts)');

    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (!_wantCapture) {
      _reopening = false;
      return;
    }

    await _teardown();
    final ok = await _open();
    _reopening = false;
    if (!ok && _wantCapture) {
      // Loop back through the same guarded path (backoff grows each time).
      await _streamGone('reopen failed');
    }
  }

  Future<void> _teardown() async {
    final amp = _ampSub;
    final pcm = _pcmSub;
    _ampSub = null;
    _pcmSub = null;
    await amp?.cancel();
    await pcm?.cancel();
    _buf.clear();
    _sinceHop = 0;
    try {
      await _recorder.stop();
    } catch (e) {
      // Already stopped by the platform — nothing to salvage, not fatal.
      debugPrint('CAP stop: $e');
    }
  }

  void _onPcm(Uint8List chunk) {
    if (_reopenAttempts != 0) {
      debugPrint('CAP recovered after $_reopenAttempts reopen attempt(s)');
      _reopenAttempts = 0;
    }
    _lastPcm = DateTime.now();

    final units = chunk.length ~/ 2;
    for (var i = 0; i < units; i++) {
      final raw = chunk[i * 2] | (chunk[i * 2 + 1] << 8);
      final signed = raw >= 0x8000 ? raw - 0x10000 : raw;
      _buf.add(signed / 32768.0);
    }
    _sinceHop += units;

    final need = YamnetClassifier.windowSamples;
    if (_buf.length < need || _sinceHop < _hopSamples) return;
    _sinceHop = 0;

    // Take the newest full window, then keep only it for the next hop.
    final window = Float32List.fromList(
      _buf.sublist(_buf.length - need),
    );
    if (_buf.length > need) {
      _buf.removeRange(0, _buf.length - need);
    }

    var peak = 0.0;
    for (final v in window) {
      final a = v < 0 ? -v : v;
      if (a > peak) peak = a;
    }
    if (peak < _silencePeak) return; // digital-ish silence: nothing to name

    _nameWindow(window, peak, _captureGeneration);
  }

  Future<void> _nameWindow(
    Float32List window,
    double peak,
    int generation,
  ) async {
    // One inference per window; the guesses come straight from its scores.
    final scores = await classifier.scores(window);
    if (generation != _captureGeneration) return;
    if (!_wantCapture || scores == null) {
      _doorKnockConfirmation.reset();
      return; // a skipped inference is not an unknown sound
    }
    final guesses = guessesFromScores(scores).toList();
    final knockGuess = _doorKnockConfirmation.addScores(scores);
    if (knockGuess != null &&
        !guesses.any((guess) => guess.category == SoundCategory.door)) {
      guesses.removeWhere((guess) => guess.category == SoundCategory.unknown);
      guesses.add(knockGuess);
    }

    debugPrint(classifier.diagnosticSummary(scores));

    // dBFS -> the same 0..1 scale the pulse uses, so a bubble's red/orange
    // means exactly what the pulse's red/orange means (prd.md > proximity).
    final db = peak <= 1e-4 ? -80.0 : 20.0 * math.log(peak) / math.ln10;
    final strength = ((db + 60) / 60).clamp(0.0, 1.0);

    for (final g in guesses) {
      _session.onSound(g.category, g.confidence, strength.toDouble());
    }
    debugPrint(
      'CLS ${guesses.map((g) => g.category.name).join('+')} '
      'conf=${guesses.first.confidence.toStringAsFixed(2)} '
      'lvl=${strength.toStringAsFixed(2)}',
    );
  }

  Future<void> stop() async {
    // Stop wanting sound first: teardown raises end-of-stream callbacks, and
    // those must not schedule a reopen.
    _wantCapture = false;
    _captureGeneration++;
    _doorKnockConfirmation.reset();
    _watchdog?.cancel();
    _watchdog = null;
    _session.onLevel(0);
    await _teardown();
  }

  void dispose() {
    _wantCapture = false;
    _captureGeneration++;
    _doorKnockConfirmation.reset();
    _watchdog?.cancel();
    _watchdog = null;
    _ampSub?.cancel();
    _pcmSub?.cancel();
    classifier.dispose();
    _recorder.dispose();
  }
}
