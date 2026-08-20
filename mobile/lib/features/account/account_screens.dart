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
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/ui.dart';

class AccountHubScreen extends ConsumerWidget {
  const AccountHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: const PigptAppBar(title: 'حساب'),
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
                me?.spendableToday ?? me?.dailyTokensRemaining,
            dailyUnlimited: me?.dailyUnlimited ?? false,
            onTopUp: () => context.push('/account/plans'),
          ),
          const SizedBox(height: 16),
          _tile(context, Icons.credit_card_rounded, 'پلن و کیف‌توکن',
              '/account/plans'),
          _tile(context, Icons.account_balance_outlined, 'پرداخت‌های کارت‌به‌کارت',
              '/account/offline-payments'),
          _tile(context, Icons.receipt_long_outlined, 'فاکتورها',
              '/account/invoices'),
          _tile(context, Icons.bar_chart_rounded, 'مصرف', '/account/usage'),
          _tile(context, Icons.tune_rounded, 'تنظیمات',
              '/account/settings'),
          _tile(context, Icons.auto_awesome_rounded, 'مدل‌ها', '/models'),
          _tile(context, Icons.card_giftcard_rounded, 'دعوت دوستان',
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
  const PlansScreen({super.key, this.billingStatus});
  final String? billingStatus;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  List<BillingPlan> _plans = const [];
  List<TokenPackage> _packages = const [];
  BillingWallet? _wallet;
  String? _error;
  bool _loading = true;
  bool _offlineEnabled = false;
  String? _offlineHint;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = widget.billingStatus;
      if (b == null || !mounted) return;
      final msg = switch (b) {
        'ok' => 'پرداخت موفق — موجودی به‌روز شد',
        'failed' => 'پرداخت ناموفق بود',
        'missing' => 'پرداخت یافت نشد',
        _ => 'وضعیت پرداخت: $b',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (b == 'ok') {
        ref.read(authControllerProvider.notifier).refreshMe();
      }
    });
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    String? error;
    List<BillingPlan> plans = const [];
    List<TokenPackage> packages = const [];
    BillingWallet? wallet;
    var offlineEnabled = false;
    String? offlineHint;

    try {
      final off = await api.get<Map<String, dynamic>>(
        ApiPaths.billingOfflineSettings,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final cards = off['cards'];
      final hasCards = (cards is List && cards.isNotEmpty) ||
          '${off['card_number'] ?? ''}'.trim().isNotEmpty;
      offlineEnabled = off['is_enabled'] == true ||
          off['enabled'] == true ||
          off['configured'] == true ||
          hasCards;
      if (!offlineEnabled) {
        offlineHint =
            '${off['message_fa'] ?? off['hint_fa'] ?? 'پرداخت کارت‌به‌کارت فعلاً فعال نیست.'}';
      }
    } on ApiException catch (e) {
      // Still offer the offline flow — the pay screen shows the real status.
      offlineEnabled = true;
      offlineHint = e.message;
    }

    try {
      final data = await api.get<Map<String, dynamic>>(
        ApiPaths.billingPlans,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final list = (data['plans'] ?? data['items'] ?? []) as List;
      final current = data['current_plan_id']?.toString();
      plans = list.whereType<Map>().map((e) {
        final p = BillingPlan.fromJson(Map<String, dynamic>.from(e));
        return BillingPlan(
          id: p.id,
          name: p.name,
          price: p.price,
          priceRial: p.priceRial,
          description: p.description,
          current: p.id == current || p.current,
          tokensGranted: p.tokensGranted,
          capabilityCount: p.capabilityCount,
        );
      }).toList();
    } on ApiException catch (e) {
      error = e.message;
    }

    try {
      final pkgs = await api.get<Map<String, dynamic>>(
        ApiPaths.billingTokenPackages,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final list = (pkgs['packages'] ?? pkgs['items'] ?? []) as List;
      packages = list
          .whereType<Map>()
          .map((e) => TokenPackage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException catch (e) {
      error ??= e.message;
    }

    try {
      final w = await api.get<Map<String, dynamic>>(
        ApiPaths.billingWallet,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      wallet = BillingWallet.fromJson(w);
    } on ApiException {
      // Fall back to /me wallet fields below.
    }

    if (!mounted) return;
    setState(() {
      _offlineEnabled = offlineEnabled;
      _offlineHint = offlineHint;
      _plans = plans;
      _packages = packages;
      _wallet = wallet;
      _error = error;
      _loading = false;
    });
  }

  String _fmtPrice(num? rial) {
    if (rial == null) return '—';
    if (rial == 0) return 'رایگان';
    final toman = (rial / 10).round();
    return '${toman.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} تومان';
  }

  String _fmtNum(num n) =>
      n.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _startOffline({String? planId, String? packageId}) {
    final q = <String, String>{
      if (planId != null && planId.isNotEmpty) 'plan_id': planId,
      if (packageId != null && packageId.isNotEmpty) 'package_id': packageId,
    };
    final uri = Uri(path: '/account/offline-pay', queryParameters: q);
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final wallet = _wallet;
    final balance = wallet?.balance ?? me?.balance;
    final dailyRemaining = wallet?.spendableToday ??
        me?.spendableToday ??
        me?.dailyTokensRemaining;
    final dailyUnlimited =
        wallet?.dailyUnlimited == true || me?.dailyUnlimited == true;
    final canGenerate = wallet?.canGenerate ?? me?.canGenerate ?? true;

    return Scaffold(
      appBar: const PigptAppBar(title: 'پلن و کیف', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'موجودی کیف',
                          style: TextStyle(
                            color: PigptColors.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${balance != null ? _fmtNum(balance) : '—'} توکن',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: PigptColors.brand,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dailyUnlimited
                              ? 'بدون سقف روزانه'
                              : 'باقیمانده امروز: ${dailyRemaining != null ? _fmtNum(dailyRemaining) : '—'}'
                          '${!canGenerate ? ' — برای ادامه شارژ لازم است' : ''}',
                          style: const TextStyle(
                            color: PigptColors.inkMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'مصرف با توکن پلتفرم محاسبه می‌شود. پس از اتمام موجودی، تولید مسدود می‌شود تا شارژ کنید.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: PigptColors.inkMuted),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/account/usage'),
                            child: const Text('تاریخچه مصرف توکن'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    onTap: () => context.push('/account/plans-compare'),
                    child: const Row(
                      children: [
                        Icon(Icons.compare_arrows_rounded,
                            color: PigptColors.brand),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'مقایسه پلن‌ها',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded,
                            color: PigptColors.inkFaint),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    onTap: () => context.push('/account/offline-payments'),
                    child: const Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: PigptColors.brand),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'پرداخت‌های کارت‌به‌کارت',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded,
                            color: PigptColors.inkFaint),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: PigptColors.danger)),
                  ],
                  if (!_offlineEnabled && _offlineHint != null) ...[
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Text(
                        _offlineHint!,
                        style: const TextStyle(color: PigptColors.inkMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'شارژ توکن اضافه',
                    subtitle: 'بسته‌های توکن — واریز کارت‌به‌کارت',
                  ),
                  const SizedBox(height: 10),
                  if (_packages.isEmpty)
                    const SoftCard(
                      child: Text(
                        'بسته توکنی تعریف نشده است.',
                        style: TextStyle(color: PigptColors.inkMuted),
                      ),
                    )
                  else
                    ..._packages.map(
                      (p) => SoftCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              '${_fmtNum(p.tokensGranted)} توکن',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: PigptColors.brand,
                                fontSize: 18,
                              ),
                            ),
                            if (p.description != null &&
                                p.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(p.description!,
                                  style: const TextStyle(
                                      color: PigptColors.inkMuted,
                                      fontSize: 13)),
                            ],
                            const SizedBox(height: 4),
                            Text(_fmtPrice(p.priceRial),
                                style: const TextStyle(
                                    color: PigptColors.inkMuted)),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () => _startOffline(packageId: p.id),
                              child: const Text('پرداخت کارت‌به‌کارت'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'پلن‌ها'),
                  const SizedBox(height: 10),
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
                              if (p.current) const CurrentPlanBadge(),
                            ],
                          ),
                          if (p.description != null) ...[
                            const SizedBox(height: 6),
                            Text(p.description!,
                                style: const TextStyle(
                                    color: PigptColors.inkMuted)),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _fmtPrice(p.priceRial ?? p.price) +
                                ((p.priceRial ?? p.price ?? 0) > 0
                                    ? ' / ماه'
                                    : ''),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if ((p.tokensGranted ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                                'توکن همراه پلن: ${_fmtNum(p.tokensGranted!)}'),
                          ],
                          if (p.capabilityCount != null) ...[
                            const SizedBox(height: 2),
                            Text('ابزارها: ${p.capabilityCount} مورد'),
                          ],
                          const SizedBox(height: 10),
                          if (p.current)
                            const OutlinedButton(
                              onPressed: null,
                              child: Text('پلن فعلی'),
                            )
                          else if ((p.priceRial ?? p.price ?? 0) <= 0)
                            const OutlinedButton(
                              onPressed: null,
                              child: Text('رایگان'),
                            )
                          else
                            FilledButton(
                              onPressed: () => _startOffline(planId: p.id),
                              child: const Text('پرداخت کارت‌به‌کارت'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PlansCompareScreen extends ConsumerStatefulWidget {
  const PlansCompareScreen({super.key});

  @override
  ConsumerState<PlansCompareScreen> createState() => _PlansCompareScreenState();
}

class _PlansCompareScreenState extends ConsumerState<PlansCompareScreen> {
  List<Map<String, dynamic>> _plans = const [];
  List<Map<String, dynamic>> _features = const [];
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
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.billingPlansCompare,
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      final plans = (data['plans'] ?? []) as List;
      final feats = (data['features_matrix'] ?? data['features'] ?? []) as List;
      if (!mounted) return;
      setState(() {
        _plans = plans
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _features = feats
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

  String _cell(Map<String, dynamic> plan, String key) {
    final v = plan[key] ??
        (plan['limits'] is Map ? (plan['limits'] as Map)[key] : null) ??
        (plan['features'] is Map ? (plan['features'] as Map)[key] : null);
    if (v == null) return '—';
    if (v is bool) return v ? '✓' : '—';
    if (v is num) {
      return v
          .round()
          .toString()
          .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'مقایسه پلن‌ها', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  title: 'مقایسه',
                  body: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('تلاش دوباره')),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SectionHeader(
                      title: 'پلن‌ها در یک نگاه',
                      subtitle: 'تفاوت سقف و ابزارها',
                    ),
                    const SizedBox(height: 12),
                    ..._plans.map((p) {
                      final name =
                          '${p['name_fa'] ?? p['name'] ?? p['code'] ?? 'پلن'}';
                      return SoftCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            if (_features.isEmpty)
                              Text(
                                'توکن: ${_cell(p, 'platform_tokens_granted')}',
                                style: const TextStyle(
                                    color: PigptColors.inkMuted),
                              )
                            else
                              ..._features.map((f) {
                                final key = '${f['key'] ?? ''}';
                                final label =
                                    '${f['label_fa'] ?? f['label'] ?? key}';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(label)),
                                      Text(
                                        _cell(p, key),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () {
                                final id = '${p['id'] ?? ''}';
                                if (id.isEmpty) {
                                  context.push('/account/plans');
                                } else {
                                  context.push(
                                      '/account/offline-pay?plan_id=$id');
                                }
                              },
                              child: const Text('پرداخت کارت‌به‌کارت'),
                            ),
                          ],
                        ),
                      );
                    }),
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
      appBar: const PigptAppBar(title: 'درباره PiGPT', showBack: true),
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
