import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../features/chat/chat_providers.dart';

/// Lightweight command-palette equivalent: find chats + jump to key features.
Future<void> showPigptCommandPalette(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _CommandPaletteSheet(),
  );
}

class _CommandPaletteSheet extends ConsumerStatefulWidget {
  const _CommandPaletteSheet();

  @override
  ConsumerState<_CommandPaletteSheet> createState() =>
      _CommandPaletteSheetState();
}

class _CommandPaletteSheetState extends ConsumerState<_CommandPaletteSheet> {
  final _q = TextEditingController();
  String _query = '';

  static const _features = <(String, String, IconData)>[
    ('گفتگوی جدید', '/chat', Icons.edit_square),
    ('تاریخچه', '/chat/history', Icons.history_rounded),
    ('شروع سریع', '/quick-start', Icons.bolt_outlined),
    ('استودیوها', '/studios', Icons.grid_view_rounded),
    ('گالری', '/studios/gallery', Icons.photo_library_outlined),
    ('تصویر', '/studios/studio-image', Icons.image_outlined),
    ('نوشتن', '/studios/studio-writing', Icons.edit_note_rounded),
    ('مدل‌ها', '/models', Icons.auto_awesome_rounded),
    ('پلن و کیف', '/account/plans', Icons.credit_card_rounded),
    ('تنظیمات', '/account/settings', Icons.tune_rounded),
    ('پشتیبانی', '/account/support', Icons.support_agent_rounded),
    ('دعوت دوستان', '/account/referral', Icons.card_giftcard_rounded),
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _go(String path) {
    Navigator.pop(context);
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim();
    final features = _features.where((f) {
      if (needle.isEmpty) return true;
      return f.$1.contains(needle);
    }).toList();
    final searchAsync = needle.length >= 2
        ? ref.watch(conversationSearchProvider(needle))
        : null;
    final convs = searchAsync?.asData?.value ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'جستجوی گفتگو یا بخش…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (convs.isNotEmpty) ...[
                    const Text('گفتگوها',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...convs.take(12).map(
                          (c) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(c.title ?? 'گفتگو'),
                            onTap: () => _go('/chat/${c.id}'),
                          ),
                        ),
                    const SizedBox(height: 12),
                  ],
                  const Text('بخش‌ها',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...features.map(
                    (f) => ListTile(
                      dense: true,
                      leading: Icon(f.$3, color: PigptColors.brand),
                      title: Text(f.$1),
                      onTap: () => _go(f.$2),
                    ),
                  ),
                  if (needle.length >= 2 &&
                      convs.isEmpty &&
                      (searchAsync?.isLoading ?? false))
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
