import 'package:flutter/material.dart';

import '../classify/categories.dart';
import '../session/controller.dart';
import '../theme.dart';

/// One floating, swipeable bubble per prd.md > Sound-type bubbles: a plain
/// picture naming the sound type — no circle, no ring, no shadow, because
/// those made it read as a button and it is not one. The picture's size
/// carries loudness (closer is larger), a neutral "?" when the type is
/// unknown, and a downward swipe to dismiss. The layer sits above the pulse
/// inside the live area.
class BubblesLayer extends StatelessWidget {
  const BubblesLayer({super.key, required this.bubbles, required this.onDismiss});

  final List<SoundBubble> bubbles;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (bubbles.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final b in bubbles)
            _BubbleView(bubble: b, onDismiss: onDismiss),
        ],
      ),
    );
  }
}

/// The swipe-down gesture lives on a single bubble. The drag is tracked
/// locally so the bubble follows the finger before it commits to dismissal.
class _BubbleView extends StatefulWidget {
  const _BubbleView({required this.bubble, required this.onDismiss});

  final SoundBubble bubble;
  final ValueChanged<int> onDismiss;

  @override
  State<_BubbleView> createState() => _BubbleViewState();
}

class _BubbleViewState extends State<_BubbleView> {
  double _dragY = 0.0;

  static const double _commitDistance = 64;

  @override
  Widget build(BuildContext context) {
    final b = widget.bubble;
    final unknown = b.category == SoundCategory.unknown;

    // The circle, ring, shadow and colour wash are gone: all four were what
    // made this read as a *button*, and it is not one. What is left is the
    // picture.
    //
    // Loudness still has to travel somehow (prd.md > Look and Feel: close is
    // red, farther is orange), and the ring was its only carrier — so the
    // shape carries it now. This is a Transform, not a width change, so the
    // Wrap never re-lays-out: the picture grows inside a fixed 72px box and
    // nothing jumps.
    final double scale =
        unknown ? 1.0 : 0.75 + 0.25 * b.strength.clamp(0.0, 1.0);

    return GestureDetector(
      onVerticalDragUpdate: (d) => setState(() => _dragY += d.delta.dy),
      onVerticalDragEnd: (_) {
        if (_dragY >= _commitDistance) {
          widget.onDismiss(b.id);
        } else {
          setState(() => _dragY = 0.0);
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _dragY > _commitDistance ? 0.0 : 1.0,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: _glyph(b.category, unknown),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The picture, and nothing else.
  ///
  /// Prefers `assets/icons/<category>.png`. Until that file exists the
  /// Material glyph stands in, so a missing image degrades to a recognisable
  /// symbol rather than a blank hole in the row.
  Widget _glyph(SoundCategory cat, bool unknown) {
    return Image.asset(
      'assets/icons/${cat.name}.png',
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => unknown
          ? const Text(
              '?',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: SoundscapeColors.ink,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          : Icon(_iconFor(cat), size: 52, color: SoundscapeColors.ink),
    );
  }
}

IconData _iconFor(SoundCategory cat) => switch (cat) {
      SoundCategory.cars => Icons.directions_car,
      SoundCategory.speech => Icons.record_voice_over,
      SoundCategory.door => Icons.meeting_room,
      SoundCategory.alarm => Icons.notifications_active,
      SoundCategory.birds => Icons.emoji_nature,
      SoundCategory.unknown => Icons.help_outline,
    };
