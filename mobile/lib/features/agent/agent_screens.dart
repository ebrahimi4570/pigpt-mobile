import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/tool_output.dart';
import '../../shared/widgets/ui.dart';

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
  bool _busy = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final goal = _goal.text.trim();
    if (goal.isEmpty) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.agentMissions,
        data: {'goal': goal, 'confirm_sensitive': true},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      _goal.clear();
      ref.invalidate(agentMissionsProvider);
      if (mounted) context.push('/agent/${data['id']}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(agentMissionsProvider);
    return Scaffold(
      appBar: const PigptAppBar(title: 'ماموریت‌های ایجنت', showBack: true),
      body: async.when(
        loading: () => const ListShimmer(itemCount: 5),
        error: (e, _) => EmptyState(
          title: 'خطا در بارگذاری ماموریت‌ها',
          body: '$e',
        ),
        data: (missions) {
          if (missions == null) {
            return const EmptyState(
              title: 'ایجنت ماموریتی به‌زودی',
              body:
                  'API ماموریت روی این استقرار فعال نیست. حالت ایجنت داخل گفتگو همچنان در دسترس است.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'هدف جدید',
                      subtitle:
                          'ایجنت = یک هدف تا تکمیل · گفتگو = پرسش‌وپاسخ آزاد',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _goal,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'مثلاً: گزارش کوتاه بازار رقبای محلی…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _create,
                      child: const Text('ایجاد ماموریت'),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 20),
              const SectionHeader(title: 'تاریخچه'),
              const SizedBox(height: 10),
              if (missions.isEmpty)
                const EmptyState(
                  title: 'ماموریتی نیست',
                  body: 'اولین هدف را بالا بنویسید.',
                )
              else
                ...missions.asMap().entries.map((e) {
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

  Future<void> _act(Future<dynamic> Function() fn) async {
    setState(() {
      _busy = true;
      _toolOut = null;
    });
    try {
      final res = await fn();
      if (res != null) {
        setState(() => _toolOut = res);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
                      const SizedBox(height: 8),
                      Chip(label: Text(m.statusFa)),
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
                              }),
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
                                }),
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
                                }),
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
                                }),
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
