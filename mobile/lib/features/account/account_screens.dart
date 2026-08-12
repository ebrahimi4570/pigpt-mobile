import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/ui.dart';
import '../chat/chat_providers.dart';

class AccountHubScreen extends ConsumerWidget {
  const AccountHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حساب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            dailyRemaining:
                me?.dailyTokensRemaining ?? me?.freeDailyRemaining,
            dailyCap: me?.freeDailyCap,
            onTopUp: () => context.push('/account/plans'),
          ),
          const SizedBox(height: 16),
          _tile(context, Icons.credit_card_rounded, 'پلن و کیف‌توکن',
              '/account/plans'),
          _tile(context, Icons.bar_chart_rounded, 'مصرف', '/account/usage'),
          _tile(context, Icons.tune_rounded, 'تنظیمات و مدل‌های من',
              '/account/settings'),
          _tile(context, Icons.card_giftcard_rounded, 'ارجاع',
              '/account/referral'),
          _tile(context, Icons.support_agent_rounded, 'پشتیبانی',
              '/account/support'),
          _tile(context, Icons.terminal_rounded, 'راهنمای PiCode',
              '/account/picode'),
          _tile(context, Icons.info_outline_rounded, 'درباره PiGPT',
              '/account/about'),
          const SizedBox(height: 12),
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

  Widget _tile(BuildContext context, IconData icon, String title, String path) {
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
}

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  List<BillingPlan> _plans = const [];
  String? _error;
  bool _loading = true;
  String? _gateway;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>(
        ApiPaths.billingPlans,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final list = (data['plans'] ?? data['items'] ?? []) as List;
      final current = data['current_plan_id']?.toString();
      setState(() {
        _gateway = data['gateway']?.toString();
        _plans = list
            .whereType<Map>()
            .map((e) {
              final p = BillingPlan.fromJson(Map<String, dynamic>.from(e));
              return BillingPlan(
                id: p.id,
                name: p.name,
                price: p.price,
                description: p.description,
                current: p.id == current || p.current,
              );
            })
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pay(String planId) async {
    if (_gateway == 'inactive') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('درگاه پرداخت غیرفعال است — با پشتیبانی تماس بگیرید')),
      );
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.billingPayments,
        data: {'plan_id': planId},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final url = '${data['redirect_url'] ?? data['url'] ?? ''}';
      if (url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('پلن و کیف')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WalletBanner(
                  canGenerate: me?.canGenerate ?? true,
                  balance: me?.balance,
                  dailyRemaining: me?.dailyTokensRemaining ??
                      me?.freeDailyRemaining,
                  dailyCap: me?.freeDailyCap,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: PigptColors.danger)),
                ],
                const SizedBox(height: 16),
                ..._plans.map(
                  (p) => SoftCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (p.current) const SoonBadge(),
                          ],
                        ),
                        if (p.description != null) ...[
                          const SizedBox(height: 6),
                          Text(p.description!),
                        ],
                        if (p.price != null) ...[
                          const SizedBox(height: 6),
                          Text('${p.price}'),
                        ],
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: p.current ? null : () => _pay(p.id),
                          child: Text(p.current ? 'پلن فعلی' : 'خرید / ارتقا'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

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
  bool _loading = true;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final settingsRes = await api.get<Map<String, dynamic>>(
        ApiPaths.meSettings,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final settings = settingsRes['settings'] is Map
          ? Map<String, dynamic>.from(settingsRes['settings'] as Map)
          : settingsRes;
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
      setState(() {
        _settings = settings;
        _models = models;
        _enabledModels = enabled;
        _defaultModel = prefs['default_model_id']?.toString();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _msg = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await ref.read(apiClientProvider).patch(
            ApiPaths.meSettings,
            data: _settings,
          );
      final theme = _settings['theme']?.toString();
      if (theme == 'light') {
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
      } else if (theme == 'system') {
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
      } else {
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
      }
      setState(() => _msg = 'ذخیره شد');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_msg != null) Text(_msg!),
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
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (v) =>
                            setState(() => _settings['ui_locale'] = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '${_settings['tone'] ?? ''}',
                        decoration: const InputDecoration(labelText: 'لحن'),
                        onChanged: (v) => _settings['tone'] = v,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _saveSettings,
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
                        title: const Text('بایگانی همه گفتگوها'),
                        onTap: () async {
                          await ref
                              .read(apiClientProvider)
                              .post(ApiPaths.conversationsArchiveAll);
                          setState(() => _msg = 'بایگانی شد');
                        },
                      ),
                      ListTile(
                        title: const Text('خروج از همه دستگاه‌ها'),
                        onTap: () async {
                          await ref
                              .read(apiClientProvider)
                              .post(ApiPaths.meLogoutAll);
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (mounted) context.go('/auth');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('مصرف')),
      body: FutureBuilder(
        future: () async {
          final api = ref.read(apiClientProvider);
          try {
            return await api.get<dynamic>(ApiPaths.usage);
          } catch (_) {
            return await api.get<dynamic>(ApiPaths.billingTokenLedger);
          }
        }(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SoftCard(
              child: SelectableText('${snap.data}'),
            ),
          );
        },
      ),
    );
  }
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('ارجاع')),
      body: FutureBuilder(
        future: ref.read(apiClientProvider).get<dynamic>(ApiPaths.referral),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(title: 'ارجاع', body: '${snap.error}');
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SoftCard(child: SelectableText('${snap.data}')),
          );
        },
      ),
    );
  }
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String? _msg;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبانی')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'موضوع'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'متن پیام'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).post(
                        ApiPaths.supportTickets,
                        data: {
                          'subject': _subject.text.trim(),
                          'body': _body.text.trim(),
                        },
                      );
                      setState(() => _msg = 'تیکت ثبت شد');
                      _subject.clear();
                      _body.clear();
                    } on ApiException catch (e) {
                      setState(() => _msg = e.message);
                    }
                  },
                  child: const Text('ارسال تیکت'),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: 8),
                  Text(_msg!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('درباره PiGPT')),
      body: FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final v = snap.data;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: PigptMark(size: 72)),
              const SizedBox(height: 16),
              Text(
                PigptBrand.webDisplay,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                PigptBrand.taglineFa,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PigptColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const Text(
                'PiGPT پلتفرم هوش مصنوعی فارسی است. مدل‌ها فقط موتور پاسخ‌اند؛ هویت محصول همیشه PiGPT است.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 20),
              if (v != null)
                Text('نسخه اپ: ${v.version}+${v.buildNumber}',
                    textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => launchUrl(Uri.parse(PigptBrand.webUrl)),
                child: const Text('باز کردن pigpt.ir'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(PigptBrand.privacyUrl)),
                child: const Text('حریم خصوصی'),
              ),
            ],
          );
        },
      ),
    );
  }
}
