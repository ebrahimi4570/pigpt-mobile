import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/shimmer.dart';
import '../../shared/widgets/ui.dart';

String _fmtNum(num? n) {
  if (n == null) return '—';
  return n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

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
    final api = ref.read(apiClientProvider);
    try {
      dynamic data;
      try {
        data = await api.get<dynamic>(ApiPaths.usage);
      } catch (_) {
        data = await api.get<dynamic>(ApiPaths.billingTokenLedger);
      }
      if (!mounted) return;
      setState(() {
        _data = data is Map
            ? Map<String, dynamic>.from(data)
            : {'items': data};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'مصرف', showBack: true),
      body: _loading
          ? const ListShimmer(itemCount: 4)
          : _error != null
              ? EmptyState(
                  title: 'مصرف در دسترس نیست',
                  body: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('تلاش دوباره')),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildCards(_data ?? const {}),
                  ),
                ),
    );
  }

  List<Widget> _buildCards(Map<String, dynamic> data) {
    final wallet = data['wallet'] is Map
        ? Map<String, dynamic>.from(data['wallet'] as Map)
        : <String, dynamic>{};
    final messagesUsed = data['messages_used'] ?? data['used'] ?? wallet['daily_tokens_used'];
    final dailyLimit = data['daily_limit'] ?? data['limit'] ?? wallet['daily_token_limit'];
    final remaining = data['remaining'] ??
        data['daily_tokens_remaining'] ??
        wallet['daily_tokens_remaining'] ??
        wallet['free_daily_remaining'];
    final balance = wallet['balance'] ?? data['balance'];
    final items = (data['items'] ?? data['ledger'] ?? data['entries']) is List
        ? (data['items'] ?? data['ledger'] ?? data['entries']) as List
        : const [];

    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'خلاصه امروز',
              subtitle: 'سقف روزانه بر اساس تقویم تهران',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'مصرف پیام/توکن',
                    value: _fmtNum(messagesUsed is num ? messagesUsed : null),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'سقف',
                    value: _fmtNum(dailyLimit is num ? dailyLimit : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'باقیمانده',
                    value: _fmtNum(remaining is num ? remaining : null),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'موجودی کیف',
                    value: _fmtNum(balance is num ? balance : null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionHeader(title: 'ریزتراکنش‌ها'),
        const SizedBox(height: 8),
        ...items.take(40).map((raw) {
          final m = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{'raw': raw};
          final title =
              '${m['description_fa'] ?? m['description'] ?? m['kind'] ?? m['type'] ?? 'تراکنش'}';
          final amount = m['amount'] ?? m['tokens'] ?? m['delta'];
          final at = m['created_at'] ?? m['at'] ?? '';
          return SoftCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if ('$at'.isNotEmpty)
                        Text('$at',
                            style: const TextStyle(
                                color: PigptColors.inkFaint, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  amount != null ? _fmtNum(amount is num ? amount : num.tryParse('$amount')) : '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: PigptColors.brand),
                ),
              ],
            ),
          );
        }),
      ],
      if (items.isEmpty &&
          messagesUsed == null &&
          balance == null &&
          remaining == null) ...[
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جزئیات خام',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SelectableText(
                data.toString(),
                style: const TextStyle(
                    fontSize: 12, color: PigptColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: PigptColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ],
    );
  }
}

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

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
      final data = await ref.read(apiClientProvider).get<dynamic>(ApiPaths.referral);
      if (!mounted) return;
      setState(() {
        _data = data is Map
            ? Map<String, dynamic>.from(data)
            : {'code': data?.toString()};
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

  @override
  Widget build(BuildContext context) {
    final d = _data ?? const {};
    final code = '${d['code'] ?? d['referral_code'] ?? d['invite_code'] ?? ''}';
    final link = '${d['link'] ?? d['url'] ?? d['invite_url'] ?? (code.isNotEmpty ? '${PigptBrand.webUrl}/?ref=$code' : '')}';
    final invited = d['invited_count'] ?? d['referrals'] ?? d['count'];
    final reward = d['reward_fa'] ?? d['reward'] ?? d['bonus_tokens'];

    return Scaffold(
      appBar: const PigptAppBar(title: 'ارجاع', showBack: true),
      body: _loading
          ? const CardShimmer(height: 180)
          : _error != null
              ? EmptyState(
                  title: 'ارجاع',
                  body: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('تلاش دوباره')),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'کد دعوت شما',
                            subtitle: 'دوستان را دعوت کنید و پاداش بگیرید',
                          ),
                          const SizedBox(height: 16),
                          if (code.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: PigptColors.brandSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SelectableText(
                                code,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: PigptColors.brand,
                                ),
                              ),
                            ),
                          if (link.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              link,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontSize: 12, color: PigptColors.inkMuted),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: code.isEmpty && link.isEmpty
                                      ? null
                                      : () {
                                          Clipboard.setData(ClipboardData(
                                              text: link.isNotEmpty
                                                  ? link
                                                  : code));
                                          HapticFeedback.lightImpact();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text('کپی شد')));
                                        },
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('کپی'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: link.isEmpty && code.isEmpty
                                      ? null
                                      : () => Share.share(
                                            link.isNotEmpty ? link : code,
                                            subject: 'دعوت به PiGPT',
                                          ),
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('اشتراک'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'دعوت‌شده‌ها: ${invited ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (reward != null) ...[
                            const SizedBox(height: 6),
                            Text('پاداش: $reward',
                                style: const TextStyle(
                                    color: PigptColors.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
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
  List<Map<String, dynamic>> _tickets = const [];
  bool _loading = true;
  String? _msg;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.supportTickets);
      final list = data is List
          ? data
          : (data is Map
              ? (data['tickets'] ?? data['items'] ?? data['data'] ?? [])
              : []);
      if (!mounted) return;
      setState(() {
        _tickets = (list as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.supportTickets,
        data: {
          'subject': _subject.text.trim(),
          'body': _body.text.trim(),
          'message': _body.text.trim(),
        },
      );
      _subject.clear();
      _body.clear();
      setState(() => _msg = 'تیکت ثبت شد');
      await _load();
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'پشتیبانی', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'تیکت جدید'),
                const SizedBox(height: 8),
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
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? '…' : 'ارسال تیکت'),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: 8),
                  Text(_msg!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'تیکت‌های من'),
          const SizedBox(height: 8),
          if (_loading)
            const SizedBox(height: 120, child: CardShimmer(height: 100))
          else if (_tickets.isEmpty)
            const EmptyState(
              title: 'تیکتی نیست',
              body: 'اولین پیام پشتیبانی را ارسال کنید.',
            )
          else
            ..._tickets.map((t) {
              final id = '${t['id'] ?? ''}';
              final subject = '${t['subject'] ?? t['title'] ?? 'تیکت'}';
              final status = '${t['status'] ?? t['state'] ?? ''}';
              return SoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: id.isEmpty
                    ? null
                    : () => context.push('/account/support/$id'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if (status.isNotEmpty)
                            Text(status,
                                style: const TextStyle(
                                    color: PigptColors.inkMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded,
                        color: PigptColors.inkFaint),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  String? _error;
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.supportTicket(widget.id),
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      if (!mounted) return;
      setState(() => _ticket = data['ticket'] is Map
          ? Map<String, dynamic>.from(data['ticket'] as Map)
          : data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post(
        ApiPaths.supportTicket(widget.id),
        data: {'body': text, 'message': text},
      );
      _reply.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final messages = t == null
        ? const <dynamic>[]
        : (t['messages'] ?? t['replies'] ?? t['thread'] ?? []) as List;

    return Scaffold(
      appBar: const PigptAppBar(title: 'جزئیات تیکت', showBack: true),
      body: t == null
          ? (_error != null
              ? EmptyState(title: 'خطا', body: _error)
              : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['subject'] ?? t['title'] ?? 'تیکت'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('${t['status'] ?? ''}',
                                style: const TextStyle(
                                    color: PigptColors.inkMuted)),
                            if (t['body'] != null || t['message'] != null) ...[
                              const SizedBox(height: 10),
                              Text('${t['body'] ?? t['message']}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'گفتگو'),
                      const SizedBox(height: 8),
                      if (messages.isEmpty)
                        const Text('هنوز پاسخی نیست.',
                            style: TextStyle(color: PigptColors.inkMuted))
                      else
                        ...messages.map((raw) {
                          final m = raw is Map
                              ? Map<String, dynamic>.from(raw)
                              : <String, dynamic>{'body': raw};
                          return SoftCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m['author'] ?? m['role'] ?? m['from'] ?? 'پیام'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: PigptColors.inkMuted),
                                ),
                                const SizedBox(height: 6),
                                Text('${m['body'] ?? m['message'] ?? m['content'] ?? ''}'),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            decoration: const InputDecoration(
                              hintText: 'پاسخ…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy ? null : _sendReply,
                          icon: const Icon(Icons.send_rounded),
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
