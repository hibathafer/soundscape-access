import 'package:flutter/material.dart';

import '../audio/capture.dart';
import '../audio/permission.dart' as mic;
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

  @override
  void initState() {
    super.initState();
    _capture = AudioCapture(_session);
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
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
      await _capture.stop();
      _session.stop();
    } else {
      if (await _ensurePermission()) {
        final started = await _capture.start();
        if (started) {
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
