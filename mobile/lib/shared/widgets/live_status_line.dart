import 'package:flutter/material.dart';

import '../../core/live_status.dart';
import '../../core/theme.dart';

/// Single in-place status line. Cursor-like: no toast, no second chrome bar.
class LiveStatusLine extends StatelessWidget {
  const LiveStatusLine({
    super.key,
    required this.status,
    this.compact = false,
    this.reserveSlot = false,
  });

  final LiveStatus status;
  final bool compact;
  /// Keep a fixed height when idle so the composer dock does not jump.
  final bool reserveSlot;

  @override
  Widget build(BuildContext context) {
    if (status.isIdle || status.label.isEmpty) {
      if (reserveSlot) {
        return SizedBox(height: compact ? 18 : 22);
      }
      return const SizedBox.shrink();
    }
    final danger = status.phase == LivePhase.error;
    final active = status.isActive;
    final color = danger
        ? PigptColors.danger
        : PigptColors.faintOf(context).withValues(alpha: 0.92);
    final style = TextStyle(
      fontSize: compact ? 12 : 12.5,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: color,
    );
    return SizedBox(
      height: compact ? 18 : 22,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        child: Row(
          children: [
            if (active) ...[
              _PulseDot(color: PigptColors.brand.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: active
                  ? _ShimmerStatusText(
                      text: status.label,
                      style: style,
                      base: color,
                      shine: PigptColors.inkOf(context).withValues(alpha: 0.55),
                    )
                  : Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: style,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerStatusText extends StatefulWidget {
  const _ShimmerStatusText({
    required this.text,
    required this.style,
    required this.base,
    required this.shine,
  });

  final String text;
  final TextStyle style;
  final Color base;
  final Color shine;

  @override
  State<_ShimmerStatusText> createState() => _ShimmerStatusTextState();
}

class _ShimmerStatusTextState extends State<_ShimmerStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final label = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: widget.style.copyWith(color: Colors.white),
    );
    if (reduce) {
      return Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: widget.style,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final w = bounds.width <= 0 ? 1.0 : bounds.width;
            final slide = w * (1.2 - 2.4 * _c.value);
            return LinearGradient(
              colors: [
                widget.base,
                widget.base,
                widget.shine,
                widget.base,
                widget.base,
              ],
              stops: const [0.0, 0.36, 0.5, 0.64, 1.0],
              transform: _SlideGradient(slide),
            ).createShader(Rect.fromLTWH(-w, 0, w * 3, bounds.height));
          },
          child: child,
        );
      },
      child: label,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.28, end: 0.7).animate(_c),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
