import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Transparent field chrome so the textarea is not a second box inside the
/// composer. Theme `InputDecorationTheme.filled` would otherwise paint a
/// different background (scaffold `bg`) and look like the input sits outside.
InputDecoration pigptComposerFieldDecoration({
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    filled: false,
    fillColor: Colors.transparent,
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
  );
}

/// Cursor-style composer: one bordered surface; textarea + toolbar inside.
class PigptComposer extends StatelessWidget {
  const PigptComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.onStop,
    this.onAttach,
    this.onMic,
    this.onSubmitted,
    this.listening = false,
    this.micBusy = false,
    this.showMic = false,
    this.streaming = false,
    this.enabled = true,
    this.showRing = false,
    this.fill = 0,
    this.usedTokens = 0,
    this.capTokens = 0,
    this.minLines = 1,
    this.maxLines = 5,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final VoidCallback? onAttach;
  final VoidCallback? onMic;
  final VoidCallback? onSubmitted;
  final bool listening;
  final bool micBusy;
  final bool showMic;
  final bool streaming;
  final bool enabled;
  final bool showRing;
  final double fill;
  final int usedTokens;
  final int capTokens;
  final int minLines;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final surface = PigptColors.surfaceOf(context);
    final border = PigptColors.borderOf(context);

    return Material(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: minLines,
              maxLines: maxLines,
              enabled: enabled && !streaming,
              textInputAction: TextInputAction.newline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    fontSize: 14.5,
                  ),
              cursorColor: Theme.of(context).colorScheme.primary,
              decoration: pigptComposerFieldDecoration(hint: hint),
              onSubmitted: (_) {
                if (!enabled || streaming) return;
                onSubmitted?.call();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 6, 6),
              child: Row(
                children: [
                  if (onAttach != null)
                    _ComposerIconButton(
                      tooltip: 'پیوست فایل یا تصویر',
                      onPressed: streaming ? null : onAttach,
                      icon: Icons.attach_file_rounded,
                    ),
                  const Spacer(),
                  if (showMic)
                    _ComposerIconButton(
                      tooltip: listening ? 'توقف ضبط' : 'ورودی صوتی',
                      onPressed: streaming || micBusy ? null : onMic,
                      icon: listening
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none_rounded,
                      color: listening ? PigptColors.danger : null,
                    ),
                  _ComposerSendButton(
                    streaming: streaming,
                    enabled: enabled,
                    onStop: onStop,
                    onSend: onSend,
                  ),
                  if (showRing) ...[
                    const SizedBox(width: 6),
                    ComposerVolumeRing(
                      fill: fill,
                      usedTokens: usedTokens,
                      capTokens: capTokens,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = PigptColors.mutedOf(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          iconSize: 16,
          icon: Icon(icon, size: 16, color: color ?? muted),
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.streaming,
    required this.enabled,
    required this.onSend,
    this.onStop,
  });

  final bool streaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = streaming || enabled;
    return Tooltip(
      message: streaming ? 'توقف' : 'ارسال',
      child: SizedBox(
        width: 28,
        height: 28,
        child: Material(
          color: active ? cs.primary : PigptColors.faintOf(context),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: streaming
                ? onStop
                : (enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onSend();
                      }
                    : null),
            child: Icon(
              streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              size: 15,
              color: cs.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class ComposerVolumeRing extends StatelessWidget {
  const ComposerVolumeRing({
    super.key,
    required this.fill,
    required this.usedTokens,
    required this.capTokens,
  });

  final double fill;
  final int usedTokens;
  final int capTokens;

  @override
  Widget build(BuildContext context) {
    final p = fill.clamp(0.0, 1.0);
    final hot = p >= 0.85;
    final pct = (p * 100).round();
    return Tooltip(
      message: 'حجم این گفتگو $pct٪ · حدود $usedTokens از $capTokens توکن',
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          value: p,
          strokeWidth: 2.2,
          backgroundColor: PigptColors.borderOf(context),
          color: hot ? const Color(0xFFF59E0B) : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
