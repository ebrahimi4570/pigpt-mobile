import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/audio_player_card.dart';
import '../../shared/widgets/pigpt_markdown.dart';
import '../../shared/widgets/ui.dart';

/// Maps studio catalog id → specialized workspace (not generic textarea).
Widget studioWorkspaceFor({
  required String toolId,
  required String title,
  required String capability,
}) {
  switch (toolId) {
    case 'media':
      return const MediaStudioScreen();
    case 'coding':
      return const CodingStudioScreen();
    case 'analytics':
      return const AnalyticsStudioScreen();
    case 'edu':
      return const EduStudioScreen();
    case 'algorithms':
      return const AlgorithmsStudioScreen();
    case 'biz':
      return const BizStudioScreen();
    case 'assistant':
      return const AssistantStudioScreen();
    case 'growth':
      return const GrowthStudioScreen();
    case 'workspace':
      return const WorkspaceStudioScreen();
    case 'documents':
      return DocumentsStudioScreen(title: title);
    case 'automation':
      return AutomationStudioScreen(title: title);
    default:
      return StudioFallbackScreen(title: title, toolId: toolId);
  }
}

String _extractText(Map<String, dynamic> data) {
  for (final k in [
    'text',
    'output',
    'result',
    'review',
    'markdown',
    'material',
    'session',
    'reply',
    'report',
    'insight',
    'optimized',
    'edit_prompt',
    'yaml',
    'raw',
    'a',
    'b',
  ]) {
    final v = data[k] ?? (data['data'] is Map ? (data['data'] as Map)[k] : null);
    if (v != null && '$v'.trim().isNotEmpty && '$v' != 'null') {
      if (k == 'a' && data['b'] != null) {
        return 'نسخه A:\n${data['a']}\n\nنسخه B:\n${data['b']}';
      }
      return '$v';
    }
  }
  final nested = data['data'];
  if (nested is Map) return _extractText(Map<String, dynamic>.from(nested));
  return data.toString();
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.text, this.url});
  final String text;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('خروجی',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  HapticFeedback.lightImpact();
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          if (url != null && url!.isNotEmpty && looksLikeAudioUrl(url))
            AudioPlayerCard(
              url: url!.startsWith('http') ? url! : '${PigptBrand.apiBase}$url',
            )
          else if (url != null && url!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url!.startsWith('http')
                    ? url!
                    : '${PigptBrand.apiBase}$url',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
            PigptMarkdown(data: text),
          ] else
            PigptMarkdown(data: text),
          const SizedBox(height: 8),
          const Text(PigptBrand.readyWith,
              style: TextStyle(color: PigptColors.inkFaint, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn();
  }
}

class MediaStudioScreen extends ConsumerStatefulWidget {
  const MediaStudioScreen({super.key});

  @override
  ConsumerState<MediaStudioScreen> createState() => _MediaStudioScreenState();
}

class _MediaStudioScreenState extends ConsumerState<MediaStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _tts = TextEditingController();
  final _edit = TextEditingController();
  String? _out;
  String? _url;
  String? _error;
  bool _busy = false;
  Map<String, dynamic> _flags = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadFlags();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _tts.dispose();
    _edit.dispose();
    super.dispose();
  }

  Future<void> _loadFlags() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiPaths.studiosMediaFlags);
      if (data is Map && mounted) {
        setState(() => _flags = Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
      _url = null;
    });
    try {
      final data = await fn();
      final nested = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      setState(() {
        _out = _extractText(nested);
        _url = '${nested['url'] ?? data['url'] ?? ''}';
        if (_url!.isEmpty) _url = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndOcr() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    final f = picked?.files.single;
    if (f?.path == null) {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img == null) return;
      await _run(() => ref.read(apiClientProvider).postMultipart(
            ApiPaths.studiosMediaOcr,
            filePath: img.path,
            filename: img.name,
          ));
      return;
    }
    await _run(() => ref.read(apiClientProvider).postMultipart(
          ApiPaths.studiosMediaOcr,
          filePath: f!.path!,
          filename: f.name,
        ));
  }

  Future<void> _pickAndStt() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
    final f = picked?.files.single;
    if (f?.path == null) return;
    await _run(() => ref.read(apiClientProvider).postMultipart(
          ApiPaths.studiosMediaStt,
          filePath: f!.path!,
          filename: f.name,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'منو',
          onPressed: () => openPigptMenu(context, ref),
          icon: const Icon(Icons.menu_rounded),
        ),
        title: const Text('استودیوی رسانه'),
        actions: [
          IconButton(
            tooltip: 'بازگشت',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'OCR'),
            Tab(text: 'TTS'),
            Tab(text: 'STT'),
            Tab(text: 'ویرایش تصویر'),
            Tab(text: 'وضعیت'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                              'تصویر یا PDF را انتخاب کنید تا متن استخراج شود.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy ? null : _pickAndOcr,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('انتخاب و OCR'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _tts,
                            minLines: 3,
                            maxLines: 8,
                            decoration:
                                const InputDecoration(labelText: 'متن برای صدا'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() => ref
                                    .read(apiClientProvider)
                                    .post(
                                      ApiPaths.studiosMediaTts,
                                      data: {
                                        'text': _tts.text.trim(),
                                        'options': {'voice': 'alloy'},
                                      },
                                      parser: (d) =>
                                          Map<String, dynamic>.from(d as Map),
                                    )),
                            child: const Text('تولید صدا'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                              'فایل صوتی را انتخاب کنید یا با میکروفون ضبط کنید.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy ? null : _pickAndStt,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('آپلود و تبدیل گفتار'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _edit,
                            minLines: 3,
                            maxLines: 8,
                            decoration: const InputDecoration(
                                labelText: 'دستور ویرایش تصویر'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() => ref
                                    .read(apiClientProvider)
                                    .post(
                                      ApiPaths.studiosMediaImageEdit,
                                      data: {
                                        'text': _edit.text.trim(),
                                        'options': {
                                          'mode': 'restyle',
                                          'style': 'natural',
                                        },
                                      },
                                      parser: (d) =>
                                          Map<String, dynamic>.from(d as Map),
                                    )),
                            child: const Text('ساخت پرامپت ویرایش'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'قابلیت‌های رسانه'),
                          const SizedBox(height: 8),
                          if (_flags.isEmpty)
                            const Text('پرچم‌ها بارگذاری نشد.',
                                style: TextStyle(color: PigptColors.inkMuted))
                          else
                            ..._flags.entries.map((e) {
                              final v = e.value;
                              final on = v is Map
                                  ? v['enabled'] == true
                                  : v == true;
                              final name = v is Map
                                  ? '${v['name_fa'] ?? e.key}'
                                  : e.key;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(name),
                                trailing: Icon(
                                  on
                                      ? Icons.check_circle
                                      : Icons.lock_clock_outlined,
                                  color: on
                                      ? PigptColors.brand
                                      : PigptColors.inkFaint,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: const TextStyle(color: PigptColors.danger)),
            ),
          if (_out != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ResultCard(text: _out!, url: _url),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class CodingStudioScreen extends ConsumerStatefulWidget {
  const CodingStudioScreen({super.key});

  @override
  ConsumerState<CodingStudioScreen> createState() => _CodingStudioScreenState();
}

class _CodingStudioScreenState extends ConsumerState<CodingStudioScreen> {
  final _input = TextEditingController();
  String _mode = 'review';
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      final path = switch (_mode) {
        'scaffold' => ApiPaths.studiosCodingScaffold,
        'openapi' => ApiPaths.studiosCodingOpenapi,
        _ => ApiPaths.studiosCodingReview,
      };
      final data = await api.post<Map<String, dynamic>>(
        path,
        data: {'text': text},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'کدنویسی', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('بازبینی'),
                      selected: _mode == 'review',
                      onSelected: (_) => setState(() => _mode = 'review'),
                    ),
                    ChoiceChip(
                      label: const Text('اسکفولد'),
                      selected: _mode == 'scaffold',
                      onSelected: (_) => setState(() => _mode = 'scaffold'),
                    ),
                    ChoiceChip(
                      label: const Text('OpenAPI'),
                      selected: _mode == 'openapi',
                      onSelected: (_) => setState(() => _mode = 'openapi'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  minLines: 8,
                  maxLines: 16,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: _mode == 'review'
                        ? 'کد را اینجا بچسبانید…'
                        : 'توضیح نیازمندی…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class AnalyticsStudioScreen extends ConsumerStatefulWidget {
  const AnalyticsStudioScreen({super.key});

  @override
  ConsumerState<AnalyticsStudioScreen> createState() =>
      _AnalyticsStudioScreenState();
}

class _AnalyticsStudioScreenState extends ConsumerState<AnalyticsStudioScreen> {
  final _csv = TextEditingController();
  final _question = TextEditingController(
      text: 'خلاصه و بینش کلیدی به فارسی بده');
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _csv.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final csv = _csv.text.trim();
    if (csv.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      // Prefer JSON body when API accepts csv_text; multipart file path also exists.
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.studiosDataAnalyzeCsv,
        data: {
          'csv_text': csv,
          'text': csv,
          'question': _question.text.trim(),
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final cols = data['columns'] ?? (data['data'] is Map ? (data['data'] as Map)['columns'] : null);
      final insight = _extractText(data);
      setState(() {
        _out = cols != null ? 'ستون‌ها: $cols\n\n$insight' : insight;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'داده و گزارش', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _csv,
                  minLines: 8,
                  maxLines: 16,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'CSV',
                    hintText: 'header1,header2\n...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _question,
                  decoration: const InputDecoration(labelText: 'سؤال تحلیلی'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'تحلیل'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class EduStudioScreen extends ConsumerStatefulWidget {
  const EduStudioScreen({super.key});

  @override
  ConsumerState<EduStudioScreen> createState() => _EduStudioScreenState();
}

class _EduStudioScreenState extends ConsumerState<EduStudioScreen> {
  final _topic = TextEditingController();
  final _role = TextEditingController(text: 'توسعه‌دهنده');
  String _mode = 'quiz';
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _topic.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _topic.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final path = _mode == 'interview'
          ? ApiPaths.studiosEduInterview
          : ApiPaths.studiosEduQuiz;
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        path,
        data: {
          'text': text,
          if (_mode == 'interview')
            'options': {'role': _role.text.trim()},
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'آموزش', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'quiz', label: Text('آزمون')),
                    ButtonSegment(value: 'interview', label: Text('مصاحبه')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topic,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _mode == 'quiz' ? 'موضوع درس' : 'زمینه مصاحبه',
                  ),
                ),
                if (_mode == 'interview') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _role,
                    decoration: const InputDecoration(labelText: 'نقش شغلی'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class AlgorithmsStudioScreen extends ConsumerStatefulWidget {
  const AlgorithmsStudioScreen({super.key});

  @override
  ConsumerState<AlgorithmsStudioScreen> createState() =>
      _AlgorithmsStudioScreenState();
}

class _AlgorithmsStudioScreenState extends ConsumerState<AlgorithmsStudioScreen> {
  final _input = TextEditingController();
  String _mode = 'optimize';
  String? _industry;
  List<Map<String, dynamic>> _industries = const [];
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadIndustries();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadIndustries() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiPaths.studiosAlgorithmsIndustries);
      if (data is List && mounted) {
        setState(() {
          _industries = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (_industries.isNotEmpty) {
            _industry = '${_industries.first['id']}';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final path = switch (_mode) {
        'score' => ApiPaths.studiosAlgorithmsScore,
        'wizard' => ApiPaths.studiosAlgorithmsWizard,
        'pipeline' => ApiPaths.studiosAlgorithmsPipeline,
        _ => ApiPaths.studiosAlgorithmsOptimize,
      };
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        path,
        data: {
          'text': text,
          if (_mode == 'wizard' || _mode == 'pipeline')
            'options': {'industry': _industry ?? 'startup'},
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'الگوریتم‌ها', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in const [
                      ('optimize', 'بهینه پرامپت'),
                      ('score', 'امتیاز کیفیت'),
                      ('wizard', 'ویزارد'),
                      ('pipeline', 'پایپلاین'),
                    ])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: _mode == e.$1,
                        onSelected: (_) => setState(() => _mode = e.$1),
                      ),
                  ],
                ),
                if ((_mode == 'wizard' || _mode == 'pipeline') &&
                    _industries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _industry,
                    decoration: const InputDecoration(labelText: 'صنعت'),
                    items: _industries
                        .map((i) => DropdownMenuItem(
                              value: '${i['id']}',
                              child: Text('${i['name_fa'] ?? i['id']}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _industry = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'ورودی'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class BizStudioScreen extends ConsumerStatefulWidget {
  const BizStudioScreen({super.key});

  @override
  ConsumerState<BizStudioScreen> createState() => _BizStudioScreenState();
}

class _BizStudioScreenState extends ConsumerState<BizStudioScreen> {
  final _input = TextEditingController();
  final _brand = TextEditingController();
  String _mode = 'invoice';
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final path = switch (_mode) {
        'support' => ApiPaths.studiosBizSupport,
        'report' => ApiPaths.studiosBizDailyReport,
        _ => ApiPaths.studiosBizInvoice,
      };
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        path,
        data: {
          'text': text,
          'options': {
            if (_mode == 'invoice') 'kind': 'invoice',
            if (_mode == 'support') 'brand_knowledge': _brand.text.trim(),
          },
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'کسب‌وکار ایران', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const [
                      ('invoice', 'فاکتور'),
                      ('support', 'پشتیبانی'),
                      ('report', 'گزارش روزانه'),
                    ])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: _mode == e.$1,
                        onSelected: (_) => setState(() => _mode = e.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_mode == 'support')
                  TextField(
                    controller: _brand,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'دانش برند'),
                  ),
                if (_mode == 'support') const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: _mode == 'support'
                        ? 'سؤال مشتری'
                        : 'جزئیات',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class AssistantStudioScreen extends ConsumerStatefulWidget {
  const AssistantStudioScreen({super.key});

  @override
  ConsumerState<AssistantStudioScreen> createState() =>
      _AssistantStudioScreenState();
}

class _AssistantStudioScreenState extends ConsumerState<AssistantStudioScreen> {
  final _topic = TextEditingController();
  final _projectName = TextEditingController();
  List<dynamic> _projects = const [];
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _topic.dispose();
    _projectName.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiPaths.studiosAssistantProjects);
      if (!mounted) return;
      setState(() {
        _projects = data is List
            ? data
            : (data is Map ? (data['projects'] ?? data['items'] ?? []) as List : []);
      });
    } catch (_) {}
  }

  Future<void> _multiAgent() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.studiosAssistantMultiAgent,
        data: {'text': topic, 'topic': topic},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProject() async {
    final name = _projectName.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.studiosAssistantProjects,
        data: {'name': name, 'title': name},
      );
      _projectName.clear();
      await _loadProjects();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'دستیار پروژه‌ای', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'چندایجنت'),
                const SizedBox(height: 8),
                TextField(
                  controller: _topic,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'موضوع'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _multiAgent,
                  child: Text(_busy ? '…' : 'اجرای چندایجنت'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'پروژه‌ها'),
                const SizedBox(height: 8),
                TextField(
                  controller: _projectName,
                  decoration: const InputDecoration(labelText: 'نام پروژه'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: _createProject, child: const Text('ایجاد')),
                const SizedBox(height: 8),
                if (_projects.isEmpty)
                  const Text('پروژه‌ای نیست.',
                      style: TextStyle(color: PigptColors.inkMuted))
                else
                  ..._projects.map((p) {
                    final m = p is Map
                        ? Map<String, dynamic>.from(p)
                        : <String, dynamic>{};
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${m['name'] ?? m['title'] ?? m['id']}'),
                    );
                  }),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class GrowthStudioScreen extends ConsumerStatefulWidget {
  const GrowthStudioScreen({super.key});

  @override
  ConsumerState<GrowthStudioScreen> createState() => _GrowthStudioScreenState();
}

class _GrowthStudioScreenState extends ConsumerState<GrowthStudioScreen> {
  final _input = TextEditingController();
  String _mode = 'filter';
  String? _out;
  String? _error;
  bool _busy = false;
  List<dynamic> _market = const [];

  @override
  void initState() {
    super.initState();
    _loadMarket();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadMarket() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<dynamic>(ApiPaths.studiosMarketplace);
      if (!mounted) return;
      setState(() {
        _market = data is List
            ? data
            : (data is Map ? (data['items'] ?? []) as List : []);
      });
    } catch (_) {}
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final path = _mode == 'ab'
          ? ApiPaths.studiosSafetyAb
          : ApiPaths.studiosSafetyFilter;
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        path,
        data: {'text': text},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'ایمنی و رشد', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'filter', label: Text('فیلتر ایمنی')),
                    ButtonSegment(value: 'ab', label: Text('A/B')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'متن'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'اجرا'),
                ),
              ],
            ),
          ),
          if (_market.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'بازارچه قالب'),
            const SizedBox(height: 8),
            ..._market.take(8).map((raw) {
              final m = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              return SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Text('${m['name_fa'] ?? m['code'] ?? m}'),
              );
            }),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class WorkspaceStudioScreen extends ConsumerStatefulWidget {
  const WorkspaceStudioScreen({super.key});

  @override
  ConsumerState<WorkspaceStudioScreen> createState() =>
      _WorkspaceStudioScreenState();
}

class _WorkspaceStudioScreenState extends ConsumerState<WorkspaceStudioScreen> {
  final _name = TextEditingController();
  List<dynamic> _teams = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosTeam);
      if (!mounted) return;
      setState(() {
        _teams = data is List
            ? data
            : (data is Map ? (data['teams'] ?? data['items'] ?? []) as List : []);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.studiosTeam,
        data: {'name': name},
      );
      _name.clear();
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'فضای کاری سازمان', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'تیم‌ها',
                  subtitle: 'ایجاد و مشاهده فضای کاری سطح کاربر',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'نام تیم'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('ایجاد تیم'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          if (_teams.isEmpty)
            const EmptyState(
              title: 'تیمی نیست',
              body: 'اولین فضای کاری را بسازید.',
            )
          else
            ..._teams.map((raw) {
              final m = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              return SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Text('${m['name'] ?? m['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            }),
        ],
      ),
    );
  }
}

class DocumentsStudioScreen extends ConsumerStatefulWidget {
  const DocumentsStudioScreen({super.key, required this.title});
  final String title;

  @override
  ConsumerState<DocumentsStudioScreen> createState() =>
      _DocumentsStudioScreenState();
}

class _DocumentsStudioScreenState extends ConsumerState<DocumentsStudioScreen> {
  final _question = TextEditingController();
  List<Map<String, dynamic>> _docs = const [];
  final _selected = <String>{};
  String? _out;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosDocuments);
      final list = data is List
          ? data
          : (data is Map ? (data['documents'] ?? data['items'] ?? []) as List : []);
      final docs = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() => _docs = docs);
      final pending = docs.any((d) {
        final s = '${d['status']}';
        return s == 'pending' || s == 'processing' || s == 'queued';
      });
      _poll?.cancel();
      if (pending) {
        _poll = Timer(const Duration(seconds: 3), _load);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md', 'csv'],
    );
    final f = picked?.files.single;
    if (f?.path == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postMultipart(
            ApiPaths.studiosDocuments,
            filePath: f!.path!,
            filename: f.name,
            fields: {'title': f.name},
          );
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ask() async {
    final q = _question.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    final api = ref.read(apiClientProvider);
    var buffer = '';
    try {
      await for (final event in api.postSse(
        ApiPaths.studiosRagChat,
        data: {
          'message': q,
          if (_selected.isNotEmpty) 'document_ids': _selected.toList(),
        },
      )) {
        if (event.event == 'token') {
          buffer += '${event.data['text'] ?? ''}';
          setState(() => _out = buffer);
        } else if (event.event == 'error') {
          setState(() => _error =
              '${event.data['error_message_fa'] ?? event.data['message_fa'] ?? event.data['detail'] ?? 'خطا'}');
          break;
        }
      }
      if (buffer.isEmpty && _out == null) {
        final data = await api.post<Map<String, dynamic>>(
          ApiPaths.studiosRagChat,
          data: {
            'message': q,
            if (_selected.isNotEmpty) 'document_ids': _selected.toList(),
          },
          parser: (d) => Map<String, dynamic>.from(d as Map),
        );
        setState(() => _out = _extractText(data));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PigptAppBar(title: widget.title, showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'اسناد و دانش',
                  subtitle: 'PDF / TXT / MD / CSV — ایندکس و پرسش با استناد',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('آپلود سند'),
                ),
                const SizedBox(height: 8),
                if (_docs.isEmpty)
                  Text('سندی نیست — ابتدا فایل آپلود کنید.',
                      style: TextStyle(
                          color: PigptColors.mutedOf(context), fontSize: 12))
                else
                  ..._docs.map((d) {
                    final id = '${d['id'] ?? ''}';
                    final st = '${d['status'] ?? ''}';
                    final ready = st == 'ready';
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(id),
                      onChanged: ready
                          ? (v) => setState(() {
                                if (v == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              })
                          : null,
                      title: Text('${d['title'] ?? d['filename'] ?? id}',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        st == 'ready'
                            ? 'آماده'
                            : (st == 'pending' || st == 'processing'
                                ? 'در حال ایندکس…'
                                : st),
                        style: TextStyle(
                          fontSize: 11,
                          color: PigptColors.mutedOf(context),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                TextField(
                  controller: _question,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'سؤال از اسناد'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _ask,
                  child: Text(_busy ? '…' : 'پرسش'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class AutomationStudioScreen extends ConsumerStatefulWidget {
  const AutomationStudioScreen({super.key, required this.title});
  final String title;

  @override
  ConsumerState<AutomationStudioScreen> createState() =>
      _AutomationStudioScreenState();
}

class _AutomationStudioScreenState
    extends ConsumerState<AutomationStudioScreen> {
  final _input = TextEditingController();
  String? _out;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _out = null;
    });
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.proQualityGate,
        data: {
          'content': text,
          'studio': 'automation',
          'intent': 'workflow',
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      setState(() => _out = _extractText(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PigptAppBar(title: widget.title, showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'اتوماسیون',
                  subtitle: 'شرح گردش‌کار کاربر → پیشنهاد مراحل و کیفیت',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _input,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: 'مثلاً: هر صبح خلاصه تیکت‌های پشتیبانی…',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '…' : 'طراحی ورکفلو'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PigptColors.danger)),
          ],
          if (_out != null) ...[
            const SizedBox(height: 16),
            _ResultCard(text: _out!),
          ],
        ],
      ),
    );
  }
}

class StudioFallbackScreen extends StatelessWidget {
  const StudioFallbackScreen({
    super.key,
    required this.title,
    required this.toolId,
  });
  final String title;
  final String toolId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PigptAppBar(title: title, showBack: true),
      body: EmptyState(
        title: title,
        body: 'استودیوی «$toolId» هنوز API اختصاصی ندارد.',
      ),
    );
  }
}
