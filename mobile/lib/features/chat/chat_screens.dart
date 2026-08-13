import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/drafts.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/speech.dart';
import '../../core/starter_prompts.dart';
import '../../core/theme.dart';
import '../../core/voice_input.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/fullscreen_image.dart';
import '../../shared/widgets/pigpt_markdown.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';
import 'chat_limits.dart';
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
      appBar: const PigptAppBar(title: 'تاریخچه گفتگوها', showBack: true),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return SoftCard(
                        dense: true,
                        onTap: () => context.push('/chat/${c.id}'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: PigptColors.brandSoft,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
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
                                          _conversationTitle(c.title),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                              PopupMenuButton<String>(
                              onSelected: (v) async {
                                try {
                                  final api = ref.read(apiClientProvider);
                                  if (v == 'rename') {
                                    final next = await promptRename(
                                      context,
                                      _conversationTitle(c.title),
                                    );
                                    if (next == null || next.trim().isEmpty) {
                                      return;
                                    }
                                    await api.patch(
                                      ApiPaths.conversation(c.id),
                                      data: {'title': next.trim()},
                                    );
                                  } else if (v == 'pin') {
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
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('تغییر نام'),
                                ),
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
  final _lastUserKey = GlobalKey();
  final _streamEndKey = GlobalKey();
  late List<String> _starters;
  late final DraftSaver _drafts;
  VoiceInputService? _voice;
  bool _listening = false;
  bool _micBusy = false;

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
    _scroll.addListener(_onChatScroll);
    _input.addListener(_onDraftChanged);
    _drafts = DraftSaver();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final text = await ComposerDrafts.load(_sessionKey.conversationId);
    if (!mounted || text.isEmpty || _input.text.isNotEmpty) return;
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
  }

  void _onDraftChanged() {
    _drafts.schedule(_sessionKey.conversationId, _input.text);
    if (mounted) setState(() {});
  }

  double _maxBeforePrepend = 0;
  double _pixelsBeforePrepend = 0;
  double _turnSpacer = 0;
  bool _keepTurnSpacer = false;

  void _onChatScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset > 80) return;
    final key = _sessionKey;
    final session = ref.read(chatSessionProvider(key));
    if (!session.hasOlder || session.loadingOlder || session.streaming) return;
    _maxBeforePrepend = _scroll.position.maxScrollExtent;
    _pixelsBeforePrepend = _scroll.offset;
    ref.read(chatSessionProvider(key).notifier).loadOlder();
  }

  void _scrollToLatest() {
    _keepTurnSpacer = false;
    if (_turnSpacer != 0 && mounted) setState(() => _turnSpacer = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  RenderBox? _boxOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  RenderBox? _scrollBox() {
    if (!_scroll.hasClients) return null;
    final box = _scroll.position.context.notificationContext?.findRenderObject() ??
        _scroll.position.context.storageContext.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  void _jumpUserToTop() {
    final user = _boxOf(_lastUserKey);
    final view = _scrollBox();
    if (user == null || view == null || !_scroll.hasClients) return;
    final delta = user.localToGlobal(Offset.zero).dy - view.localToGlobal(Offset.zero).dy - 8;
    final next =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(next);
  }

  void _syncTurnSpacer({required bool pin}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final user = _boxOf(_lastUserKey);
      if (user == null) {
        if (pin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncTurnSpacer(pin: true);
          });
        }
        return;
      }
      final next =
          (_scroll.position.viewportDimension - user.size.height - 16)
              .clamp(0.0, _scroll.position.viewportDimension);
      void afterSpacer() {
        if (!mounted) return;
        if (pin) _jumpUserToTop();
      }

      if ((next - _turnSpacer).abs() > 1) {
        setState(() => _turnSpacer = next);
        WidgetsBinding.instance.addPostFrameCallback((_) => afterSpacer());
      } else {
        afterSpacer();
      }
    });
  }

  void _pinLastUserToTop() {
    _keepTurnSpacer = true;
    _syncTurnSpacer(pin: true);
  }

  void _followTypingIfClipped() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final endBox = _boxOf(_streamEndKey);
      final view = _scrollBox();
      if (endBox == null || view == null) return;
      final caretBottom = endBox.localToGlobal(Offset(0, endBox.size.height)).dy;
      final viewBottom = view.localToGlobal(Offset(0, view.size.height)).dy;
      final overflow = caretBottom - viewBottom + 16;
      if (overflow > 6) {
        final next = (_scroll.offset + overflow)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _drafts.flush(_sessionKey.conversationId, _input.text);
    _drafts.dispose();
    _voice?.dispose();
    _input.removeListener(_onDraftChanged);
    _scroll.removeListener(_onChatScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    ref.read(chatChromeProvider.notifier).state = null;
    super.deactivate();
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

  Future<void> _pickAttachment(ChatSessionController ctrl) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('تصویر از گالری'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('دوربین'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('فایل / PDF'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'file') {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'txt',
          'md',
          'csv',
          'doc',
          'docx',
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
      );
      final f = picked?.files.single;
      if (f?.path == null) return;
      await ctrl.attachFile(f!.path!, filename: f.name);
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final img = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (img == null) return;
    await ctrl.attachFile(img.path, filename: img.name);
  }

  Future<void> _toggleMic() async {
    final enabled = ref.read(speechInputEnabledProvider);
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ورودی صوتی را از تنظیمات گفتار روشن کنید'),
        ),
      );
      return;
    }
    _voice ??= VoiceInputService(ref.read(apiClientProvider));
    await _voice!.toggle(
      currentText: _input.text,
      onText: (t) {
        if (!mounted) return;
        _input.text = t;
        _input.selection = TextSelection.collapsed(offset: t.length);
        setState(() {});
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _micBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
      },
    );
    if (!mounted) return;
    setState(() {
      _listening = _voice?.listening ?? false;
      _micBusy = _voice?.busy ?? false;
    });
  }

  void _bindChrome(ChatSessionController ctrl, ChatSessionState session) {
    ref.read(chatChromeProvider.notifier).state = ChatChromeActions(
      conversationId: session.conversationId,
      title: session.title,
      onNewChat: () {
        ctrl.startFresh();
        _input.clear();
        ComposerDrafts.clear(_sessionKey.conversationId);
        setState(() => _starters = StarterPrompts.pick(count: 4));
        context.go('/chat');
      },
      onPickModel: () => _pickModel(ctrl, session),
      onShare: session.conversationId == null
          ? null
          : () => _share(session.conversationId!),
      onRename: session.conversationId == null
          ? null
          : () async {
              final next = await promptRename(
                context,
                _conversationTitle(session.title),
              );
              if (next != null) await ctrl.rename(next);
            },
      onPin: session.conversationId == null
          ? null
          : () => ctrl.setPinned(pinned: true),
      onArchive: session.conversationId == null
          ? null
          : () async {
              await ctrl.archive(archived: true);
              if (!mounted) return;
              if (widget.isHome) {
                ctrl.startFresh();
                _input.clear();
              } else {
                context.go('/chat');
              }
            },
      onDelete: session.conversationId == null
          ? null
          : () async {
              await ctrl.deleteConversation();
              if (!mounted) return;
              if (widget.isHome) {
                ctrl.startFresh();
                _input.clear();
              } else {
                context.go('/chat');
              }
            },
      onTemplates: () async {
        final templates = await ref.read(chatTemplatesProvider.future);
        if (!mounted) return;
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
      },
      onRegenerate: session.streaming ? null : ctrl.regenerate,
    );
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
    final session = ref.watch(chatSessionProvider(key));
    final ctrl = ref.read(chatSessionProvider(key).notifier);
    final me = ref.watch(meProvider);

    ref.listen<ChatSessionState>(chatSessionProvider(key), (prev, next) {
      final wasStreaming = prev?.streaming ?? false;
      final started = !wasStreaming && next.streaming;
      final reloadedAfterStream = wasStreaming &&
          !next.streaming &&
          next.messages.isNotEmpty;
      final idsReplaced = prev != null &&
          !next.streaming &&
          prev.messages.isNotEmpty &&
          next.messages.isNotEmpty &&
          prev.messages.last.id != next.messages.last.id;
      final initialLoad = (prev == null || prev.messages.isEmpty) &&
          next.messages.isNotEmpty &&
          !next.streaming;
      final prepended = prev != null &&
          prev.messages.isNotEmpty &&
          next.messages.isNotEmpty &&
          next.messages.length > prev.messages.length &&
          next.messages.last.id == prev.messages.last.id &&
          next.messages.first.id != prev.messages.first.id;
      if (prepended && _scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          final delta =
              _scroll.position.maxScrollExtent - _maxBeforePrepend;
          _scroll.jumpTo(_pixelsBeforePrepend + delta);
        });
        return;
      }
      if (started || reloadedAfterStream) {
        _pinLastUserToTop();
      } else if (initialLoad) {
        _scrollToLatest();
      } else if (idsReplaced && _keepTurnSpacer) {
        _pinLastUserToTop();
      } else if (next.streaming && _keepTurnSpacer) {
        _followTypingIfClipped();
      }
    });

    _bindChrome(ctrl, session);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: PigptAppBar(
        showBack: !widget.isHome,
        titleWidget: widget.isHome
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PigptMark(size: 26),
                  SizedBox(width: 8),
                  Text(PigptBrand.webDisplay),
                ],
              )
            : Text(_conversationTitle(session.title)),
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
          if (session.loadingOlder)
            const LinearProgressIndicator(minHeight: 2),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: session.messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i >= session.messages.length) {
                        return SizedBox(height: _keepTurnSpacer ? _turnSpacer : 0);
                      }
                      final m = session.messages[i];
                      final lastUserIdx = session.messages
                          .lastIndexWhere((x) => x.role == 'user');
                      final lastAsstIdx = session.messages
                          .lastIndexWhere((x) => x.role == 'assistant');
                      return KeyedSubtree(
                        key: ValueKey(m.id),
                        child: _MessageBubble(
                          message: m,
                          anchorKey: i == lastUserIdx
                              ? _lastUserKey
                              : (m.streaming ? _streamEndKey : null),
                          canEdit: m.role == 'user' &&
                              !session.streaming &&
                              !m.id.startsWith('local-'),
                          onEdit: () => _editMessage(ctrl, m),
                          onRegenerate: m.role == 'assistant' &&
                                  i == lastAsstIdx &&
                                  !session.streaming
                              ? () => ctrl.regenerate()
                              : null,
                        ),
                      );
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
                  else ...[
                    if (_isImageName(session.pending!.name) ||
                        (session.pending!.localPath != null &&
                            _isImageName(session.pending!.localPath!)))
                      _ChatImageThumb(
                        filePath: session.pending!.localPath,
                        assetId: session.pending!.id,
                        size: 48,
                      )
                    else
                      Flexible(
                        child: Text(
                          session.pending!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'حذف پیوست',
                      onPressed: ctrl.clearPending,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ],
              ),
            ),
          if (session.fill >= 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                kChatFullFa,
                textAlign: TextAlign.center,
                style: TextStyle(color: PigptColors.danger, fontSize: 12),
              ),
            )
          else if (session.fill >= 0.85)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                kChatNearFullFa,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
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
                    tooltip: 'پیوست فایل یا تصویر',
                    onPressed: session.streaming || session.uploading
                        ? null
                        : () => _pickAttachment(ctrl),
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  if (ref.watch(speechInputEnabledProvider))
                    IconButton(
                      tooltip: _listening ? 'توقف ضبط' : 'ورودی صوتی',
                      onPressed: session.streaming || _micBusy
                          ? null
                          : _toggleMic,
                      icon: Icon(
                        _listening
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none_rounded,
                        color: _listening ? PigptColors.danger : null,
                      ),
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
                        if (session.isFull) return;
                        final t = _input.text;
                        _input.clear();
                        ComposerDrafts.clear(session.conversationId);
                        ctrl.send(t);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ComposerSendColumn(
                    fill: (() {
                      final cap = session.capTokens <= 0
                          ? kChatContextCapTokens
                          : session.capTokens;
                      return ((session.fill * cap) +
                              estimateTokens(_input.text))
                          .clamp(0, cap) /
                          cap;
                    })(),
                    usedTokens: session.usedTokens +
                        estimateTokens(_input.text),
                    capTokens: session.capTokens,
                    streaming: session.streaming,
                    enabled: !session.isFull,
                    onStop: ctrl.stop,
                    onSend: () {
                      HapticFeedback.lightImpact();
                      final t = _input.text;
                      _input.clear();
                      ComposerDrafts.clear(session.conversationId);
                      ctrl.send(t);
                    },
                  ),
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

class _ComposerSendColumn extends StatelessWidget {
  const _ComposerSendColumn({
    required this.fill,
    required this.usedTokens,
    required this.capTokens,
    required this.streaming,
    required this.enabled,
    required this.onStop,
    required this.onSend,
  });

  final double fill;
  final int usedTokens;
  final int capTokens;
  final bool streaming;
  final bool enabled;
  final VoidCallback onStop;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streaming)
          IconButton.filled(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
          )
        else
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded),
          ),
        const SizedBox(height: 4),
        _ChatVolumeRing(fill: fill, usedTokens: usedTokens, capTokens: capTokens),
      ],
    );
  }
}

class _ChatVolumeRing extends StatelessWidget {
  const _ChatVolumeRing({
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
      message:
          'حجم این گفتگو $pct٪ · حدود $usedTokens از $capTokens توکن',
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          value: p,
          strokeWidth: 2.4,
          backgroundColor: PigptColors.border,
          color: hot ? const Color(0xFFF59E0B) : PigptColors.brand,
        ),
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

final _uuidLike = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _conversationTitle(String? title) {
  final t = title?.trim() ?? '';
  if (t.isEmpty || _uuidLike.hasMatch(t)) return 'گفتگو';
  return t;
}

Future<String?> promptRename(BuildContext context, String current) async {
  final c = TextEditingController(text: current);
  final next = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('نام گفتگو'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'عنوان جدید'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
  c.dispose();
  return next;
}

bool _isImageName(String name) {
  return RegExp(r'\.(png|jpe?g|gif|webp|heic)$', caseSensitive: false)
      .hasMatch(name);
}

bool _looksLikeImageRef(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  final lower = t.toLowerCase();
  if (lower.startsWith('<!--assets:')) return true;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(t) &&
      (lower.contains('/uploads/') ||
          lower.contains('/assets/') ||
          RegExp(r'\.(png|jpe?g|gif|webp|heic)(\?|$)').hasMatch(lower))) {
    return true;
  }
  if (t.contains('/uploads/') || t.contains('/assets/')) return true;
  if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(t)) return true;
  if (t.startsWith('/data/') ||
      t.startsWith('/storage/') ||
      t.contains('/cache/') ||
      t.startsWith('file:')) {
    return true;
  }
  if (RegExp(r'\.(png|jpe?g|gif|webp|heic)$', caseSensitive: false).hasMatch(t)) {
    return true;
  }
  return false;
}

String _visibleMessageText(String content) {
  var t = stripPoweredByFooter(content);
  t = t.replaceAll(RegExp(r'<!--assets:[^>]+-->'), '');
  if (_looksLikeImageRef(t)) return '';
  t = t.replaceAll(
    RegExp(r'https?://\S+/(?:uploads|assets)/\S+', caseSensitive: false),
    '',
  );
  return t.trim();
}

String? _imageUrlFromContent(String content) {
  final t = content.trim();
  final abs = RegExp(
    r'https?://\S+/(?:api/v1/)?(?:uploads|assets)/[^\s)>\]]+',
    caseSensitive: false,
  ).firstMatch(t);
  if (abs != null) return abs.group(0);
  final rel = RegExp(
    r'(?:/api/v1)?(/(?:uploads|assets)/[a-f0-9\-]+)',
    caseSensitive: false,
  ).firstMatch(t);
  if (rel != null) {
    return '${PigptBrand.apiBase}${PigptBrand.apiPrefix}${rel.group(1)}';
  }
  return null;
}

String? _localFileFromContent(String content) {
  final t = content.trim().replaceFirst(RegExp(r'^file://'), '');
  if (t.startsWith('/data/') ||
      t.startsWith('/storage/') ||
      t.contains('/cache/') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(t)) {
    return t;
  }
  return null;
}

List<String> _assetIdsIn(String content, List<String> attachmentIds) {
  final ids = [...attachmentIds];
  final m = RegExp(r'<!--assets:([a-f0-9,\-]+)-->', caseSensitive: false)
      .firstMatch(content);
  if (m != null) {
    for (final part in m.group(1)!.split(',')) {
      final id = part.trim();
      if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
    }
  }
  return ids;
}

String stripPoweredByFooter(String text) {
  if (text.isEmpty) return text;
  return text
      .replaceAll(
        RegExp(
          r'(?:\n|^)\s*(?:[-–—*•]\s*)?(?:PiGPT\s*[·•|\-–—]?\s*)?(?:قدرت[\u200c\s\-]*گرفته\s*از|powered\s+by)\s+[^\n]+?\s*$',
          caseSensitive: false,
          multiLine: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trimRight();
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    this.anchorKey,
    this.canEdit = false,
    this.onEdit,
    this.onRegenerate,
  });
  final ChatMessage message;
  final Key? anchorKey;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final ttsOn = ref.watch(speechOutputEnabledProvider);
    final cleaned = stripPoweredByFooter(message.content);
    final assetIds = _assetIdsIn(message.content, message.attachmentIds);
    final thumbs = _thumbWidgets(message, assetIds);
    var visible = _visibleMessageText(cleaned);
    if (thumbs.isNotEmpty &&
        (visible == 'تصویر پیوست شد' || visible == 'تصویر پیوست')) {
      visible = '';
    }
    final mdSource = message.streaming ? visible.replaceAll(RegExp(r'\n+$'), '') : visible;
    final emptyAssistant = !isUser &&
        !message.streaming &&
        visible.trim().isEmpty &&
        thumbs.isEmpty;
    if (emptyAssistant) {
      final err = (message.errorFa != null && message.errorFa!.trim().isNotEmpty)
          ? message.errorFa!
          : 'پاسخ دریافت نشد. اتصال قطع شد یا مدل جواب نداد. دوباره تلاش کنید.';
      return Align(
        key: anchorKey,
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: PigptColors.bubbleAssistant(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PigptColors.danger.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  err,
                  style: const TextStyle(color: PigptColors.danger, height: 1.45),
                ),
                if (onRegenerate != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('دوباره تلاش کنید'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Align(
      key: anchorKey,
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
                ? PigptColors.bubbleUser(context)
                : PigptColors.bubbleAssistant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PigptColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (thumbs.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: thumbs,
                ),
                const SizedBox(height: 8),
              ],
              if (isUser)
                visible.isEmpty
                    ? const SizedBox.shrink()
                    : SelectableText(visible)
              else if (mdSource.isEmpty && message.streaming)
                const SizedBox(
                  height: 22,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                PigptMarkdown(
                  data: mdSource,
                  streaming: message.streaming,
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
              if (!isUser && !message.streaming) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    if (ttsOn)
                      IconButton(
                        tooltip: SpeechService.speaking &&
                                SpeechService.speakingText ==
                                    SpeechService.plainText(visible)
                            ? 'توقف صدا'
                            : 'پخش صدا',
                        onPressed: visible.isEmpty
                            ? null
                            : () async {
                                final err = await SpeechService.speak(visible);
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                }
                              },
                        icon: Icon(
                          SpeechService.speaking &&
                                  SpeechService.speakingText ==
                                      SpeechService.plainText(visible)
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 16,
                        ),
                      ),
                    IconButton(
                      tooltip: 'کپی',
                      onPressed: visible.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: visible));
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

List<Widget> _thumbWidgets(ChatMessage message, List<String> assetIds) {
  if (message.localPath != null && message.localPath!.isNotEmpty) {
    return [_ChatImageThumb(filePath: message.localPath)];
  }
  if (assetIds.isNotEmpty) {
    return [for (final id in assetIds) _ChatImageThumb(assetId: id)];
  }
  final file = _localFileFromContent(message.content);
  if (file != null) return [_ChatImageThumb(filePath: file)];
  final url = _imageUrlFromContent(message.content);
  if (url != null) return [_ChatImageThumb(networkUrl: url)];
  return const [];
}

class _ChatImageThumb extends ConsumerWidget {
  const _ChatImageThumb({
    this.filePath,
    this.assetId,
    this.networkUrl,
    this.size = 96,
  });

  final String? filePath;
  final String? assetId;
  final String? networkUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = filePath != null && filePath!.isNotEmpty ? File(filePath!) : null;
    if (file != null && file.existsSync()) {
      return _frame(
        Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _broken(),
        ),
      );
    }
    final url = networkUrl ??
        (assetId != null && assetId!.isNotEmpty
            ? '${PigptBrand.apiBase}${PigptBrand.apiPrefix}/uploads/$assetId'
            : null);
    if (url == null || url.isEmpty) return _frame(_broken());
    return FutureBuilder<String?>(
      future: ref.read(tokenStoreProvider).read(),
      builder: (context, snap) {
        final token = snap.data;
        return _frame(
          Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            headers: token != null && token.isNotEmpty
                ? {'Authorization': 'Bearer $token'}
                : const {},
            errorBuilder: (_, __, ___) => _broken(),
          ),
        );
      },
    );
  }

  Widget _frame(Widget child) {
    final file = filePath;
    final url = networkUrl ??
        (assetId != null && assetId!.isNotEmpty
            ? '${PigptBrand.apiBase}${PigptBrand.apiPrefix}/uploads/$assetId'
            : null);
    return TappableImage(
      filePath: file,
      url: url,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }

  Widget _broken() => ColoredBox(
        color: PigptColors.bgElevated,
        child: Icon(Icons.image_outlined, size: size * 0.4, color: PigptColors.inkFaint),
      );
}

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modelsProvider);
    return Scaffold(
      appBar: const PigptAppBar(title: 'مدل‌ها', showBack: true),
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
