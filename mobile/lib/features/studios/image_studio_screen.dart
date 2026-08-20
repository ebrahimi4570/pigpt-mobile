import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/live_status.dart';
import '../../core/media_io.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/fullscreen_image.dart';
import '../../shared/widgets/live_status_line.dart';
import '../../shared/widgets/ui.dart';

class ImageStudioScreen extends ConsumerStatefulWidget {
  const ImageStudioScreen({super.key});

  @override
  ConsumerState<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends ConsumerState<ImageStudioScreen> {
  final _prompt = TextEditingController();
  final _editPrompt = TextEditingController();
  final _brandName = TextEditingController();
  final _brandColors = TextEditingController();
  final _brandWords = TextEditingController();
  List<ImagePreset> _presets = const [];
  List<Map<String, dynamic>> _jobs = const [];
  String? _presetId;
  bool _loadingPresets = true;
  bool _busy = false;
  String? _error;
  String? _msg;
  String? _resultUrl;
  String? _resultText;
  String? _revisedPrompt;
  int _batchCount = 3;
  Timer? _poll;
  LiveStatus _live = const LiveStatus();

  @override
  void initState() {
    super.initState();
    _loadPresets();
    _loadJobs();
    _loadBrand();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _prompt.dispose();
    _editPrompt.dispose();
    _brandName.dispose();
    _brandColors.dispose();
    _brandWords.dispose();
    super.dispose();
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${PigptBrand.apiBase}$raw';
    return raw;
  }

  Future<void> _loadPresets() async {
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosImagePresets);
      final list = data is List
          ? data
          : (data is Map ? (data['presets'] ?? data['items'] ?? []) as List : []);
      final presets = list
          .whereType<Map>()
          .map((e) => ImagePreset.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _presets = presets;
        _presetId = presets.isNotEmpty ? presets.first.id : null;
        _loadingPresets = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingPresets = false;
        _presets = const [];
        _presetId = null;
      });
    }
  }

  Future<void> _loadBrand() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(ApiPaths.proBrandKit,
              parser: (d) => Map<String, dynamic>.from(d as Map));
      _brandName.text = '${data['brand_name'] ?? data['name'] ?? ''}';
      final colors = data['colors'];
      _brandColors.text = colors is List ? colors.join(', ') : '${colors ?? ''}';
      final words = data['forbidden_words'];
      _brandWords.text = words is List ? words.join(', ') : '${words ?? ''}';
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.studiosImageJobs);
      final list = data is List
          ? data
          : (data is Map ? (data['jobs'] ?? data['items'] ?? []) as List : []);
      final jobs = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      final pending = jobs.any((j) {
        final s = '${j['status']}';
        return s == 'queued' || s == 'running';
      });
      LiveStatus nextLive = _live;
      if (pending && _live.phase != LivePhase.error) {
        final first = jobs.firstWhere(
          (j) {
            final s = '${j['status']}';
            return s == 'queued' || s == 'running';
          },
          orElse: () => const <String, dynamic>{},
        );
        final st = '${first['status']}';
        final pct = realPercentOf(first['progress'] ?? first['percent']);
        nextLive = LiveStatus(
          phase: st == 'queued' ? LivePhase.queued : LivePhase.generating,
          percent: pct,
        );
      }
      setState(() {
        _jobs = jobs;
        _live = nextLive;
      });
      _poll?.cancel();
      if (pending) {
        _poll = Timer(const Duration(seconds: 3), _loadJobs);
      }
      final latest = jobs.cast<Map<String, dynamic>?>().firstWhere(
            (j) => '${j?['status']}' == 'succeeded',
            orElse: () => null,
          );
      if (latest != null) {
        final payload = latest['output_payload'] is Map
            ? Map<String, dynamic>.from(latest['output_payload'] as Map)
            : latest;
        final url = '${payload['url'] ?? latest['url'] ?? ''}';
        if (url.isNotEmpty) {
          setState(() => _resultUrl = _resolveUrl(url));
        }
      }
    } on ApiException {
      // Jobs API may be missing on some deploys — generate still works.
    }
  }

  Future<void> _generate() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _msg = null;
      _live = const LiveStatus(phase: LivePhase.queued);
    });
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        ApiPaths.studiosImageGenerate,
        data: {
          'prompt': prompt,
          if (_presetId != null) 'preset': _presetId,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      _applyResult(data);
      await _loadJobs();
      await ref.read(authControllerProvider.notifier).refreshMe();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _live = LiveStatus(phase: LivePhase.error, errorFa: e.message);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batch() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _msg = null;
      _live = const LiveStatus(phase: LivePhase.queued);
    });
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.proImageBatch,
        data: {
          'prompt': prompt,
          if (_presetId != null) 'preset': _presetId,
          'count': _batchCount,
        },
      );
      setState(() => _msg = 'بچ در صف تولید قرار گرفت');
      await _loadJobs();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final prompt = _editPrompt.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.proImageEdit,
        data: {
          'prompt': prompt,
          'operation': 'inpaint',
          if (_presetId != null) 'params': {'preset': _presetId},
        },
      );
      setState(() => _msg = 'ویرایش در صف قرار گرفت');
      await _loadJobs();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBrand() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).put(
        ApiPaths.proBrandKit,
        data: {
          'brand_name': _brandName.text.trim(),
          'colors': _brandColors.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'forbidden_words': _brandWords.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        },
      );
      setState(() => _msg = 'کیت برند ذخیره شد');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyResult(Map<String, dynamic> data) {
    final payload = data['output_payload'] is Map
        ? Map<String, dynamic>.from(data['output_payload'] as Map)
        : data;
    final url = '${payload['url'] ?? data['url'] ?? data['image_url'] ?? ''}';
    final text =
        '${payload['text'] ?? data['text'] ?? data['output'] ?? data['result'] ?? ''}';
    final revised = '${payload['revised_prompt'] ?? data['revised_prompt'] ?? ''}';
    final status = '${data['status'] ?? ''}';
    setState(() {
      if (url.isNotEmpty) {
        _resultUrl = _resolveUrl(url);
      } else if (text.isNotEmpty && text != '{}') {
        _resultText = text;
      } else if (status == 'queued' || status == 'running') {
        _live = LiveStatus(
          phase: status == 'queued' ? LivePhase.queued : LivePhase.generating,
        );
      }
      if (revised.isNotEmpty) _revisedPrompt = revised;
      if (_resultUrl != null || _resultText != null) {
        _live = const LiveStatus(phase: LivePhase.ready);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'استودیوی تصویر', showBack: true),
      body: _loadingPresets
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'پرامپت تصویر',
                        subtitle: 'مثل گفتگو بنویسید؛ سپس تصویر بسازید',
                      ),
                      const SizedBox(height: 12),
                      if (_presets.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _presets.map((p) {
                            return ChoiceChip(
                              label: Text(p.name),
                              selected: p.id == _presetId,
                              onSelected: (_) =>
                                  setState(() => _presetId = p.id),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _prompt,
                        minLines: 4,
                        maxLines: 8,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'توضیح تصویر را بنویسید…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _generate,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('ساخت تصویر'),
                      ),
                      LiveStatusLine(status: _live),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('تعداد بچ'),
                          Expanded(
                            child: Slider(
                              value: _batchCount.toDouble(),
                              min: 2,
                              max: 6,
                              divisions: 4,
                              label: '$_batchCount',
                              onChanged: (v) =>
                                  setState(() => _batchCount = v.round()),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _batch,
                            child: const Text('بچ'),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push('/studios/gallery'),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('گالری تصاویر'),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'ویرایش درجا'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _editPrompt,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'دستور ویرایش',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _edit,
                        child: const Text('ارسال ویرایش'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'کیت برند'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _brandName,
                        decoration: const InputDecoration(labelText: 'نام برند'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _brandColors,
                        decoration: const InputDecoration(
                          labelText: 'رنگ‌ها (با کاما)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _brandWords,
                        decoration: const InputDecoration(
                          labelText: 'کلمات ممنوع',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _saveBrand,
                        child: const Text('ذخیره کیت'),
                      ),
                    ],
                  ),
                ),
                if (_jobs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'صف تولید'),
                        const SizedBox(height: 6),
                        for (final j in _jobs.take(6))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              () {
                                final st = '${j['status'] ?? ''}';
                                final p = livePhaseFromJobStatus(st);
                                return p != null
                                    ? LiveStatus(phase: p).label
                                    : (st.isEmpty ? '—' : st);
                              }(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: PigptColors.mutedOf(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: PigptColors.danger)),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: 8),
                  Text(_msg!, style: const TextStyle(color: PigptColors.brand)),
                ],
                if (_resultUrl != null || _resultText != null) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('خروجی',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (_resultUrl != null)
                          TappableImage(
                            url: _resultUrl,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_resultUrl!, fit: BoxFit.contain),
                            ),
                          ),
                        if (_resultUrl != null)
                          ImageActionBar(url: _resultUrl),
                        if (_resultText != null) SelectableText(_resultText!),
                        if (_revisedPrompt != null)
                          Text(
                            'پرامپت بازبینی‌شده: $_revisedPrompt',
                            style: TextStyle(
                              color: PigptColors.mutedOf(context),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
