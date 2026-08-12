import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';

final quickStartCardsProvider = FutureProvider<List<QuickStartCard>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<dynamic>(ApiPaths.quickStartCards);
  List list;
  List quality = const [];
  if (data is Map) {
    list = (data['cards'] ?? data['items'] ?? data['data'] ?? []) as List;
    quality = (data['quality_options'] as List?) ?? const [];
  } else if (data is List) {
    list = data;
  } else {
    list = const [];
  }
  return list.whereType<Map>().map((e) {
    final map = Map<String, dynamic>.from(e);
    if (quality.isNotEmpty && map['quality_options'] == null) {
      map['quality_options'] = quality;
    }
    return QuickStartCard.fromJson(map);
  }).toList();
});

final quickStartHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get<dynamic>(ApiPaths.quickStartHistory);
    if (data is List) return data;
    if (data is Map) {
      return (data['items'] ?? data['history'] ?? data['data'] ?? []) as List;
    }
  } catch (_) {}
  return const [];
});

class QuickStartHubScreen extends ConsumerWidget {
  const QuickStartHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(quickStartCardsProvider);
    final history = ref.watch(quickStartHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('شروع سریع')),
      body: cards.when(
        loading: () => const ListShimmer(itemCount: 6),
        error: (e, _) => EmptyState(
          title: 'کارت‌ها در دسترس نیست',
          body: '$e',
          action: FilledButton(
            onPressed: () => ref.invalidate(quickStartCardsProvider),
            child: const Text('تلاش دوباره'),
          ),
        ),
        data: (list) {
          final shown = list.take(6).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quickStartCardsProvider);
              ref.invalidate(quickStartHistoryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeader(
                  title: 'ویزاردهای آماده',
                  subtitle: 'شش مسیر سریع برای تولید متن یا تصویر',
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  const EmptyState(
                    title: 'کارتی نیست',
                    body: 'کارت‌های شروع سریع از سرور نیامد.',
                  )
                else
                  ...shown.asMap().entries.map((e) {
                    final c = e.value;
                    return SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      onTap: () => context.push('/quick-start/${c.id}'),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PigptColors.brandSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              c.kind == 'image'
                                  ? Icons.image_outlined
                                  : Icons.edit_note_rounded,
                              color: PigptColors.brand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                if (c.description != null)
                                  Text(
                                    c.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: PigptColors.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded),
                        ],
                      ),
                    )
                        .animate(delay: (40 * e.key).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0);
                  }),
                const SizedBox(height: 18),
                const SectionHeader(title: 'تاریخچه'),
                const SizedBox(height: 8),
                history.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text('هنوز اجرایی ثبت نشده.',
                          style: TextStyle(color: PigptColors.inkMuted));
                    }
                    return Column(
                      children: items.take(8).map((raw) {
                        final m = raw is Map
                            ? Map<String, dynamic>.from(raw)
                            : <String, dynamic>{};
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${m['title'] ?? m['card_id'] ?? 'اجرا'}'),
                          subtitle:
                              Text('${m['created_at'] ?? m['status'] ?? ''}'),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class QuickStartWizardScreen extends ConsumerStatefulWidget {
  const QuickStartWizardScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<QuickStartWizardScreen> createState() =>
      _QuickStartWizardScreenState();
}

class _QuickStartWizardScreenState
    extends ConsumerState<QuickStartWizardScreen> {
  QuickStartCard? _card;
  final _values = <String, TextEditingController>{};
  String _quality = 'fast';
  bool _busy = false;
  String? _result;
  String? _imageUrl;
  String? _error;
  String? _jobId;
  List<Map<String, dynamic>> _followUps = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>(
        ApiPaths.quickStartCard(widget.cardId),
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final cardJson = data['card'] is Map
          ? Map<String, dynamic>.from(data['card'] as Map)
          : data;
      final card = QuickStartCard.fromJson(cardJson);
      for (final f in card.fields) {
        _values[f.id] = TextEditingController();
      }
      final fus = data['follow_ups'];
      setState(() {
        _card = card;
        _quality = card.qualityOptions.isNotEmpty
            ? card.qualityOptions.first
            : 'fast';
        if (fus is List) {
          _followUps = fus
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _run({String? followUp}) async {
    final card = _card;
    if (card == null) return;
    setState(() {
      _busy = true;
      _error = null;
      if (followUp == null) {
        _result = null;
        _imageUrl = null;
      }
    });
    try {
      final fields = <String, dynamic>{};
      for (final e in _values.entries) {
        fields[e.key] = e.value.text.trim();
      }
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.quickStartRun,
        data: {
          'card_id': card.id,
          'fields': fields,
          'quality': _quality,
          if (followUp != null) 'follow_up': followUp,
          if (followUp != null && _result != null) 'previous_text': _result,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final fus = data['follow_ups'];
      if (fus is List) {
        _followUps = fus
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final kind = '${data['kind'] ?? card.kind}';
      final text = '${data['copy_all'] ?? data['raw'] ?? data['text'] ?? data['output'] ?? data['result'] ?? ''}';
      final sections = data['sections'];
      if (sections is List && sections.isNotEmpty) {
        final buf = StringBuffer();
        for (final s in sections) {
          if (s is Map) {
            buf.writeln(s['title'] ?? '');
            buf.writeln(s['body'] ?? s['text'] ?? '');
            buf.writeln();
          }
        }
        setState(() => _result = buf.toString().trim().isNotEmpty
            ? buf.toString().trim()
            : text);
      } else if (text.isNotEmpty) {
        setState(() => _result = text);
      }

      final img = data['image_url'] ??
          data['url'] ??
          (data['job'] is Map ? (data['job'] as Map)['image_url'] : null) ??
          (data['job'] is Map ? (data['job'] as Map)['url'] : null);
      if (img != null && '$img'.isNotEmpty) {
        setState(() => _imageUrl = '$img');
      }

      final jobId = data['job_id']?.toString() ??
          (data['job'] is Map ? '${(data['job'] as Map)['id']}' : null);
      if ((_result == null || _result!.isEmpty) &&
          _imageUrl == null &&
          jobId != null) {
        _jobId = jobId;
        _startPoll(jobId);
      } else if (_result == null &&
          _imageUrl == null &&
          kind != 'image' &&
          data.isNotEmpty) {
        setState(() => _result = data.toString());
      }
      ref.invalidate(quickStartHistoryProvider);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPoll(String jobId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final api = ref.read(apiClientProvider);
        final data = await api.get<Map<String, dynamic>>(
          ApiPaths.quickStartJob(jobId),
          parser: (d) => Map<String, dynamic>.from(d as Map),
        );
        final job = data['job'] is Map
            ? Map<String, dynamic>.from(data['job'] as Map)
            : data;
        final status = '${job['status'] ?? data['status'] ?? ''}';
        final text =
            '${job['text'] ?? job['output'] ?? job['result'] ?? data['text'] ?? data['output'] ?? ''}';
        final img = job['image_url'] ??
            job['url'] ??
            job['result_url'] ??
            data['image_url'] ??
            data['url'];
        if (img != null && '$img'.isNotEmpty) {
          _poll?.cancel();
          if (mounted) {
            setState(() {
              _imageUrl = '$img'.startsWith('http')
                  ? '$img'
                  : '${PigptBrand.apiBase}$img';
              if (text.isNotEmpty) _result = text;
            });
          }
        } else if (status == 'completed' || text.isNotEmpty) {
          _poll?.cancel();
          if (mounted) {
            setState(() => _result = text.isNotEmpty ? text : 'انجام شد');
          }
        } else if (status == 'failed') {
          _poll?.cancel();
          if (mounted) {
            setState(() =>
                _error = '${job['error_message_fa'] ?? data['error_message_fa'] ?? 'ناموفق'}');
          }
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: Text(card?.title ?? 'ویزارد')),
      body: card == null
          ? (_error != null
              ? EmptyState(title: 'خطا', body: _error)
              : const ListShimmer(itemCount: 4))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (card.description != null)
                  Text(card.description!,
                      style: const TextStyle(color: PigptColors.inkMuted)),
                const SizedBox(height: 16),
                ...card.fields.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _values[f.id],
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: f.hint,
                      ),
                      minLines: f.type == 'textarea' ? 3 : 1,
                      maxLines: f.type == 'textarea' ? 6 : 1,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text('کیفیت', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: card.qualityOptions.map((q) {
                    return ChoiceChip(
                      label: Text(q),
                      selected: _quality == q,
                      onSelected: (_) => setState(() => _quality = q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : () => _run(),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('اجرا'),
                ),
                if (_jobId != null && _result == null && _imageUrl == null) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('در حال آماده‌سازی خروجی…'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: PigptColors.danger)),
                ],
                if (_imageUrl != null) ...[
                  const SizedBox(height: 20),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تصویر',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrl!.startsWith('http')
                                ? _imageUrl!
                                : '${PigptBrand.apiBase}$_imageUrl',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                                'پیش‌نمایش تصویر در دسترس نیست'),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('خروجی',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: _result!));
                                HapticFeedback.lightImpact();
                              },
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                        SelectableText(_result!),
                        const SizedBox(height: 8),
                        const Text(PigptBrand.readyWith,
                            style: TextStyle(
                                color: PigptColors.inkFaint, fontSize: 12)),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                ],
                if (_followUps.isNotEmpty &&
                    (_result != null || _imageUrl != null)) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'ادامه‌ها'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _followUps.map((fu) {
                      final id = '${fu['id'] ?? fu['key'] ?? ''}';
                      final label =
                          '${fu['label_fa'] ?? fu['label'] ?? fu['title'] ?? id}';
                      return ActionChip(
                        label: Text(label),
                        onPressed: _busy
                            ? null
                            : () => _run(followUp: id.isEmpty ? 'retry' : id),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
    );
  }
}
