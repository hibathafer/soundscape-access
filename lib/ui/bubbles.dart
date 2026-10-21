import 'package:flutter/material.dart';

import '../classify/categories.dart';
import '../session/controller.dart';
import '../theme.dart';

/// One floating, swipeable bubble per prd.md > Sound-type bubbles:
/// an icon naming the sound type, colored by loudness (red close / orange
/// farther), a neutral "?" when the type is unknown, and a downward swipe to
/// dismiss. The layer sits above the pulse inside the live area.
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

    // Known sounds ride the loudness scale; unknown stays a quiet neutral so
    // it never reads as "close" or "far" (prd.md > Look and Feel colors).
    // On the light canvas that neutral has to be a real ink-like gray, or
    // the "?" would be white-on-white.
    final color =
        unknown ? SoundscapeColors.unknownGray : proximityColor(b.strength);

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
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              // A faint wash of the same color keeps the bubble readable
              // against a white card; the ring carries the loudness.
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: SoundscapeColors.ink.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: unknown
                ? const Center(
                    child: Text(
                      '?',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: SoundscapeColors.unknownGray,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Icon(_iconFor(b.category), color: color, size: 36),
          ),
        ),
      ),
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
