import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/live_status.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/live_status_line.dart';
import '../../shared/widgets/pigpt_markdown.dart';
import '../../shared/widgets/ui.dart';

/// Writing studio aligned with web `/app/writing`: templates, steps, streamed draft.
class WritingStudioScreen extends ConsumerStatefulWidget {
  const WritingStudioScreen({super.key});

  @override
  ConsumerState<WritingStudioScreen> createState() =>
      _WritingStudioScreenState();
}

class _WritingStudioScreenState extends ConsumerState<WritingStudioScreen> {
  final _topic = TextEditingController();
  final _audience = TextEditingController();
  final _notes = TextEditingController();
  final _previous = TextEditingController();

  List<WritingTemplate> _templates = const [];
  String? _templateId;
  String? _stepId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _output = '';
  LiveStatus _live = const LiveStatus();
  String? _seo;
  String? _exportHint;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _topic.dispose();
    _audience.dispose();
    _notes.dispose();
    _previous.dispose();
    super.dispose();
  }

  WritingTemplate? get _current {
    if (_templateId == null) return null;
    for (final t in _templates) {
      if (t.id == _templateId) return t;
    }
    return null;
  }

  Future<void> _loadTemplates() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<dynamic>(ApiPaths.studiosWritingTemplates);
      final list = data is List
          ? data
          : (data is Map
              ? (data['templates'] ?? data['items'] ?? []) as List
              : <dynamic>[]);
      final templates = list
          .whereType<Map>()
          .map((e) => WritingTemplate.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        if (templates.isNotEmpty) {
          _templateId = templates.first.id;
          _stepId = templates.first.steps.isNotEmpty
              ? templates.first.steps.first.id
              : null;
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _templates = const [];
        _templateId = null;
        _stepId = null;
      });
    }
  }

  void _selectTemplate(String id) {
    final t = _templates.firstWhere((e) => e.id == id, orElse: () => _templates.first);
    setState(() {
      _templateId = id;
      _stepId = t.steps.isNotEmpty ? t.steps.first.id : null;
    });
  }

  Future<void> _run() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty || _templateId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _output = '';
      _live = const LiveStatus(phase: LivePhase.waiting);
    });
    _cancel = CancelToken();
    final api = ref.read(apiClientProvider);
    var buffer = '';
    try {
      await for (final event in api.postSse(
        ApiPaths.studiosWritingRun,
        data: {
          'template_id': _templateId,
          if (_stepId != null) 'step_id': _stepId,
          'topic': topic,
          'audience': _audience.text.trim(),
          'notes': _notes.text.trim(),
          'previous': _previous.text.trim(),
        },
        cancelToken: _cancel,
      )) {
        if (event.event == 'token') {
          buffer += '${event.data['text'] ?? ''}';
          setState(() {
            _output = buffer;
            if (_live.phase == LivePhase.waiting ||
                _live.phase == LivePhase.thinking) {
              _live = const LiveStatus(phase: LivePhase.writing);
            }
          });
        } else if (event.event == 'error') {
          setState(() {
            _error =
                '${event.data['error_message_fa'] ?? event.data['message_fa'] ?? event.data['detail'] ?? 'خطا'}';
          });
          break;
        }
      }
      if (buffer.isNotEmpty) {
        _previous.text = buffer;
        setState(() => _output = buffer);
      }
      await ref.read(authControllerProvider.notifier).refreshMe();
    } on StreamCancelled {
      setState(() => _busy = false);
    } on ApiException catch (e) {
      // Non-stream JSON fallback if endpoint returns plain JSON.
      try {
        final data = await api.post<Map<String, dynamic>>(
          ApiPaths.studiosWritingRun,
          data: {
            'template_id': _templateId,
            if (_stepId != null) 'step_id': _stepId,
            'topic': topic,
            'audience': _audience.text.trim(),
            'notes': _notes.text.trim(),
            'previous': _previous.text.trim(),
          },
          parser: (d) => Map<String, dynamic>.from(d as Map),
        );
        final text =
            '${data['text'] ?? data['output'] ?? data['result'] ?? ''}';
        if (text.isNotEmpty) {
          _previous.text = text;
          setState(() {
            _output = text;
            _error = null;
          });
        } else {
          setState(() => _error = e.message);
        }
      } on ApiException catch (e2) {
        setState(() => _error = e2.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_error != null) {
            _live = LiveStatus(phase: LivePhase.error, errorFa: _error);
          } else if (_output.trim().isNotEmpty) {
            _live = const LiveStatus(phase: LivePhase.ready);
          } else {
            _live = const LiveStatus();
          }
        });
      }
    }
  }

  void _stop() {
    _cancel?.cancel('user');
    _cancel = null;
    setState(() {
      _busy = false;
      _live = _output.trim().isEmpty
          ? const LiveStatus()
          : const LiveStatus(phase: LivePhase.ready);
    });
  }

  Future<void> _seoScore() async {
    final text = _output.isNotEmpty ? _output : _previous.text.trim();
    if (text.isEmpty) return;
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.proWritingSeo,
        data: {
          'title': _topic.text.trim(),
          'text': text,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _seo = '${data['score'] ?? data['seo'] ?? data}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _export() async {
    final text = _output.isNotEmpty ? _output : _previous.text.trim();
    if (text.isEmpty) return;
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.proWritingExport,
        data: {
          'title': _topic.text.trim().isEmpty ? 'خروجی نوشتار' : _topic.text.trim(),
          'text': text,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final md = data['markdown'];
      final html = data['html'];
      final mdUrl = md is Map ? md['url'] : data['markdown_url'];
      final htmlUrl = html is Map ? html['url'] : data['html_url'];
      setState(() {
        _exportHint = [
          if (mdUrl != null) 'Markdown: $mdUrl',
          if (htmlUrl != null) 'HTML: $htmlUrl',
        ].join('\n');
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    String stepLabel = _stepId ?? 'مرحله';
    if (current != null) {
      for (final s in current.steps) {
        if (s.id == _stepId) {
          stepLabel = s.name;
          break;
        }
      }
    }

    return Scaffold(
      appBar: const PigptAppBar(title: 'استودیوی نوشتن', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'جریان قالبی',
                        subtitle:
                            'قالب و مرحله را انتخاب کنید؛ هر خروجی پایهٔ مرحله بعد است.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _templateId != null &&
                                _templates.any((t) => t.id == _templateId)
                            ? _templateId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'قالب نوشتن'),
                        items: _templates
                            .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _selectTemplate(v);
                        },
                      ),
                      if (current?.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          current!.description!,
                          style: const TextStyle(
                              color: PigptColors.inkMuted, fontSize: 13),
                        ),
                      ],
                      if (current != null && current.steps.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('مراحل جریان',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < current.steps.length; i++)
                              ChoiceChip(
                                label: Text('${i + 1}. ${current.steps[i].name}'),
                                selected: current.steps[i].id == _stepId,
                                onSelected: (_) => setState(
                                    () => _stepId = current.steps[i].id),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topic,
                        decoration: const InputDecoration(
                          labelText: 'موضوع',
                          hintText:
                              'مثلاً: راهنمای انتخاب کفش ورزشی برای دویدن',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _audience,
                        decoration: const InputDecoration(
                          labelText: 'مخاطب',
                          hintText: 'مثلاً: مبتدیان علاقه‌مند به دویدن',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'نکات و محدودیت‌ها',
                          hintText: 'لحن، طول، کلمات ممنوع، CTA…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _previous,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'خروجی مرحله قبل',
                          hintText:
                              'پس از اجرای یک مرحله اینجا پر می‌شود — قابل ویرایش.',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _run,
                        child: Text('اجرای مرحله «$stepLabel»'),
                      ),
                      LiveStatusLine(status: _live),
                      if (_busy) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('توقف استریم'),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: PigptColors.danger)),
                ],
                if (_busy || _output.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('پیش‌نویس',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            if (_output.isNotEmpty)
                              IconButton(
                                tooltip: 'کپی',
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _output));
                                  HapticFeedback.selectionClick();
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_output.isEmpty && _busy)
                          LiveStatusLine(
                            status: _live.phase == LivePhase.idle
                                ? const LiveStatus(phase: LivePhase.waiting)
                                : _live,
                            compact: true,
                          )
                        else
                          PigptMarkdown(data: _output),
                        if (_output.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _seoScore,
                                child: const Text('امتیاز SEO'),
                              ),
                              OutlinedButton(
                                onPressed: _export,
                                child: const Text('خروجی Markdown/HTML'),
                              ),
                            ],
                          ),
                        ],
                        if (_seo != null) ...[
                          const SizedBox(height: 8),
                          Text('SEO: $_seo',
                              style: TextStyle(
                                  color: PigptColors.mutedOf(context),
                                  fontSize: 12)),
                        ],
                        if (_exportHint != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            _exportHint!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          PigptBrand.readyWith,
                          style: TextStyle(
                              color: PigptColors.inkFaint, fontSize: 12),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                ],
              ],
            ),
    );
  }
}
