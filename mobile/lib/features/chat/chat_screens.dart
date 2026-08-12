import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/speech.dart';
import '../../core/starter_prompts.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';
import 'chat_providers.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _archived = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final asyncConvs = ref.watch(conversationsProvider(_archived));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'بازگشت به گفتگو',
          onPressed: () => context.go('/chat'),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: const Text('تاریخچه گفتگوها'),
        actions: [
          IconButton(
            tooltip: 'ماموریت‌های ایجنت',
            onPressed: () => context.push('/agent'),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: 'مدل‌ها',
            onPressed: () => context.push('/models'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.go('/chat');
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('گفتگوی جدید'),
      )
          .animate()
          .fadeIn(duration: 280.ms)
          .scale(begin: const Offset(0.92, 0.92)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: WalletBanner(
              canGenerate: me?.canGenerate ?? true,
              balance: me?.balance,
              dailyRemaining: me?.dailyTokensRemaining ?? me?.freeDailyRemaining,
              dailyCap: me?.freeDailyCap,
              onTopUp: () => context.push('/account/plans'),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'جستجوی گفتگو…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(_archived ? 'بایگانی' : 'فعال'),
                  selected: _archived,
                  onSelected: (v) => setState(() => _archived = v),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 40.ms),
          Expanded(
            child: asyncConvs.when(
              loading: () => const ListShimmer(itemCount: 8),
              error: (e, _) => EmptyState(
                title: 'بارگذاری گفتگوها ناموفق بود',
                body: '$e',
                action: FilledButton(
                  onPressed: () =>
                      ref.invalidate(conversationsProvider(_archived)),
                  child: const Text('تلاش دوباره'),
                ),
              ),
              data: (list) {
                final searchAsync = _query.length >= 2
                    ? ref.watch(conversationSearchProvider(_query))
                    : null;
                var filtered = searchAsync?.asData?.value ??
                    (_query.isEmpty
                        ? list
                        : list
                            .where((c) =>
                                (c.title ?? '').contains(_query) ||
                                c.id.contains(_query))
                            .toList());
                // Pin polish: pinned first
                filtered = [
                  ...filtered.where((c) => c.pinned),
                  ...filtered.where((c) => !c.pinned),
                ];
                if (searchAsync != null && searchAsync.isLoading) {
                  return const ListShimmer(itemCount: 4);
                }
                if (filtered.isEmpty) {
                  return EmptyState(
                    title: 'هنوز گفتگویی نیست',
                    body: 'اولین پیام را بفرستید — PiGPT پاسخ را استریم می‌کند.',
                    action: FilledButton(
                      onPressed: () => context.go('/chat'),
                      child: const Text('شروع گفتگو'),
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(conversationsProvider(_archived));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return SoftCard(
                        onTap: () => context.push('/chat/${c.id}'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: PigptColors.brandSoft,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.asset(
                                  PigptBrand.logoAsset,
                                  fit: BoxFit.contain,
                                  semanticLabel: PigptBrand.webDisplay,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (c.pinned) ...[
                                        const Icon(Icons.push_pin_rounded,
                                            size: 14, color: PigptColors.brand),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          c.title?.isNotEmpty == true
                                              ? c.title!
                                              : 'گفتگو',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (c.modelId != null)
                                    Text(
                                      c.modelId!,
                                      style: const TextStyle(
                                        color: PigptColors.inkFaint,
                                        fontSize: 12,
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                try {
                                  final api = ref.read(apiClientProvider);
                                  if (v == 'pin') {
                                    await api.patch(
                                      ApiPaths.conversation(c.id),
                                      data: {
                                        'is_pinned': !c.pinned,
                                        'pinned': !c.pinned,
                                      },
                                    );
                                  } else if (v == 'archive') {
                                    await api.patch(
                                      ApiPaths.conversation(c.id),
                                      data: {'archived': !_archived},
                                    );
                                  } else if (v == 'delete') {
                                    await api.delete(ApiPaths.conversation(c.id));
                                  }
                                  ref.invalidate(conversationsProvider(false));
                                  ref.invalidate(conversationsProvider(true));
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)));
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Text(c.pinned
                                      ? 'برداشتن سنجاق'
                                      : 'سنجاق'),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(_archived
                                      ? 'بازگردانی'
                                      : 'بایگانی'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate(delay: (35 * i).ms)
                          .fadeIn(duration: 280.ms)
                          .slideX(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    this.conversationId,
    this.initialModelId,
    this.isHome = false,
  });
  final String? conversationId;
  final String? initialModelId;
  /// When true, this is the shell chat tab: composer-first home (not archive).
  final bool isHome;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late List<String> _starters;

  ChatSessionKey get _sessionKey {
    final id = widget.conversationId == 'new' ? null : widget.conversationId;
    return ChatSessionKey(
      conversationId: id,
      initialModelId: id == null ? widget.initialModelId : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _starters = StarterPrompts.pick(count: 4);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickModel(ChatSessionController ctrl, ChatSessionState s) async {
    final models = await ref.read(modelsProvider.future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('انتخاب مدل')),
            ...models.map(
              (m) => ListTile(
                title: Text(m.name),
                subtitle: m.vendor != null ? Text(m.vendor!) : null,
                selected: m.id == s.modelId,
                onTap: () => Navigator.pop(ctx, m.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) ctrl.setModel(selected);
  }

  Future<void> _share(String convId) async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.conversationShare(convId),
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final url = '${data['url'] ?? data['share_url'] ?? ''}';
      if (url.isNotEmpty) {
        await Share.share(url);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _pickImage(ChatSessionController ctrl) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('گالری'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('دوربین'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (picked == null) return;
    await ctrl.attachImage(picked.path, filename: picked.name);
  }

  Future<void> _editMessage(
    ChatSessionController ctrl,
    ChatMessage message,
  ) async {
    final edited = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: message.content);
        return AlertDialog(
          title: const Text('ویرایش پیام'),
          content: TextField(
            controller: c,
            minLines: 3,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'متن جدید پیام…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('اعمال و بازتولید'),
            ),
          ],
        );
      },
    );
    if (edited == null) return;
    await ctrl.editMessage(message.id, edited);
  }

  @override
  Widget build(BuildContext context) {
    final key = _sessionKey;
    final id = key.conversationId;
    final session = ref.watch(chatSessionProvider(key));
    final ctrl = ref.read(chatSessionProvider(key).notifier);
    final me = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isHome,
        title: widget.isHome
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PigptMark(size: 28),
                  const SizedBox(width: 10),
                  Text(PigptBrand.webDisplay),
                ],
              )
                .animate()
                .fadeIn(duration: 280.ms)
                .slideX(begin: 0.04, end: 0)
            : Text(id == null ? 'گفتگوی جدید' : 'گفتگو'),
        actions: [
          if (session.modelId != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  session.modelId!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PigptColors.inkFaint,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          if (widget.isHome) ...[
            IconButton(
              tooltip: 'تاریخچه گفتگوها',
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/chat/history');
              },
              icon: const Icon(Icons.history_rounded),
            ),
            if (session.messages.isNotEmpty || session.conversationId != null)
              IconButton(
                tooltip: 'گفتگوی جدید',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ctrl.startFresh();
                  _input.clear();
                  setState(() {
                    _starters = StarterPrompts.pick(count: 4);
                  });
                },
                icon: const Icon(Icons.edit_square),
              ),
          ],
          IconButton(
            tooltip: 'مدل',
            onPressed: () => _pickModel(ctrl, session),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          if (session.conversationId != null)
            IconButton(
              tooltip: 'اشتراک',
              onPressed: () => _share(session.conversationId!),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'regenerate') ctrl.regenerate();
              if (v == 'agent') context.push('/agent');
              if (v == 'history') context.push('/chat/history');
              if (v == 'archive' && session.conversationId != null) {
                await ctrl.archive(archived: true);
                if (context.mounted) {
                  if (widget.isHome) {
                    ctrl.startFresh();
                    _input.clear();
                  } else {
                    context.go('/chat');
                  }
                }
              }
              if (v == 'pin' && session.conversationId != null) {
                await ctrl.setPinned(pinned: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سنجاق شد')),
                  );
                }
              }
              if (v == 'delete' && session.conversationId != null) {
                await ctrl.deleteConversation();
                if (context.mounted) {
                  if (widget.isHome) {
                    ctrl.startFresh();
                    _input.clear();
                  } else {
                    context.go('/chat');
                  }
                }
              }
              if (v == 'templates') {
                final templates = await ref.read(chatTemplatesProvider.future);
                if (!context.mounted) return;
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: templates.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('قالبی در دسترس نیست'),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              const ListTile(title: Text('قالب‌های گفتگو')),
                              ...templates.map((t) {
                                final title =
                                    '${t['title'] ?? t['title_fa'] ?? t['name'] ?? 'قالب'}';
                                final body =
                                    '${t['prompt'] ?? t['content'] ?? t['body'] ?? ''}';
                                return ListTile(
                                  title: Text(title),
                                  subtitle: body.isEmpty
                                      ? null
                                      : Text(body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                  onTap: () => Navigator.pop(
                                      ctx, body.isNotEmpty ? body : title),
                                );
                              }),
                            ],
                          ),
                  ),
                );
                if (picked != null && picked.isNotEmpty) {
                  _input.text = picked;
                }
              }
            },
            itemBuilder: (_) => [
              if (widget.isHome)
                const PopupMenuItem(
                    value: 'history', child: Text('تاریخچه گفتگوها')),
              const PopupMenuItem(value: 'templates', child: Text('قالب‌ها')),
              const PopupMenuItem(value: 'regenerate', child: Text('بازتولید پاسخ')),
              const PopupMenuItem(value: 'pin', child: Text('سنجاق گفتگو')),
              const PopupMenuItem(value: 'archive', child: Text('بایگانی گفتگو')),
              const PopupMenuItem(value: 'delete', child: Text('حذف گفتگو')),
              const PopupMenuItem(value: 'agent', child: Text('ماموریت ایجنت')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'chat', label: Text('گفتگو')),
                      ButtonSegment(value: 'agent', label: Text('ایجنت')),
                    ],
                    selected: {session.mode},
                    onSelectionChanged: (s) => ctrl.setMode(s.first),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.05, end: 0),
          if (!(me?.canGenerate ?? true))
            Padding(
              padding: const EdgeInsets.all(12),
              child: WalletBanner(
                canGenerate: false,
                balance: me?.balance,
                dailyRemaining: me?.dailyTokensRemaining,
                onTopUp: () => context.push('/account/plans'),
              ),
            ),
          Expanded(
            child: session.messages.isEmpty
                ? _EmptyChat(
                    starters: _starters,
                    onPick: (t) {
                      HapticFeedback.selectionClick();
                      _input.text = t;
                      ctrl.send(t);
                    },
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: session.messages.length,
                    itemBuilder: (context, i) {
                      final m = session.messages[i];
                      return _MessageBubble(
                        message: m,
                        canEdit: m.role == 'user' &&
                            !session.streaming &&
                            !m.id.startsWith('local-'),
                        onEdit: () => _editMessage(ctrl, m),
                      )
                          .animate()
                          .fadeIn(duration: 220.ms)
                          .slideY(begin: 0.04, end: 0);
                    },
                  ),
          ),
          if (session.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                session.error!,
                style: const TextStyle(color: PigptColors.danger),
              ),
            ),
          if (session.pending != null || session.uploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  if (session.uploading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Chip(
                      avatar: const Icon(Icons.image_outlined, size: 16),
                      label: Text(session.pending!.name,
                          overflow: TextOverflow.ellipsis),
                      onDeleted: ctrl.clearPending,
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'پیوست تصویر',
                    onPressed: session.streaming || session.uploading
                        ? null
                        : () => _pickImage(ctrl),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: session.mode == 'agent'
                            ? 'هدف ایجنت را بنویسید…'
                            : 'پیام خود را بنویسید…',
                      ),
                      onSubmitted: (_) {
                        final t = _input.text;
                        _input.clear();
                        ctrl.send(t);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (session.streaming)
                    IconButton.filled(
                      onPressed: ctrl.stop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1, end: 1.06, duration: 700.ms)
                  else
                    IconButton.filled(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final t = _input.text;
                        _input.clear();
                        ctrl.send(t);
                      },
                      icon: const Icon(Icons.send_rounded),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.starters, required this.onPick});
  final List<String> starters;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        Center(child: const PigptMark(size: 64))
            .animate()
            .fadeIn(duration: 420.ms)
            .scale(begin: const Offset(0.88, 0.88), curve: Curves.easeOutBack)
            .then(delay: 200.ms)
            .shimmer(duration: 1400.ms, color: PigptColors.brandSoft),
        const SizedBox(height: 12),
        Text(
          'از کجا شروع کنیم؟',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 4),
        Text(
          'پیشنهادها هر بار عوض می‌شوند — بدون پخش خودکار صدا.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PigptColors.inkMuted,
              ),
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: 10),
        ...starters.asMap().entries.map((e) {
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onPick(e.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 16,
                    color: PigptColors.brand.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: PigptColors.ink,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate(delay: (50 * e.key).ms)
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
        }),
      ],
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    this.canEdit = false,
    this.onEdit,
  });
  final ChatMessage message;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final ttsOn = ref.watch(speechOutputEnabledProvider);
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUser
                ? PigptColors.brandDeep.withValues(alpha: 0.35)
                : PigptColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PigptColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message.attachmentIds.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Chip(
                    avatar: const Icon(Icons.image_outlined, size: 16),
                    label: Text('${message.attachmentIds.length} پیوست'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (isUser)
                SelectableText(message.content)
              else
                MarkdownBody(
                  data: message.content.isEmpty && message.streaming
                      ? PigptBrand.loadingWriting
                      : message.content,
                  selectable: true,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.55),
                    code: const TextStyle(
                      fontFamily: 'monospace',
                      backgroundColor: Color(0xFF0A0F18),
                    ),
                  ),
                ),
              if (isUser && canEdit) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('ویرایش'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
              if (!isUser) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        PigptBrand.poweredBy(message.modelId ?? 'مدل'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: PigptColors.inkFaint,
                        ),
                      ),
                    ),
                    if (ttsOn)
                      IconButton(
                        tooltip: 'پخش صدا',
                        onPressed: message.content.isEmpty
                            ? null
                            : () => SpeechService.speak(message.content),
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                      ),
                    IconButton(
                      tooltip: 'کپی',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: message.content));
                        HapticFeedback.selectionClick();
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                    ),
                  ],
                ),
              ],
              if (message.errorFa != null)
                Text(
                  message.errorFa!,
                  style: const TextStyle(
                      color: PigptColors.danger, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('مدل‌ها')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (models) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: models.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = models[i];
            return SoftCard(
              onTap: () => context.go('/chat/new', extra: m.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (m.description != null) ...[
                    const SizedBox(height: 4),
                    Text(m.description!,
                        style: const TextStyle(color: PigptColors.inkMuted)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
