import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/capture.dart';
import '../audio/permission.dart' as mic;
import '../direction/probe.dart';
import '../session/controller.dart';
import '../session/vibration_service.dart';
import '../theme.dart';

/// The one and only screen — prd.md > Screens and Layout.
/// Large Start/Stop at the center, small vibration toggle, live area beneath.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _session = SessionController();
  final _vibration = VibrationService();
  late final AudioCapture _capture;

  bool _permissionExplained = false;
  bool _permissionBlocked = false;
  bool _busy = false;

  // Slice-2 direction research probe (temporary debug panel).
  final _probe = MicProbeStream();
  Map<String, double> _probeLevels = const {};
  bool _probeRunning = false;

  @override
  void initState() {
    super.initState();
    _capture = AudioCapture(_session);
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _probe.stop();
    _capture.stop();
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (_session.events.isNotEmpty) {
      _vibration.buzzOnEvent(_session.vibrationEnabled);
    }
    setState(() {});
  }

  // --- Permission flow: gentle line -> system dialog -> friendly denial ---
  Future<bool> _ensurePermission() async {
    if (await mic.MicPermission.isGranted()) return true;
    if (!mounted) return false;

    if (!_permissionExplained) {
      _permissionExplained = true;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SoundscapeColors.surface,
          title: const Text('A quick note first'),
          content: const Text(
            'To know the sounds around you, this app listens with your '
            'microphone while a session is on. Nothing is recorded or sent '
            'anywhere — it all stays on your phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (go != true) return false;
    }

    final result = await mic.MicPermission.request();
    if (result == mic.PermissionResult.granted) return true;

    if (!mounted) return false;
    setState(() => _permissionBlocked =
        result == mic.PermissionResult.permanentlyDenied);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result == mic.PermissionResult.permanentlyDenied
            ? 'The microphone is blocked for this app. You can allow it in '
                'Settings — tap the message for a hand.'
            : 'No worries — the app stays quiet until the microphone is '
                'allowed.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: mic.MicPermission.openSettings,
        ),
      ));
    return false;
  }

  // --- Start / Stop ---
  Future<void> _toggleSession() async {
    if (_busy) return;
    setState(() => _busy = true);

    if (_session.sessionActive) {
      await _probe.stop();
      setState(() {
        _probeRunning = false;
        _probeLevels = const {};
      });
      await _capture.stop();
      _session.stop();
    } else {
      if (await _ensurePermission()) {
        final started = await _capture.start();
        if (started) {
          // Slice-2 research probe: runs alongside the session.
          final probeOk = await _probe.start((levels) {
            // Slice-2 evidence trail: timestamped levels for adb logcat.
            final pairs = levels.entries
                .map((e) => '${e.key}=${e.value.toStringAsFixed(1)}')
                .join(' ');
            debugPrint('PROBE $pairs');
            if (mounted) setState(() => _probeLevels = levels);
          });
          if (mounted) setState(() => _probeRunning = probeOk);
          _session.start();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Working now')),
            );
          }
        }
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Temporary research panel: live dB per mic source + the spread.
  /// Round 2: adds vrec / unprocessed / stereo channels — any signal that
  /// might carry direction after round 1 showed MIC+CAMCORDER are mixed.
  Widget _buildProbePanel() {
    const order = ['micA', 'micB', 'uL', 'uR', 'top', 'bottom', 'stL', 'stR', 'vrec', 'unproc'];
    final present = order.where((k) => _probeLevels.containsKey(k)).toList();

    double norm(double? db) => (((db ?? -160) + 80) / 80).clamp(0.0, 1.0);

    // Spread = max - min among live sources (the direction opportunity).
    String verdict;
    if (present.length < 2) {
      verdict = 'Need at least two sources…';
    } else {
      final vals = present.map((k) => _probeLevels[k]!);
      final spread = vals.reduce(math.max) - vals.reduce(math.min);
      if (spread >= 5) {
        verdict =
            'SPREAD ${spread.toStringAsFixed(1)} dB — sources differ! Direction may be possible.';
      } else if (spread >= 2.5) {
        verdict =
            'Spread ${spread.toStringAsFixed(1)} dB — weak. Needs strong near-field sound to judge.';
      } else {
        verdict =
            'Spread ${spread.toStringAsFixed(1)} dB — sources nearly identical.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16212E),
        border: Border.all(color: const Color(0xFF2B3B4E)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Direction probe r2 (research)',
              style: TextStyle(
                  color: SoundscapeColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          for (final k in present) ...[
            _probeBar(k, norm(_probeLevels[k]), _probeLevels[k]),
            const SizedBox(height: 6),
          ],
          Text(verdict,
              style:
                  const TextStyle(color: SoundscapeColors.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _probeBar(String label, double value, double? db) {
    return Row(
      children: [
        SizedBox(
            width: 58,
            child: Text(label,
                style:
                    const TextStyle(color: SoundscapeColors.muted, fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: const Color(0xFF0F1720),
              valueColor: AlwaysStoppedAnimation(
                  label == 'bottom'
                      ? SoundscapeColors.farOrange
                      : SoundscapeColors.accent),
            ),
          ),
        ),
        SizedBox(
            width: 66,
            child: Text(
                db == null ? '--' : '${db.toStringAsFixed(1)} dB',
                textAlign: TextAlign.right,
                style:
                    const TextStyle(color: SoundscapeColors.muted, fontSize: 13))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _session.sessionActive;
    final level = _session.currentLevel;

    return Scaffold(
      backgroundColor: SoundscapeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Soundscape Access',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: SoundscapeColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            // Live area: slice 3 fills it with the directional flash.
            Expanded(
              child: Center(
                child: active
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 160 + 200 * level,
                            height: 160 + 200 * level,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: proximityColor(level).withValues(
                                alpha: (0.15 + 0.6 * level).clamp(0.0, 1.0)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Listening… level ${(level * 100).round()}%',
                            style: const TextStyle(
                                color: SoundscapeColors.muted, fontSize: 15),
                          ),
                          const SizedBox(height: 14),
                          // Slice-2 research readout (temporary debug panel).
                          if (_probeRunning) _buildProbePanel(),
                        ],
                      )
                    : Text(
                        _permissionBlocked
                            ? 'The microphone is blocked — allow it in '
                                'Settings to start.'
                            : 'Press Start when you are ready.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: SoundscapeColors.muted, fontSize: 16),
                      ),
              ),
            ),
            // Vibration toggle (manual, simple — prd.md > Vibration).
            SwitchListTile.adaptive(
              value: _session.vibrationEnabled,
              onChanged: active
                  ? (v) => _session.setVibration(v)
                  : null,
              title: const Text(
                'Vibrate on sounds',
                style: TextStyle(color: SoundscapeColors.ink),
              ),
              activeThumbColor: SoundscapeColors.accent,
            ),
            const SizedBox(height: 4),
            // Big Start/Stop.
            Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: SizedBox(
                width: 220,
                height: 68,
                child: FilledButton(
                  onPressed: _busy ? null : _toggleSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: active
                        ? SoundscapeColors.closeRed
                        : SoundscapeColors.accent,
                    foregroundColor: const Color(0xFF06231F),
                    textStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(34)),
                  ),
                  child: Text(active ? 'Stop' : 'Start'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
