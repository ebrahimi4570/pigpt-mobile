import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';

/// Public `/share/:token` viewer (read-only).
class ShareViewerScreen extends ConsumerStatefulWidget {
  const ShareViewerScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<ShareViewerScreen> createState() => _ShareViewerScreenState();
}

class _ShareViewerScreenState extends ConsumerState<ShareViewerScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.sharePublic(widget.token),
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final kind = '${d?['kind'] ?? ''}';
    final title = '${d?['title'] ?? d?['title_fa'] ?? 'اشتراک عمومی'}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const ListShimmer()
          : _error != null
              ? EmptyState(title: 'لینک در دسترس نیست', body: _error)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Row(
                        children: [
                          const PigptMark(size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                  kind.isEmpty
                                      ? 'فقط‌خواندنی'
                                      : '$kind · فقط‌خواندنی',
                                  style: const TextStyle(
                                      color: PigptColors.inkMuted,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (kind == 'conversation')
                      ..._messages(d?['messages'])
                    else if (d?['payload'] != null)
                      SoftCard(
                        child: MarkdownBody(
                          data: '${d!['payload']}',
                          selectable: true,
                        ),
                      )
                    else
                      SoftCard(
                        child: SelectableText('${d ?? ''}'),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      PigptBrand.readyWith,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: PigptColors.inkFaint, fontSize: 12),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _messages(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return [
        const EmptyState(
          title: 'پیامی نیست',
          body: 'این اشتراک خالی است.',
        ),
      ];
    }
    return raw.map<Widget>((m) {
      final map = m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
      final role = '${map['role'] ?? ''}';
      final content = '${map['content'] ?? map['text'] ?? ''}';
      return SoftCard(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role == 'user' ? 'کاربر' : PigptBrand.webDisplay,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: PigptColors.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            MarkdownBody(data: content, selectable: true),
          ],
        ),
      );
    }).toList();
  }
}
