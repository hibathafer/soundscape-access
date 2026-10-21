import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analyze/behavior.dart';
import '../theme.dart';

/// The kernel — prd.md > Sound pulse (the visual vocabulary).
///
/// Rendered as **soft mist**, not defined shapes (learner's review note:
/// "خفيف مثل ضباب... مو شكل معين وواضح"):
///
///  1. **The living mist** — a center lobe plus three offset lobes, all
///     heavily blurred, so it reads as a soft cloud of light rather than a
///     circle. Its brightness and size follow the sound's strength directly,
///     so it is visible the moment a sound is present.
///  2. **The strike wave** — a soft ring of mist rolling outward on every
///     ignition and re-strike. This is what makes rhythm visible: a
///     repeating sound sends a new wave with each beat.
///
/// Color follows loudness (red very loud / orange moderate / a quiet neutral
/// when we cannot yet tell). When the sound ends, everything fades to calm.
///
/// No direction is claimed. Six logged probe runs on the physical device
/// (probe_log*.txt; rounds 3-6 in spec.md > Decisions and Open Issues) found
/// no usable bearing: the left/right axis produced the same sign on both
/// ends, and the "no difference" control came out *larger* than the two ends
/// it was supposed to sit between. What we show is what we can honestly
/// measure.
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

  /// Increments on each strike; a change fires the outward wave.
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
      // The sound ended — the wave rolls out and dies.
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
        // Rebuilds while the wave animates AND whenever the parent rebuilds
        // with a new live strength (the builder reads widget.strength, so the
        // mist tracks the sound in real time).
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(
            progress: _c.value,
            strength: widget.strength,
            onset: widget.onset,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.progress,
    required this.strength,
    required this.onset,
  });

  /// The strike wave phase: 0 idle .. 1 fully rolled out.
  final double progress;

  /// Live loudness — the mist's brightness, size, and color follow this
  /// directly, independent of the animation.
  final double strength;

  final Onset onset;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 && progress <= 0) return;

    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final eased = Curves.easeOutCubic.transform(progress);
    final color = proximityColor(strength);

    // A gentle swell while a sudden strike lands — the mist breathes.
    final flare = onset == Onset.sudden ? (0.9 + 0.1 * eased) : 1.0;
    final cloudR = maxR * (0.34 + 0.66 * strength) * flare;

    // --- Layer 1: the living mist (follows strength directly) ---
    // On a light canvas mist behaves like watercolour: it *adds* a tint
    // rather than emitting light. Low alpha over near-white is invisible,
    // so every lobe gets a floor — a faint sound still leaves a visible
    // wash, and louder sounds deepen toward the full proximity color.
    _mist(canvas, color, center, cloudR, 0.30 + 0.55 * strength, 26);
    for (final deg in const [90.0, 210.0, 330.0]) {
      final dir = Offset.fromDirection(deg * math.pi / 180);
      _mist(
        canvas,
        color,
        center + dir * (cloudR * 0.34),
        cloudR * 0.70,
        0.18 + 0.32 * strength,
        30,
      );
    }

    // --- Layer 2: the strike wave (the rhythm flourish) ---
    // A soft band of mist rolling outward; only while the wave animates.
    if (progress > 0 && progress < 1) {
      final waveR = cloudR * (1.05 + 0.6 * eased);
      final waveAlpha = (1 - eased) * (0.35 + 0.5 * strength);
      final shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.9 * waveAlpha),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.55, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: waveR));
      final paint = Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, waveR, paint);
    }
  }

  /// One blurred lobe of mist — the building block of the cloud.
  void _mist(
    Canvas canvas,
    Color color,
    Offset center,
    double radius,
    double alpha,
    double blur,
  ) {
    if (alpha <= 0.01 || radius <= 0) return;
    final shader = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha * 0.45),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()
      ..shader = shader
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress ||
      old.strength != strength ||
      old.onset != onset;
}
