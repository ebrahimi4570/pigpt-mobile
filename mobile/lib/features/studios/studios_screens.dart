import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/studio_catalog.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';
import 'studio_workspaces.dart';

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
        loading: () => const ListShimmer(itemCount: 5),
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

class StudioWorkspaceScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return studioWorkspaceFor(
      toolId: toolId,
      title: title,
      capability: capability,
    );
  }
}

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosGallery);
      final list = data is List
          ? data
          : (data is Map
              ? (data['items'] ?? data['gallery'] ?? []) as List
              : []);
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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

  String? _previewUrl(Map<String, dynamic> m) {
    final u = m['preview_url'] ?? m['url'] ?? m['image_url'] ?? m['thumb_url'];
    if (u == null || '$u'.isEmpty) return null;
    final s = '$u';
    if (s.startsWith('http')) return s;
    return '${PigptBrand.apiBase}$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('گالری خروجی')),
      body: _loading
          ? const GridShimmer()
          : _error != null
              ? EmptyState(
                  title: 'گالری',
                  body: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('تلاش دوباره')),
                )
              : _items.isEmpty
                  ? const EmptyState(
                      title: 'گالری خالی است',
                      body: 'خروجی استودیوها اینجا جمع می‌شود.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final m = _items[i];
                          final url = _previewUrl(m);
                          final title =
                              '${m['title_fa'] ?? m['title'] ?? m['id'] ?? 'آیتم'}';
                          final previewText =
                              '${m['preview_text'] ?? m['text'] ?? ''}';
                          return SoftCard(
                            padding: EdgeInsets.zero,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(title),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (url != null)
                                          Image.network(url,
                                              errorBuilder: (_, __, ___) =>
                                                  const SizedBox.shrink()),
                                        if (previewText.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(previewText),
                                        ],
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('بستن'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    child: url != null
                                        ? Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: PigptColors.brandSoft,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                  Icons.broken_image_outlined),
                                            ),
                                          )
                                        : Container(
                                            color: PigptColors.brandSoft,
                                            padding: const EdgeInsets.all(12),
                                            alignment: Alignment.center,
                                            child: Text(
                                              previewText.isNotEmpty
                                                  ? previewText
                                                  : title,
                                              maxLines: 6,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

