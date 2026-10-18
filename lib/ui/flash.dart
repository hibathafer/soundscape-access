import 'package:flutter/material.dart';

import '../analyze/behavior.dart';
import '../theme.dart';

/// The kernel — prd.md > Sound pulse (the visual vocabulary).
///
/// The pulse ignites at the center with every strike and expands outward:
/// brightness/size follow the sound's strength, color follows loudness
/// (red very loud / orange moderate), a sudden onset strikes fast while a
/// gradual one fades in, and a repeating sound visibly re-strikes the pulse
/// and its expanding ring with each beat. When the sound ends, it fades out.
///
/// No direction is claimed — four documented rounds of device research
/// proved the platform gives apps one mixed signal (spec.md > Decisions
/// and Open Issues). What we show is what we can honestly measure.
class SoundPulse extends StatefulWidget {
  const SoundPulse({
    super.key,
    required this.strength,
    required this.onset,
    required this.rhythm,
    required this.strike,
  });

  /// Live loudness, 0.0 silent .. 1.0 very loud.
  final double strength;
  final Onset onset;
  final Rhythm rhythm;

  /// Increments on each strike; a change re-ignites the pulse.
  final int strike;

  @override
  State<SoundPulse> createState() => _SoundPulseState();
}

class _SoundPulseState extends State<SoundPulse>
    with SingleTickerProviderStateMixin {
  static const _attackSudden = Duration(milliseconds: 90);
  static const _attackGradual = Duration(milliseconds: 320);
  static const _fadeOut = Duration(milliseconds: 450);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _attackGradual,
  );

  @override
  void didUpdateWidget(SoundPulse old) {
    super.didUpdateWidget(old);
    if (widget.strike != old.strike) {
      // Ignition / re-strike: fast for bangs, soft for gradual sounds.
      _c.duration =
          widget.onset == Onset.sudden ? _attackSudden : _attackGradual;
      _c.forward(from: 0);
    } else if (widget.strength <= 0 && old.strength > 0) {
      // The sound ended — fade to calm (prd.md > Sound pulse).
      _c.duration = _fadeOut;
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(
            progress: _c.value,
            strength: widget.strength,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.strength});

  /// Attack/fade phase: 0 quiet .. 1 fully struck.
  final double progress;

  /// Live loudness — brightness and color follow it.
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final eased = Curves.easeOutCubic.transform(progress);
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final color = proximityColor(strength);

    // The glow: bigger and brighter for stronger sounds.
    final radius = maxR * (0.3 + 0.7 * strength) * (0.35 + 0.65 * eased);
    final alpha = (strength * eased).clamp(0.0, 1.0);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.75 * alpha),
          color.withValues(alpha: 0.12 * alpha),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    // The strike ring — travels outward and dies; every repeat re-strikes it,
    // which is how rhythm becomes visible (prd.md > Sound pulse).
    final ringAlpha = (1 - eased) * alpha;
    if (ringAlpha > 0.02) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + 2.5 * strength
        ..color = color.withValues(alpha: 0.5 * ringAlpha);
      canvas.drawCircle(center, radius * (1 + 0.35 * eased), ring);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress || old.strength != strength;
}
