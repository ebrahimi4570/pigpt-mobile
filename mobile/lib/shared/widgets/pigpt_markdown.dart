import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme.dart';

class PigptMarkdown extends StatelessWidget {
  const PigptMarkdown({
    super.key,
    required this.data,
    this.streaming = false,
    this.codeBlocks = true,
  });
  final String data;
  final bool streaming;
  final bool codeBlocks;

  @override
  Widget build(BuildContext context) {
    final source = streaming && data.isNotEmpty ? '$data▍' : data;
    if (source.isEmpty) return const SizedBox.shrink();
    return MarkdownBody(
      data: source,
      selectable: true,
      shrinkWrap: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: codeBlocks ? {'pre': _CodeBlockBuilder()} : const {},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
        strong: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          backgroundColor: PigptColors.codeBg(context),
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    return _CopyableCode(code: code);
  }
}

class _CopyableCode extends StatelessWidget {
  const _CopyableCode({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final dark = PigptColors.isDark(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 8),
      decoration: BoxDecoration(
        color: PigptColors.codeBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PigptColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'کپی بلوک',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                HapticFeedback.selectionClick();
              },
              icon: Icon(
                Icons.copy_rounded,
                size: 16,
                color: dark ? PigptColors.inkMuted : PigptColors.lightMuted,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              code.trimRight(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
                color: dark ? PigptColors.ink : PigptColors.lightInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
