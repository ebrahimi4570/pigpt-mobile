import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/studio_catalog.dart';
import '../../core/theme.dart';
import '../../shared/widgets/ui.dart';

/// Capabilities enabled for the current user/plan. Missing API → treat primary studios as enabled.
final capabilitiesProvider = FutureProvider<Set<String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get<dynamic>(ApiPaths.capabilities);
    final set = <String>{};
    if (data is Map) {
      final caps = data['capabilities'] ?? data['enabled'] ?? data['items'];
      if (caps is List) {
        for (final c in caps) {
          if (c is String) set.add(c);
          if (c is Map && c['code'] != null) set.add('${c['code']}');
          if (c is Map && c['id'] != null) set.add('${c['id']}');
        }
      } else if (caps is Map) {
        caps.forEach((k, v) {
          if (v == true) set.add('$k');
        });
      }
    } else if (data is List) {
      for (final c in data) {
        if (c is String) set.add(c);
      }
    }
    return set;
  } on ApiException {
    // Fallback: enable primary consumer studios; secondary show as soon.
    return {
      'image_studio',
      'writing_studio',
      'media_studio',
      'document_rag',
    };
  }
});

class StudiosHubScreen extends ConsumerStatefulWidget {
  const StudiosHubScreen({super.key});

  @override
  ConsumerState<StudiosHubScreen> createState() => _StudiosHubScreenState();
}

class _StudiosHubScreenState extends ConsumerState<StudiosHubScreen> {
  final _intent = TextEditingController(
    text: 'می‌خواهم یک گزارش CSV را تحلیل کنم',
  );
  String? _suggestionTitle;
  String? _suggestionHref;
  bool _busy = false;

  @override
  void dispose() {
    _intent.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.proRouter,
        data: {'intent': _intent.text.trim()},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final s = data['suggestion'];
      if (s is Map) {
        setState(() {
          _suggestionTitle = s['title']?.toString();
          _suggestionHref = s['href']?.toString();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openTool(StudioToolDef tool, {required bool enabled}) {
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این استودیو به‌زودی فعال می‌شود')),
      );
      return;
    }
    final route = tool.routeName ?? 'studio-${tool.id}';
    context.push('/studios/$route');
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(capabilitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('استودیوها'),
        actions: [
          IconButton(
            tooltip: 'گالری',
            onPressed: () => context.push('/studios/gallery'),
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: caps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'خطا', body: '$e'),
        data: (enabled) {
          bool isOn(String? cap) {
            if (cap == null) return true;
            if (enabled.isEmpty) {
              return StudioCatalog.primaryIds.contains(
                StudioCatalog.allTools
                    .firstWhere((t) => t.capability == cap,
                        orElse: () => StudioCatalog.allTools.first)
                    .id,
              );
            }
            return enabled.contains(cap);
          }

          final primary = StudioCatalog.allTools
              .where((t) => StudioCatalog.primaryIds.contains(t.id))
              .toList();
          final more = StudioCatalog.allTools
              .where((t) => !StudioCatalog.primaryIds.contains(t.id))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'پیشنهاد مسیر',
                      subtitle: 'نیازتان را بنویسید تا استودیوی مناسب پیشنهاد شود',
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _intent),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _route,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('پیشنهاد'),
                    ),
                    if (_suggestionTitle != null) ...[
                      const SizedBox(height: 10),
                      Text('پیشنهاد: $_suggestionTitle'),
                      if (_suggestionHref != null)
                        Text(_suggestionHref!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                color: PigptColors.inkFaint, fontSize: 12)),
                    ],
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 18),
              const SectionHeader(
                title: 'ابزارهای اصلی',
                subtitle: 'تصویر، نوشتن و رسانه',
              ),
              const SizedBox(height: 10),
              ...primary.asMap().entries.map((e) {
                final t = e.value;
                final on = isOn(t.capability);
                return _StudioTile(
                  tool: t,
                  enabled: on,
                  onTap: () => _openTool(t, enabled: on),
                ).animate(delay: (40 * e.key).ms).fadeIn().slideY(begin: 0.05, end: 0);
              }),
              const SizedBox(height: 18),
              const SectionHeader(title: 'بیشتر'),
              const SizedBox(height: 10),
              ...more.map((t) {
                final on = isOn(t.capability);
                return _StudioTile(
                  tool: t,
                  enabled: on,
                  onTap: () => _openTool(t, enabled: on),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StudioTile extends StatelessWidget {
  const _StudioTile({
    required this.tool,
    required this.enabled,
    required this.onTap,
  });
  final StudioToolDef tool;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tool.label,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (!enabled) ...[
                      const SizedBox(width: 8),
                      const SoonBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(tool.blurb,
                    style: const TextStyle(
                        color: PigptColors.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.chevron_left_rounded : Icons.lock_clock_outlined,
            color: PigptColors.inkFaint,
          ),
        ],
      ),
    );
  }
}

class StudioWorkspaceScreen extends ConsumerStatefulWidget {
  const StudioWorkspaceScreen({
    super.key,
    required this.toolId,
    required this.title,
    required this.capability,
  });

  final String toolId;
  final String title;
  final String capability;

  @override
  ConsumerState<StudioWorkspaceScreen> createState() =>
      _StudioWorkspaceScreenState();
}

class _StudioWorkspaceScreenState extends ConsumerState<StudioWorkspaceScreen> {
  final _input = TextEditingController();
  String? _output;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final prompt = _input.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _output = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      Map<String, dynamic> data;
      switch (widget.toolId) {
        case 'image':
          data = await api.post(
            ApiPaths.studiosImageGenerate,
            data: {'prompt': prompt},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        case 'writing':
          data = await api.post(
            ApiPaths.studiosWritingRun,
            data: {'prompt': prompt, 'template_id': null},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        case 'coding':
          data = await api.post(
            ApiPaths.studiosCodingReview,
            data: {'code': prompt},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        case 'analytics':
          data = await api.post(
            ApiPaths.studiosDataAnalyzeCsv,
            data: {'csv_text': prompt},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        case 'edu':
          data = await api.post(
            ApiPaths.studiosEduQuiz,
            data: {'topic': prompt},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        case 'media':
          data = await api.post(
            ApiPaths.studiosMediaOcr,
            data: {'text_hint': prompt},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
          break;
        default:
          data = await api.post(
            ApiPaths.proQualityGate,
            data: {'content': prompt, 'studio': widget.toolId},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      }
      final text =
          '${data['text'] ?? data['output'] ?? data['result'] ?? data['url'] ?? data}';
      setState(() => _output = text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'ورودی استودیو…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? 'در حال اجرا…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_output != null) ...[
            const SizedBox(height: 16),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('خروجی',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SelectableText(_output!),
                  const SizedBox(height: 8),
                  const Text('آماده‌شده با PiGPT',
                      style: TextStyle(
                          color: PigptColors.inkFaint, fontSize: 12)),
                ],
              ),
            ).animate().fadeIn(),
          ],
        ],
      ),
    );
  }
}

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('گالری خروجی')),
      body: FutureBuilder(
        future: ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosGallery),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(title: 'گالری', body: '${snap.error}');
          }
          final data = snap.data;
          final list = data is List
              ? data
              : (data is Map
                  ? (data['items'] ?? data['gallery'] ?? []) as List
                  : []);
          if (list.isEmpty) {
            return const EmptyState(
              title: 'گالری خالی است',
              body: 'خروجی استودیوها اینجا جمع می‌شود.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = list[i] is Map
                  ? Map<String, dynamic>.from(list[i] as Map)
                  : <String, dynamic>{};
              return SoftCard(
                child: Text('${m['title'] ?? m['id'] ?? m}'),
              );
            },
          );
        },
      ),
    );
  }
}
