import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/ui.dart';

/// Image studio aligned with web `/app/image`: presets + prompt + result preview.
class ImageStudioScreen extends ConsumerStatefulWidget {
  const ImageStudioScreen({super.key});

  @override
  ConsumerState<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends ConsumerState<ImageStudioScreen> {
  final _prompt = TextEditingController();
  List<ImagePreset> _presets = const [];
  String? _presetId;
  bool _loadingPresets = true;
  bool _busy = false;
  String? _error;
  String? _msg;
  String? _resultUrl;
  String? _resultText;
  String? _revisedPrompt;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<dynamic>(ApiPaths.studiosImagePresets);
      final list = data is List
          ? data
          : (data is Map
              ? (data['presets'] ?? data['items'] ?? []) as List
              : <dynamic>[]);
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
        // Sensible offline fallbacks matching common web presets.
        _presets = [
          ImagePreset(id: 'poster', name: 'پوستر'),
          ImagePreset(id: 'product', name: 'محصول'),
          ImagePreset(id: 'social', name: 'شبکه اجتماعی'),
          ImagePreset(id: 'illustration', name: 'تصویرسازی'),
        ];
        _presetId = 'poster';
      });
    }
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${PigptBrand.apiBase}$raw';
    return raw;
  }

  Future<void> _generate() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _msg = null;
      _resultUrl = null;
      _resultText = null;
      _revisedPrompt = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.studiosImageGenerate,
        data: {
          'prompt': prompt,
          if (_presetId != null) 'preset': _presetId,
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
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
          _msg = 'در صف تولید قرار گرفت — از گالری پیگیری کنید.';
        } else {
          _resultText = '$data';
        }
        if (revised.isNotEmpty) _revisedPrompt = revised;
        if (_msg == null && (_resultUrl != null || _resultText != null)) {
          _msg = 'آماده‌شده با PiGPT';
        }
      });
      await ref.read(authControllerProvider.notifier).refreshMe();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استودیوی تصویر')),
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
                        title: 'بریف تصویر',
                        subtitle:
                            'قالب بصری را انتخاب کنید، پرامپت را دقیق بنویسید، سپس تولید کنید.',
                      ),
                      const SizedBox(height: 12),
                      const Text('قالب بصری',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presets.map((p) {
                          final selected = p.id == _presetId;
                          return ChoiceChip(
                            label: Text(p.name),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _presetId = p.id),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _prompt,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'پرامپت تولید',
                          hintText:
                              'مثلاً: پوستر افتتاحیه فروشگاه کفش در تهران، ترکیب گرم، فضای شب شهری…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _generate,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(_busy ? 'در صف…' : 'ساخت تصویر'),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: PigptColors.danger)),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: 8),
                  Text(_msg!,
                      style: const TextStyle(color: PigptColors.brand)),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _resultUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => SelectableText(
                                _resultUrl!,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ),
                        if (_resultText != null) ...[
                          if (_resultUrl != null) const SizedBox(height: 10),
                          SelectableText(_resultText!),
                        ],
                        if (_revisedPrompt != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'پرامپت بازبینی‌شده: $_revisedPrompt',
                            style: const TextStyle(
                              color: PigptColors.inkMuted,
                              fontSize: 12,
                            ),
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
                  ).animate().fadeIn().slideY(begin: 0.04, end: 0),
                ],
              ],
            ),
    );
  }
}
