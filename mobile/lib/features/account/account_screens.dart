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
  String? _gateway;
  String? _busyId;

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
    String? gateway;

    try {
      final data = await api.get<Map<String, dynamic>>(
        ApiPaths.billingPlans,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final list = (data['plans'] ?? data['items'] ?? []) as List;
      final current = data['current_plan_id']?.toString();
      gateway = data['gateway']?.toString();
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
      _gateway = gateway;
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

  Future<void> _openPayment(Map<String, dynamic> body, String busyId) async {
    if (_gateway == 'inactive') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('درگاه پرداخت غیرفعال است — با پشتیبانی تماس بگیرید')),
      );
      return;
    }
    setState(() => _busyId = busyId);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post<Map<String, dynamic>>(
        ApiPaths.billingPayments,
        data: body,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final url = '${data['redirect_url'] ?? data['url'] ?? ''}';
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('باز کردن درگاه پرداخت ناموفق بود')),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final wallet = _wallet;
    final balance = wallet?.balance ?? me?.balance;
    final dailyRemaining = wallet?.freeDailyRemaining ??
        me?.dailyTokensRemaining ??
        me?.freeDailyRemaining;
    final dailyCap = wallet?.freeDailyCap ?? me?.freeDailyCap;
    final canGenerate = wallet?.canGenerate ?? me?.canGenerate ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('پلن و کیف')),
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
                          'موجودی فعلی',
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
                          'رایگان باقیمانده: ${_fmtNum(wallet?.freeRemaining ?? me?.freeRemaining ?? 0)}'
                          ' · سقف امروز: ${dailyRemaining != null ? _fmtNum(dailyRemaining) : '—'}'
                          '${dailyCap != null ? ' / ${_fmtNum(dailyCap)}' : ''}'
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: PigptColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'شارژ توکن اضافه',
                    subtitle: 'بسته‌های توکن — پرداخت در مرورگر / درگاه',
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
                              onPressed: _busyId != null
                                  ? null
                                  : () => _openPayment(
                                        {'token_package_id': p.id},
                                        'pkg-${p.id}',
                                      ),
                              child: Text(_busyId == 'pkg-${p.id}'
                                  ? '…'
                                  : 'خرید بسته'),
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
                            OutlinedButton(
                              onPressed: null,
                              child: const Text('پلن فعلی'),
                            )
                          else
                            FilledButton(
                              onPressed: _busyId != null
                                  ? null
                                  : () => _openPayment(
                                        {'plan_id': p.id},
                                        'plan-${p.id}',
                                      ),
                              child: Text(_busyId == 'plan-${p.id}'
                                  ? '…'
                                  : 'خرید / ارتقا'),
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
