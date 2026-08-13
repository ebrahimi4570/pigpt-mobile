import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';
import '../chat/chat_providers.dart';

/// Full settings aligned with web SettingsModal (mobile-supported APIs).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  List<AiModel> _models = const [];
  Set<String> _enabledModels = {};
  String? _defaultModel;
  List<Map<String, dynamic>> _tones = const [];
  bool _loading = true;
  String? _msg;
  final _memoryDraft = TextEditingController();
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  final _nickname = TextEditingController();
  final _occupation = TextEditingController();
  final _aboutUser = TextEditingController();
  final _howRespond = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _memoryDraft.dispose();
    _displayName.dispose();
    _phone.dispose();
    _nickname.dispose();
    _occupation.dispose();
    _aboutUser.dispose();
    _howRespond.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _memories {
    final raw = _settings['memories'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> get _speech {
    final raw = _settings['speech'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'voice_input': false, 'voice_output': true};
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final me = ref.read(meProvider);
    try {
      final settingsRes = await api.get<Map<String, dynamic>>(
        ApiPaths.meSettings,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final settings = settingsRes['settings'] is Map
          ? Map<String, dynamic>.from(settingsRes['settings'] as Map)
          : settingsRes;
      final tonesRaw = settingsRes['tones'];
      final tones = tonesRaw is List
          ? tonesRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final prefs = await api.get<Map<String, dynamic>>(
        ApiPaths.meModelPrefs,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final models = await ref.read(modelsProvider.future);
      final enabled = <String>{};
      final rawEnabled = prefs['enabled_model_ids'] ?? prefs['models'];
      if (rawEnabled is List) {
        enabled.addAll(rawEnabled.map((e) => e.toString()));
      }
      final custom = settings['custom_instructions'];
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _tones = tones;
        _models = models;
        _enabledModels = enabled;
        _defaultModel = prefs['default_model_id']?.toString() ??
            settings['default_model_id']?.toString();
        _displayName.text = me?.displayName ?? '';
        _phone.text = me?.phone ?? '';
        _nickname.text = '${settings['nickname'] ?? ''}';
        _occupation.text = '${settings['occupation'] ?? ''}';
        if (custom is Map) {
          _aboutUser.text = '${custom['about_user'] ?? ''}';
          _howRespond.text = '${custom['how_to_respond'] ?? ''}';
        }
        _loading = false;
      });
      _applyLocaleThemeSpeech(settings);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.message;
        _loading = false;
      });
    }
  }

  void _applyLocaleThemeSpeech(Map<String, dynamic> settings) {
    final theme = settings['theme']?.toString();
    if (theme == 'light') {
      ref.read(themeModeProvider.notifier).state = ThemeMode.light;
    } else if (theme == 'system') {
      ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    } else {
      ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
    }
    final loc = settings['ui_locale']?.toString() == 'en' ? 'en' : 'fa';
    ref.read(localeProvider.notifier).state = Locale(loc);
    final speech = settings['speech'];
    if (speech is Map) {
      ref.read(speechOutputEnabledProvider.notifier).state =
          speech['voice_output'] != false;
      ref.read(speechInputEnabledProvider.notifier).state =
          speech['voice_input'] == true;
    }
  }

  Future<void> _saveSettings({String ok = 'ذخیره شد'}) async {
    _settings['nickname'] = _nickname.text.trim();
    _settings['occupation'] = _occupation.text.trim();
    _settings['custom_instructions'] = {
      'about_user': _aboutUser.text.trim(),
      'how_to_respond': _howRespond.text.trim(),
    };
    try {
      await ref.read(apiClientProvider).patch(
            ApiPaths.meSettings,
            data: _settings,
          );
      _applyLocaleThemeSpeech(_settings);
      setState(() => _msg = ok);
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    }
  }

  Future<void> _saveProfile() async {
    try {
      await ref.read(apiClientProvider).patch(
        ApiPaths.me,
        data: {
          'display_name': _displayName.text.trim(),
          'phone': _phone.text.trim(),
        },
      );
      await ref.read(authControllerProvider.notifier).refreshMe();
      setState(() => _msg = 'پروفایل به‌روز شد');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    }
  }

  Future<void> _saveModels() async {
    try {
      await ref.read(apiClientProvider).put(
        ApiPaths.meModelPrefs,
        data: {
          'enabled_model_ids': _enabledModels.toList(),
          'default_model_id': _defaultModel,
        },
      );
      setState(() => _msg = 'مدل‌ها ذخیره شد');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    }
  }

  Future<void> _addMemory() async {
    final text = _memoryDraft.text.trim();
    if (text.isEmpty) return;
    final next = [
      ..._memories,
      {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'content': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    _memoryDraft.clear();
    setState(() => _settings['memories'] = next);
    await _saveSettings(ok: 'حافظه افزوده شد');
  }

  Future<void> _export() async {
    try {
      final data = await ref.read(apiClientProvider).get<dynamic>(ApiPaths.meExport);
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await Share.share(pretty, subject: 'PiGPT export');
      setState(() => _msg = 'خروجی داده آماده شد');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    }
  }

  Future<void> _confirmDanger(
    String title,
    String body,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأیید')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'تنظیمات', showBack: true),
      body: _loading
          ? const ListShimmer(itemCount: 5, itemHeight: 96)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_msg != null) ...[
                  SoftCard(
                    child: Text(_msg!,
                        style: const TextStyle(color: PigptColors.brand)),
                  ),
                  const SizedBox(height: 12),
                ],
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'پروفایل'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _displayName,
                        decoration:
                            const InputDecoration(labelText: 'نام نمایشی'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'تلفن',
                          hintText: '09xxxxxxxxx',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _saveProfile,
                          child: const Text('ذخیره پروفایل')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'عمومی'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: '${_settings['theme'] ?? 'dark'}',
                        decoration: const InputDecoration(labelText: 'تم'),
                        items: const [
                          DropdownMenuItem(value: 'dark', child: Text('تاریک')),
                          DropdownMenuItem(value: 'light', child: Text('روشن')),
                          DropdownMenuItem(
                              value: 'system', child: Text('سیستم')),
                        ],
                        onChanged: (v) =>
                            setState(() => _settings['theme'] = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: '${_settings['ui_locale'] ?? 'fa'}',
                        decoration: const InputDecoration(labelText: 'زبان'),
                        items: const [
                          DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                          DropdownMenuItem(
                              value: 'en', child: Text('English')),
                        ],
                        onChanged: (v) =>
                            setState(() => _settings['ui_locale'] = v),
                      ),
                      const SizedBox(height: 12),
                      if (_tones.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: _tones.any((t) =>
                                  '${t['id']}' == '${_settings['tone']}')
                              ? '${_settings['tone']}'
                              : null,
                          decoration: const InputDecoration(labelText: 'لحن'),
                          items: _tones
                              .map((t) => DropdownMenuItem(
                                    value: '${t['id']}',
                                    child: Text(
                                        '${t['label_fa'] ?? t['id']}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _settings['tone'] = v),
                        )
                      else
                        TextFormField(
                          initialValue: '${_settings['tone'] ?? ''}',
                          decoration: const InputDecoration(labelText: 'لحن'),
                          onChanged: (v) => _settings['tone'] = v,
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ارسال با Enter'),
                        value: _settings['enter_to_send'] == true,
                        onChanged: (v) =>
                            setState(() => _settings['enter_to_send'] = v),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: () => _saveSettings(),
                          child: const Text('ذخیره تنظیمات')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'شخصی‌سازی',
                        subtitle: 'لقب، شغل و دستورهای سفارشی',
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('شخصی‌سازی فعال'),
                        value: _settings['personalization_enabled'] != false,
                        onChanged: (v) => setState(
                            () => _settings['personalization_enabled'] = v),
                      ),
                      TextField(
                        controller: _nickname,
                        decoration: const InputDecoration(labelText: 'لقب'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _occupation,
                        decoration: const InputDecoration(labelText: 'شغل'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aboutUser,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'درباره کاربر'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _howRespond,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'چگونه پاسخ دهد'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: () => _saveSettings(ok: 'شخصی‌سازی ذخیره شد'),
                          child: const Text('ذخیره شخصی‌سازی')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'حافظه'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('حافظه فعال'),
                        value: _settings['memory_enabled'] != false,
                        onChanged: (v) => setState(
                            () => _settings['memory_enabled'] = v),
                      ),
                      TextField(
                        controller: _memoryDraft,
                        decoration: const InputDecoration(
                          labelText: 'حافظه جدید',
                          hintText: 'چیزی که باید به خاطر بسپارد…',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addMemory,
                        icon: const Icon(Icons.add),
                        label: const Text('افزودن حافظه'),
                      ),
                      const SizedBox(height: 8),
                      if (_memories.isEmpty)
                        const Text('حافظه‌ای ثبت نشده.',
                            style: TextStyle(color: PigptColors.inkMuted))
                      else
                        ..._memories.map((m) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${m['content'] ?? ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                setState(() {
                                  _settings['memories'] = _memories
                                      .where((x) => x['id'] != m['id'])
                                      .toList();
                                });
                                await _saveSettings(ok: 'حافظه حذف شد');
                              },
                            ),
                          );
                        }),
                      if (_memories.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            setState(() => _settings['memories'] = []);
                            await _saveSettings(ok: 'حافظه‌ها پاک شد');
                          },
                          child: const Text('پاک کردن همه حافظه‌ها'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'گفتار',
                        subtitle:
                            'میکروفون گفتگو را به متن تبدیل می‌کند (fa-IR / Whisper)',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ورودی صوتی'),
                        subtitle: const Text(
                            'دکمهٔ میکروفون در کادر گفتگو — بدون ارسال خودکار'),
                        value: _speech['voice_input'] == true,
                        onChanged: (v) {
                          setState(() {
                            _settings['speech'] = {
                              ..._speech,
                              'voice_input': v,
                            };
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('خروجی صوتی (TTS)'),
                        value: _speech['voice_output'] != false,
                        onChanged: (v) {
                          setState(() {
                            _settings['speech'] = {
                              ..._speech,
                              'voice_output': v,
                            };
                          });
                        },
                      ),
                      FilledButton(
                        onPressed: () => _saveSettings(ok: 'گفتار ذخیره شد'),
                        child: const Text('ذخیره گفتار'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'مدل‌های من',
                        subtitle: 'حداقل یک مدل باید فعال باشد',
                      ),
                      const SizedBox(height: 8),
                      ..._models.map((m) {
                        final on = _enabledModels.contains(m.id);
                        return CheckboxListTile(
                          value: on,
                          title: Text(m.name),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _enabledModels.add(m.id);
                              } else {
                                _enabledModels.remove(m.id);
                              }
                            });
                          },
                        );
                      }),
                      DropdownButtonFormField<String>(
                        value: _defaultModel != null &&
                                _models.any((m) => m.id == _defaultModel)
                            ? _defaultModel
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'مدل پیش‌فرض'),
                        items: _models
                            .map((m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _defaultModel = v),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _saveModels,
                          child: const Text('ذخیره مدل‌ها')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('خروجی داده (Export)'),
                        onTap: _export,
                      ),
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: const Text('بایگانی همه گفتگوها'),
                        onTap: () => _confirmDanger(
                          'بایگانی همه؟',
                          'همه گفتگوهای فعال بایگانی می‌شوند.',
                          () async {
                            await ref
                                .read(apiClientProvider)
                                .post(ApiPaths.conversationsArchiveAll);
                            ref.invalidate(conversationsProvider(false));
                            ref.invalidate(conversationsProvider(true));
                            setState(() => _msg = 'بایگانی شد');
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('خروج از همه دستگاه‌ها'),
                        onTap: () => _confirmDanger(
                          'خروج سراسری؟',
                          'از همه دستگاه‌ها خارج می‌شوید.',
                          () async {
                            await ref
                                .read(apiClientProvider)
                                .post(ApiPaths.meLogoutAll);
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
                            if (mounted) context.go('/auth');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
