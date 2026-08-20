import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';
import '../chat/chat_providers.dart';

/// Full settings aligned with web SettingsModal (mobile-supported APIs).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.asHub = false});
  final bool asHub;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic> _settings = {};
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

  Map<String, String> get _traits {
    final raw = _settings['traits'];
    const keys = ['warmth', 'enthusiasm', 'headers_lists', 'emoji'];
    final out = <String, String>{};
    for (final k in keys) {
      final v = raw is Map ? raw[k]?.toString() : null;
      out[k] = (v == 'less' || v == 'more') ? v! : 'default';
    }
    return out;
  }

  String get _baseStyle {
    final v = _settings['base_style']?.toString();
    if (v != null && v.isNotEmpty) return v;
    final t = _settings['tone']?.toString();
    if (t != null && t.isNotEmpty) return t;
    return 'default';
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
      final custom = settings['custom_instructions'];
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _tones = tones;
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
    ref.read(showCodeBlocksProvider.notifier).state =
        settings['show_code_blocks'] != false;
  }

  Future<void> _saveSettings({String ok = 'ذخیره شد'}) async {
    _settings['nickname'] = _nickname.text.trim();
    _settings['occupation'] = _occupation.text.trim();
    _settings['custom_instructions'] = {
      'about_user': _aboutUser.text.trim(),
      'how_to_respond': _howRespond.text.trim(),
    };
    final style = '${_settings['base_style'] ?? _settings['tone'] ?? 'default'}';
    _settings['base_style'] = style;
    _settings['tone'] = style;
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

  Future<void> _deleteAllChats() async {
    await _confirmDanger(
      'حذف همه گفتگوها؟',
      'همه گفتگوها برای همیشه حذف می‌شوند.',
      () async {
        await ref.read(apiClientProvider).delete(ApiPaths.conversations);
        ref.invalidate(conversationsProvider(false));
        ref.invalidate(conversationsProvider(true));
        setState(() => _msg = 'همه گفتگوها حذف شد');
      },
    );
  }

  Future<void> _deleteAccount() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف کامل حساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('برای تأیید، DELETE را تایپ کنید.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim() != 'DELETE') return;
    try {
      await ref.read(apiClientProvider).delete(
            ApiPaths.me,
            data: {'confirm': 'DELETE'},
          );
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/auth');
    } on ApiException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    }
  }

  List<Widget> _traitTiles() {
    const meta = [
      ('warmth', 'گرما', 'رسمی‌تر', 'صمیمی‌تر'),
      ('enthusiasm', 'اشتیاق', 'آرام‌تر', 'پرانرژی‌تر'),
      ('headers_lists', 'عنوان و فهرست', 'پاراگراف', 'ساختارمند'),
      ('emoji', 'ایموجی', 'بدون ایموجی', 'با ایموجی'),
    ];
    final locked = _settings['personalization_enabled'] == false;
    final traits = Map<String, dynamic>.from(_settings['traits'] is Map
        ? Map<String, dynamic>.from(_settings['traits'] as Map)
        : _traits);
    return [
      for (final t in meta) ...[
        DropdownButtonFormField<String>(
          value: _traits[t.$1],
          decoration: InputDecoration(
            labelText: t.$2,
            helperText: '${t.$3} · پیش‌فرض · ${t.$4}',
          ),
          items: [
            DropdownMenuItem(value: 'less', child: Text(t.$3)),
            const DropdownMenuItem(value: 'default', child: Text('پیش‌فرض')),
            DropdownMenuItem(value: 'more', child: Text(t.$4)),
          ],
          onChanged: locked
              ? null
              : (v) => setState(() {
                    traits[t.$1] = v ?? 'default';
                    _settings['traits'] = traits;
                  }),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _hubHeader(BuildContext context) {
    final me = ref.watch(meProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          child: Row(
            children: [
              const PigptMark(size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.greetingName ?? 'کاربر',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (me?.email != null)
                      Text(
                        me!.email,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: PigptColors.inkMuted),
                      ),
                    if (me?.planName != null)
                      Text('پلن: ${me!.planName}',
                          style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WalletBanner(
          canGenerate: me?.canGenerate ?? true,
          balance: me?.balance,
          dailyRemaining: me?.spendableToday ?? me?.dailyTokensRemaining,
          dailyUnlimited: me?.dailyUnlimited ?? false,
          onTopUp: () => context.push('/account/plans'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _accountLinks(BuildContext context) {
    Widget tile(IconData icon, String title, String path) {
      return SoftCard(
        margin: const EdgeInsets.only(bottom: 8),
        onTap: () => context.push(path),
        child: Row(
          children: [
            Icon(icon, color: PigptColors.brand),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_left_rounded, color: PigptColors.inkFaint),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'حساب'),
        const SizedBox(height: 8),
        tile(Icons.credit_card_rounded, 'پلن و کیف‌توکن', '/account/plans'),
        tile(Icons.receipt_long_outlined, 'فاکتورها', '/account/invoices'),
        tile(Icons.bar_chart_rounded, 'مصرف', '/account/usage'),
        tile(Icons.card_giftcard_rounded, 'ارجاع', '/account/referral'),
        tile(Icons.support_agent_rounded, 'پشتیبانی', '/account/support'),
        tile(Icons.terminal_rounded, 'راهنمای PiCode', '/account/picode'),
        tile(Icons.info_outline_rounded, 'درباره PiGPT', '/account/about'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PigptAppBar(
        title: widget.asHub ? 'حساب و تنظیمات' : 'تنظیمات',
        showBack: !widget.asHub,
      ),
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
                if (widget.asHub) _hubHeader(context),
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ارسال با Enter'),
                        value: _settings['enter_to_send'] == true,
                        onChanged: (v) =>
                            setState(() => _settings['enter_to_send'] = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('قالب‌بندی بلوک کد'),
                        subtitle: const Text(
                            'قالب‌بندی خواناتر برای قطعات کد در پاسخ‌ها'),
                        value: _settings['show_code_blocks'] != false,
                        onChanged: (v) => setState(
                            () => _settings['show_code_blocks'] = v),
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
                      if (_settings['personalization_enabled'] == false) ...[
                        SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'شخصی‌سازی برای پلن شما محدود است یا خاموش شده.',
                                style: TextStyle(fontSize: 13),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      context.push('/account/plans'),
                                  child: const Text('مشاهده پلن‌ها'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('شخصی‌سازی فعال'),
                        value: _settings['personalization_enabled'] != false,
                        onChanged: (v) => setState(
                            () => _settings['personalization_enabled'] = v),
                      ),
                      DropdownButtonFormField<String>(
                        value: () {
                          final ids = _tones.isNotEmpty
                              ? _tones.map((t) => '${t['id']}').toList()
                              : const [
                                  'default',
                                  'professional',
                                  'friendly',
                                  'candid',
                                  'quirky',
                                  'efficient',
                                  'cynical',
                                ];
                          return ids.contains(_baseStyle) ? _baseStyle : null;
                        }(),
                        decoration: const InputDecoration(
                            labelText: 'سبک و لحن پایه'),
                        items: (_tones.isNotEmpty
                                ? _tones
                                : const [
                                    {'id': 'default', 'label_fa': 'پیش‌فرض'},
                                    {
                                      'id': 'professional',
                                      'label_fa': 'حرفه‌ای'
                                    },
                                    {'id': 'friendly', 'label_fa': 'دوستانه'},
                                    {'id': 'candid', 'label_fa': 'صریح'},
                                    {'id': 'quirky', 'label_fa': 'بامزه'},
                                    {'id': 'efficient', 'label_fa': 'کارآمد'},
                                    {'id': 'cynical', 'label_fa': 'طعنه‌آمیز'},
                                  ])
                            .map((t) => DropdownMenuItem(
                                  value: '${t['id']}',
                                  child: Text('${t['label_fa'] ?? t['id']}'),
                                ))
                            .toList(),
                        onChanged: (_settings['personalization_enabled'] ==
                                false)
                            ? null
                            : (v) => setState(() {
                                  _settings['base_style'] = v;
                                  _settings['tone'] = v;
                                }),
                      ),
                      const SizedBox(height: 8),
                      ..._traitTiles(),
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
                  onTap: () => context.push('/models'),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: PigptColors.brand),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مدل‌ها',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text(
                              'انتخاب و مدیریت مدل‌های فعال',
                              style: TextStyle(
                                  color: PigptColors.inkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          color: PigptColors.inkFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    children: [
                      const SectionHeader(title: 'داده و حریم خصوصی'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('خروجی داده'),
                        subtitle: const Text('پروفایل و گفتگوها'),
                        onTap: _export,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
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
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_forever_outlined,
                            color: PigptColors.danger),
                        title: const Text('حذف همه گفتگوها'),
                        onTap: _deleteAllChats,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'امنیت'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ایمیل حساب'),
                        subtitle: Text(
                          ref.watch(meProvider)?.email ?? '—',
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('موبایل'),
                        subtitle: Text(
                          ref.watch(meProvider)?.phone ?? '—',
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('خروج از این دستگاه'),
                        onTap: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (context.mounted) context.go('/auth');
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_off_outlined,
                            color: PigptColors.danger),
                        title: const Text('حذف کامل حساب'),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _ApiKeyCard(),
                const SizedBox(height: 12),
                _accountLinks(context),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/auth');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('خروج'),
                ),
              ],
            ),
    );
  }
}

class _ApiKeyCard extends ConsumerStatefulWidget {
  const _ApiKeyCard();

  @override
  ConsumerState<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends ConsumerState<_ApiKeyCard> {
  List<Map<String, dynamic>> _items = const [];
  String? _token;
  String? _msg;
  bool _loading = true;
  bool _hidden = false;
  bool _busy = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.meApiKeys,
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      final list = (data['items'] ?? data['keys'] ?? []) as List;
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
        _hidden = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hidden = e.statusCode == 404 || e.statusCode == 410;
        _msg = _hidden ? null : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
            ApiPaths.meApiKeys,
            data: {'name': 'افزونه وردپرس'},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      if (!mounted) return;
      setState(() {
        _token = data['token']?.toString();
        _msg = data['message_fa']?.toString() ??
            'کلید ساخته شد — فقط همین یک‌بار قابل مشاهده است.';
        _reveal = false;
        _busy = false;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _revoke(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).delete(ApiPaths.meApiKey(id));
      if (_token != null) setState(() => _token = null);
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _msg = 'کپی شد');
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    if (_loading) {
      return const SoftCard(child: Text('بارگذاری کلید اتصال…'));
    }
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'کلید اتصال',
            subtitle: 'برای افزونه وردپرس PiGPT — آدرس پایه https://pigpt.ir',
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!, style: const TextStyle(color: PigptColors.brand)),
          ],
          if (_token != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _reveal ? _token! : '••••••••••••',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: _reveal ? 'مخفی' : 'نمایش',
                  onPressed: () => setState(() => _reveal = !_reveal),
                  icon: Icon(_reveal
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
                TextButton.icon(
                  onPressed: () => _copy(_token!),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('کپی کلید'),
                ),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _copy(PigptBrand.webUrl),
              child: const Text('کپی آدرس پایه'),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: const Text('ساخت کلید جدید'),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('کلید فعالی نیست.',
                  style: TextStyle(color: PigptColors.inkMuted)),
            )
          else
            ..._items.map((k) {
              final id = '${k['id'] ?? ''}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${k['name'] ?? 'کلید'} · ${k['prefix'] ?? ''}'),
                subtitle: Text(
                  k['created_at']?.toString() ?? '',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  tooltip: 'باطل کردن',
                  onPressed: _busy || id.isEmpty ? null : () => _revoke(id),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            }),
        ],
      ),
    );
  }
}
