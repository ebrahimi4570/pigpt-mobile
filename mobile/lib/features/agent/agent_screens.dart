import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/live_status.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/live_status_line.dart';
import '../../shared/widgets/pigpt_composer.dart';
import '../../shared/widgets/tool_output.dart';
import '../../shared/widgets/ui.dart';
import 'agent_providers.dart';

final agentMissionsProvider = FutureProvider<List<AgentMission>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get<dynamic>(ApiPaths.agentMissions);
    final list = data is List
        ? data
        : (data is Map
            ? (data['missions'] ?? data['items'] ?? data['data'] ?? [])
            : []);
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => AgentMission.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } on ApiException catch (e) {
    if (e.statusCode == 404 || e.statusCode == 410) return null;
    rethrow;
  }
});

class AgentMissionsScreen extends ConsumerStatefulWidget {
  const AgentMissionsScreen({super.key});

  @override
  ConsumerState<AgentMissionsScreen> createState() => _AgentMissionsScreenState();
}

class _AgentMissionsScreenState extends ConsumerState<AgentMissionsScreen> {
  final _goal = TextEditingController();
  final _pathName = TextEditingController();
  bool _busy = false;
  LiveStatus _live = const LiveStatus();

  @override
  void dispose() {
    _goal.dispose();
    _pathName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final goal = _goal.text.trim();
    if (goal.isEmpty) return;
    final ws = ref.read(agentWorkspaceProvider).current;
    if (ws == null) {
      setState(() =>
          _live = const LiveStatus(phase: LivePhase.error, errorFa: 'ابتدا یک مسیر بسازید'));
      return;
    }
    setState(() {
      _busy = true;
      _live = const LiveStatus(phase: LivePhase.waiting);
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.agentMissions,
        data: {
          'goal': goal,
          'confirm_sensitive': true,
          if (ws.id.length > 20) 'workspace_id': ws.id,
          'workspace_path': ws.slug.isNotEmpty ? ws.slug : ws.path,
          'workspace_name': ws.name,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      _goal.clear();
      ref.invalidate(agentMissionsProvider);
      if (mounted) context.push('/agent/${data['id']}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() =>
            _live = LiveStatus(phase: LivePhase.error, errorFa: e.message));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(agentMissionsProvider);
    final ws = ref.watch(agentWorkspaceProvider);
    return Scaffold(
      appBar: const PigptAppBar(title: 'ایجنت', showBack: true),
      body: ws.loading
          ? const ListShimmer(itemCount: 5)
          : ws.current == null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'ساخت مسیر'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pathName,
                            decoration: const InputDecoration(
                              hintText: 'نام مسیر، مثلاً فروشگاه',
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    await ref
                                        .read(agentWorkspaceProvider.notifier)
                                        .create(_pathName.text);
                                    _pathName.clear();
                                    if (mounted) setState(() => _busy = false);
                                  },
                            child: const Text('ساخت مسیر'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : async.when(
        loading: () => const ListShimmer(itemCount: 5),
        error: (e, _) => EmptyState(
          title: 'خطا در بارگذاری ماموریت‌ها',
          body: '$e',
        ),
        data: (missions) {
          if (missions == null) {
            return const EmptyState(
              title: 'ایجنت در دسترس نیست',
              body: 'بعداً دوباره تلاش کنید.',
            );
          }
          final current = ws.current!;
          final filtered = missions
              .where((m) =>
                  m.workspacePath == null ||
                  m.workspacePath == current.slug ||
                  m.workspacePath == current.path)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'مسیر فعال: ${current.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'هدف جدید'),
              const SizedBox(height: 8),
              PigptComposer(
                controller: _goal,
                hint: 'مثلاً: گزارش کوتاه بازار رقبای محلی…',
                minLines: 2,
                maxLines: 4,
                enabled: !_busy,
                onSend: _create,
              ).animate().fadeIn().slideY(begin: 0.05, end: 0),
              LiveStatusLine(status: _live),
              const SizedBox(height: 20),
              const SectionHeader(title: 'مسیرهای ایجنت'),
              const SizedBox(height: 8),
              ...ws.items.map(
                (w) => SoftCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  onTap: () =>
                      ref.read(agentWorkspaceProvider.notifier).select(w),
                  child: Row(
                    children: [
                      Expanded(child: Text(w.label)),
                      if (w.slug == current.slug)
                        const Text('فعال',
                            style: TextStyle(
                                fontSize: 11, color: PigptColors.brand)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pathName,
                decoration: const InputDecoration(
                  hintText: 'نام مسیر جدید',
                ),
                onSubmitted: (v) =>
                    ref.read(agentWorkspaceProvider.notifier).create(v),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'ماموریت‌های این مسیر'),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const EmptyState(
                  title: 'ماموریتی نیست',
                  body: 'اولین هدف را بالا بنویسید.',
                )
              else
                ...filtered.asMap().entries.map((e) {
                  final m = e.value;
                  return SoftCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () => context.push('/agent/${m.id}'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.goal,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(m.statusFa,
                                  style: const TextStyle(
                                      color: PigptColors.inkMuted,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ).animate(delay: (30 * e.key).ms).fadeIn();
                }),
            ],
          );
        },
      ),
    );
  }
}

LiveStatus _missionLive(
  AgentMission m, {
  LiveStatus? current,
  String? toolHint,
}) {
  if (current != null &&
      (current.phase == LivePhase.error || current.isActive)) {
    return current;
  }
  final fromHint = livePhaseFromTool({'name': toolHint ?? ''});
  if (fromHint != null) return LiveStatus(phase: fromHint);
  AgentStep? running;
  for (final s in m.steps) {
    if (s.status == 'running') {
      running = s;
      break;
    }
  }
  final fromStep = livePhaseFromTool({'name': running?.needsTool ?? ''});
  if (fromStep != null) return LiveStatus(phase: fromStep);
  switch (m.status) {
    case 'running':
    case 'planning':
      return const LiveStatus(phase: LivePhase.thinking);
    case 'completed':
      return const LiveStatus(phase: LivePhase.ready);
    case 'failed':
      return const LiveStatus(phase: LivePhase.error, errorFa: 'ماموریت ناموفق');
    default:
      return current ?? const LiveStatus();
  }
}

class AgentMissionDetailScreen extends ConsumerStatefulWidget {
  const AgentMissionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<AgentMissionDetailScreen> createState() =>
      _AgentMissionDetailScreenState();
}

class _AgentMissionDetailScreenState
    extends ConsumerState<AgentMissionDetailScreen> {
  AgentMission? _mission;
  String? _error;
  dynamic _toolOut;
  bool _busy = false;
  String? _toolHint;
  LiveStatus _live = const LiveStatus();
  final _fileAction = TextEditingController(text: 'list');
  final _qsPrompt = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fileAction.dispose();
    _qsPrompt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>(
        ApiPaths.agentMission(widget.id),
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _mission = AgentMission.fromJson(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _act(Future<dynamic> Function() fn, {String? tool}) async {
    setState(() {
      _busy = true;
      _toolOut = null;
      _toolHint = tool;
      final fromTool = livePhaseFromTool({'name': tool ?? ''});
      _live = LiveStatus(phase: fromTool ?? LivePhase.thinking);
    });
    try {
      final res = await fn();
      if (res != null) {
        setState(() => _toolOut = res);
      }
      await _load();
      if (mounted) {
        setState(() => _live = const LiveStatus(phase: LivePhase.ready));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() =>
            _live = LiveStatus(phase: LivePhase.error, errorFa: e.message));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _mission;
    return Scaffold(
      appBar: const PigptAppBar(title: 'جزئیات ماموریت', showBack: true),
      body: m == null
          ? (_error != null
              ? EmptyState(title: 'خطا', body: _error)
              : const ListShimmer(itemCount: 4))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.goal,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      if (m.workspacePath != null &&
                          m.workspacePath!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'مسیر: ${m.workspaceName ?? m.workspacePath}',
                          style: const TextStyle(
                              fontSize: 12, color: PigptColors.inkMuted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Chip(label: Text(m.statusFa)),
                      LiveStatusLine(
                        status: _busy
                            ? _live
                            : _missionLive(m, current: _live, toolHint: _toolHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'قدم‌ها'),
                const SizedBox(height: 8),
                if (m.steps.isEmpty)
                  const Text('هنوز قدمی ثبت نشده.',
                      style: TextStyle(color: PigptColors.inkMuted))
                else
                  ...m.steps.map(
                    (s) => SoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if (s.status != null)
                            Text(s.status!,
                                style: const TextStyle(
                                    color: PigptColors.inkMuted, fontSize: 12)),
                          if (s.detail != null) ...[
                            const SizedBox(height: 6),
                            MarkdownBody(data: s.detail!, selectable: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionHeader(
                  title: 'کنترل ماموریت',
                  subtitle: 'قدم بعد، تأیید حساس، تکمیل',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _act(() async {
                                return ref.read(apiClientProvider).post(
                                      ApiPaths.agentMissionNext(widget.id),
                                    );
                              }, tool: 'next'),
                      child: const Text('قدم بعد'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(() async {
                                return ref.read(apiClientProvider).post(
                                      ApiPaths.agentMissionConfirm(widget.id),
                                      data: {'confirmed': true},
                                    );
                              }),
                      child: const Text('تأیید حساس'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(() async {
                                return ref.read(apiClientProvider).post(
                                      ApiPaths.agentMissionComplete(widget.id),
                                    );
                              }),
                      child: const Text('تکمیل'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'ابزارها',
                  subtitle: 'فایل، تصویر، شروع سریع — نزدیک به وب',
                ),
                const SizedBox(height: 8),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _fileAction,
                        decoration: const InputDecoration(
                          labelText: 'عملیات فایل',
                          hintText: 'list | read | write',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(() async {
                                  return ref.read(apiClientProvider).post(
                                    ApiPaths.agentMissionToolFile(widget.id),
                                    data: {'action': _fileAction.text.trim()},
                                  );
                                }, tool: 'file'),
                        child: const Text('ابزار فایل'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(() async {
                                  return ref.read(apiClientProvider).post(
                                    ApiPaths.agentMissionToolImage(widget.id),
                                    data: {'prompt': m.goal},
                                  );
                                }, tool: 'generate_image'),
                        child: const Text('ابزار تصویر'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qsPrompt,
                        decoration: const InputDecoration(
                          labelText: 'شروع سریع (اختیاری)',
                          hintText: 'پرامپت یا خالی = هدف ماموریت',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(() async {
                                  return ref.read(apiClientProvider).post(
                                    ApiPaths.agentMissionToolQuickStart(
                                        widget.id),
                                    data: {
                                      'prompt': _qsPrompt.text.trim().isEmpty
                                          ? m.goal
                                          : _qsPrompt.text.trim(),
                                    },
                                  );
                                }, tool: 'search'),
                        child: const Text('ابزار شروع سریع'),
                      ),
                    ],
                  ),
                ),
                if (_toolOut != null) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('نتیجه ابزار',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ToolOutputView(data: _toolOut),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
