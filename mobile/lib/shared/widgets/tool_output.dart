import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import 'fullscreen_image.dart';
import 'pigpt_markdown.dart';

/// Structured agent/studio tool output — never [Map.toString].
class ToolOutputView extends StatelessWidget {
  const ToolOutputView({super.key, required this.data});
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final blocks = _flatten(data);
    if (blocks.isEmpty) {
      return Text(
        'خروجی خالی',
        style: TextStyle(color: PigptColors.mutedOf(context), fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) ...[
          b,
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<Widget> _flatten(dynamic raw, {String? label}) {
    if (raw == null) return const [];
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty || t == '{}' || t == 'null') return const [];
      if (_isUrl(t) && _isImage(t)) {
        return [_image(t, caption: label)];
      }
      if (_isUrl(t)) {
        return [_link(t, label: label)];
      }
      return [
        if (label != null) _label(label),
        PigptMarkdown(data: t),
      ];
    }
    if (raw is num || raw is bool) {
      return [
        if (label != null) _label(label),
        SelectableText('$raw'),
      ];
    }
    if (raw is List) {
      final out = <Widget>[];
      if (label != null) out.add(_label(label));
      for (final item in raw) {
        out.addAll(_flatten(item));
      }
      return out;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final out = <Widget>[];
      final text = '${map['text'] ?? map['content'] ?? map['output'] ?? map['result'] ?? map['markdown'] ?? ''}';
      final url = '${map['url'] ?? map['image_url'] ?? map['preview_url'] ?? ''}';
      final files = map['files'] ?? map['file'] ?? map['attachments'];
      final images = map['images'] ?? map['image'];
      if (label != null) out.add(_label(label));
      if (url.isNotEmpty && url != 'null') {
        out.addAll(_flatten(url));
      }
      if (text.isNotEmpty && text != 'null') {
        out.add(PigptMarkdown(data: text));
      }
      if (files != null) out.addAll(_flatten(files, label: 'فایل‌ها'));
      if (images != null) out.addAll(_flatten(images, label: 'تصاویر'));
      for (final e in map.entries) {
        final k = e.key;
        if ({
          'text',
          'content',
          'output',
          'result',
          'markdown',
          'url',
          'image_url',
          'preview_url',
          'files',
          'file',
          'attachments',
          'images',
          'image',
        }.contains(k)) {
          continue;
        }
        out.addAll(_flatten(e.value, label: k));
      }
      return out;
    }
    return [SelectableText('$raw')];
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );

  Widget _image(String url, {String? caption}) {
    final abs = url.startsWith('http') ? url : '${PigptBrand.apiBase}$url';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null) _label(caption),
        TappableImage(
          url: abs,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(abs, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _link(String url, {String? label}) {
    return Row(
      children: [
        if (label != null) ...[
          _label(label),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SelectableText(
            url,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: 'کپی',
          onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          icon: const Icon(Icons.copy_rounded, size: 16),
        ),
      ],
    );
  }

  bool _isUrl(String s) =>
      s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('/api/') ||
      s.startsWith('/uploads/') ||
      s.startsWith('/assets/');

  bool _isImage(String s) {
    final l = s.toLowerCase();
    return l.contains('/uploads/') ||
        l.contains('/assets/') ||
        l.endsWith('.png') ||
        l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.webp') ||
        l.endsWith('.gif');
  }
}
