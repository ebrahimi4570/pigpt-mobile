import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/ui.dart';

String _fmtToman(num? rial) {
  if (rial == null) return '—';
  if (rial == 0) return 'رایگان';
  final toman = (rial / 10).round();
  return '${NumberFormat.decimalPattern('fa').format(toman)} تومان';
}

String _fmtFaDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('yyyy/MM/dd HH:mm', 'fa').format(dt);
  } catch (_) {
    return iso.length > 19 ? iso.substring(0, 19) : iso;
  }
}

/// Submit card-to-card payment request (plan or token package).
class OfflinePayScreen extends ConsumerStatefulWidget {
  const OfflinePayScreen({
    super.key,
    this.planId,
    this.packageId,
  });

  final String? planId;
  final String? packageId;

  @override
  ConsumerState<OfflinePayScreen> createState() => _OfflinePayScreenState();
}

class _OfflinePayScreenState extends ConsumerState<OfflinePayScreen> {
  Map<String, dynamic>? _settings;
  String _itemLabel = '';
  num _amount = 0;
  final _last4 = TextEditingController();
  final _tracking = TextEditingController();
  final _note = TextEditingController();
  String? _receiptPath;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _last4.dispose();
    _tracking.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final s = await api.get<Map<String, dynamic>>(
        ApiPaths.billingOfflineSettings,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      String label = '';
      num amount = 0;
      final planId = widget.planId;
      final pkgId = widget.packageId;
      if (planId != null && planId.isNotEmpty) {
        final data = await api.get<Map<String, dynamic>>(
          ApiPaths.billingPlans,
          parser: (d) => Map<String, dynamic>.from(d as Map),
        );
        final list = (data['plans'] ?? data['items'] ?? []) as List;
        final p = list.whereType<Map>().cast<Map>().firstWhere(
              (e) => '${e['id']}' == planId,
              orElse: () => {},
            );
        if (p.isEmpty) {
          throw ApiException('پلن یافت نشد');
        }
        label = '${p['name_fa'] ?? p['name'] ?? 'پلن'}';
        amount = (p['price_rial'] as num?) ?? 0;
      } else if (pkgId != null && pkgId.isNotEmpty) {
        final data = await api.get<Map<String, dynamic>>(
          ApiPaths.billingTokenPackages,
          parser: (d) => Map<String, dynamic>.from(d as Map),
        );
        final list = (data['packages'] ?? data['items'] ?? []) as List;
        final p = list.whereType<Map>().cast<Map>().firstWhere(
              (e) => '${e['id']}' == pkgId,
              orElse: () => {},
            );
        if (p.isEmpty) {
          throw ApiException('بسته یافت نشد');
        }
        label = '${p['name_fa'] ?? p['name'] ?? 'بسته'}';
        amount = (p['price_rial'] as num?) ?? 0;
      } else {
        throw ApiException('پلن یا بسته انتخاب نشده است');
      }
      if (!mounted) return;
      setState(() {
        _settings = s;
        _itemLabel = label;
        _amount = amount;
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

  Future<void> _pickReceipt() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (img == null) return;
    setState(() => _receiptPath = img.path);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final last4 = _last4.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) {
      setState(() => _error = '۴ رقم آخر کارت مبدأ را وارد کنید');
      return;
    }
    if (_receiptPath == null) {
      setState(() => _error = 'تصویر رسید را انتخاب کنید');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final uploaded = await api.uploadFile(
        _receiptPath!,
        purpose: 'offline_receipt',
      );
      final receiptId = '${uploaded['id'] ?? ''}';
      if (receiptId.isEmpty) throw ApiException('آپلود رسید ناموفق بود');
      final body = <String, dynamic>{
        'payer_card_last4': last4,
        'receipt_asset_id': receiptId,
        if (widget.planId != null && widget.planId!.isNotEmpty)
          'plan_id': widget.planId,
        if (widget.packageId != null && widget.packageId!.isNotEmpty)
          'token_package_id': widget.packageId,
        if (_tracking.text.trim().isNotEmpty)
          'tracking_code': _tracking.text.trim(),
        if (_note.text.trim().isNotEmpty) 'user_note': _note.text.trim(),
      };
      await api.post(ApiPaths.billingOfflineRequests, data: body);
      if (!mounted) return;
      context.go('/account/offline-payments');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final enabled = s?['is_enabled'] == true;
    final configured = s?['configured'] == true;
    final cards = (s?['cards'] is List) ? s!['cards'] as List : const [];

    return Scaffold(
      appBar: const PigptAppBar(
        title: 'ثبت پرداخت کارت‌به‌کارت',
        showBack: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'مبلغ را به کارت زیر واریز کنید و رسید را ثبت کنید. پس از تأیید، اعتبار به حسابتان اضافه می‌شود.',
                  style: TextStyle(color: PigptColors.inkMuted, height: 1.6),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'اطلاعات واریز',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (configured) ...[
                        if (cards.isNotEmpty)
                          ...cards.whereType<Map>().map((c) {
                            final cardNumber = '${c['card_number'] ?? ''}';
                            final holder = '${c['card_holder_fa'] ?? ''}';
                            final bank = '${c['bank_name_fa'] ?? ''}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    cardNumber,
                                    textDirection: ui.TextDirection.ltr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (holder.isNotEmpty)
                                    Text('به نام $holder'),
                                  if (bank.isNotEmpty)
                                    Text(
                                      bank,
                                      style: const TextStyle(
                                        color: PigptColors.inkMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                        else ...[
                          SelectableText(
                            '${s?['card_number'] ?? ''}',
                            textDirection: ui.TextDirection.ltr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                          if ('${s?['card_holder_fa'] ?? ''}'.isNotEmpty)
                            Text('به نام ${s!['card_holder_fa']}'),
                          if ('${s?['bank_name_fa'] ?? ''}'.isNotEmpty)
                            Text(
                              '${s!['bank_name_fa']}',
                              style: const TextStyle(
                                color: PigptColors.inkMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                        if ('${s?['instructions_fa'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${s!['instructions_fa']}',
                            style: const TextStyle(
                              color: PigptColors.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'معمولاً تا ${s?['sla_hours'] ?? 24} ساعت بررسی می‌شود.',
                          style: const TextStyle(
                            color: PigptColors.inkFaint,
                            fontSize: 12,
                          ),
                        ),
                      ] else
                        const Text(
                          'کارت مقصد هنوز در پنل ثبت نشده. با پشتیبانی تماس بگیرید.',
                          style: TextStyle(color: PigptColors.warning),
                        ),
                    ],
                  ),
                ),
                if (_itemLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مورد انتخاب‌شده',
                          style: TextStyle(
                            color: PigptColors.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _itemLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtToman(_amount),
                          style: const TextStyle(
                            color: PigptColors.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
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
                const SizedBox(height: 12),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _last4,
                        decoration: const InputDecoration(
                          labelText: '۴ رقم آخر کارت مبدأ',
                          hintText: '1234',
                        ),
                        keyboardType: TextInputType.number,
                        textDirection: ui.TextDirection.ltr,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tracking,
                        decoration: const InputDecoration(
                          labelText: 'شماره پیگیری (اختیاری)',
                        ),
                        textDirection: ui.TextDirection.ltr,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickReceipt,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(
                          _receiptPath == null
                              ? 'انتخاب تصویر رسید'
                              : 'رسید انتخاب شد',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'توضیح (اختیاری)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _busy || !enabled ? null : _submit,
                        child: Text(_busy ? '…' : 'ثبت درخواست'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// List of user's offline (card-to-card) payment requests + status.
class OfflineRequestsScreen extends ConsumerStatefulWidget {
  const OfflineRequestsScreen({super.key});

  @override
  ConsumerState<OfflineRequestsScreen> createState() =>
      _OfflineRequestsScreenState();
}

class _OfflineRequestsScreenState extends ConsumerState<OfflineRequestsScreen> {
  List<Map<String, dynamic>> _rows = const [];
  String? _error;
  bool _loading = true;
  String? _busyId;

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
            ApiPaths.billingOfflineRequestsMe,
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      final list = (data['requests'] ?? data['items'] ?? []) as List;
      if (!mounted) return;
      setState(() {
        _rows = list
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

  Future<void> _cancel(String id) async {
    setState(() => _busyId = id);
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiPaths.billingOfflineRequestCancel(id));
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => const Color(0xFF059669),
      'rejected' => PigptColors.danger,
      'pending' => const Color(0xFFD97706),
      _ => PigptColors.inkMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(
        title: 'پرداخت‌های کارت‌به‌کارت',
        showBack: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'درخواست‌های واریز و وضعیت هر کدام.',
                    style: TextStyle(color: PigptColors.inkMuted),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/account/plans'),
                      child: const Text('بازگشت به پلن‌ها'),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: PigptColors.danger),
                      ),
                    ),
                  if (_rows.isEmpty)
                    const SoftCard(
                      child: Text(
                        'هنوز درخواستی ثبت نشده است.',
                        style: TextStyle(color: PigptColors.inkMuted),
                      ),
                    )
                  else
                    ..._rows.map((r) {
                      final id = '${r['id'] ?? ''}';
                      final status = '${r['status'] ?? ''}';
                      final label =
                          '${r['status_label_fa'] ?? status}';
                      final plan = r['plan'];
                      final pkg = r['token_package'];
                      final title = plan is Map
                          ? '${plan['name_fa'] ?? plan['name'] ?? 'پلن'}'
                          : pkg is Map
                              ? '${pkg['name_fa'] ?? pkg['name'] ?? 'بسته'}'
                              : 'پرداخت';
                      final reason = '${r['rejection_reason_fa'] ?? ''}'.trim();
                      return SoftCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _fmtToman(r['amount_rial'] as num?),
                              style: const TextStyle(
                                color: PigptColors.inkMuted,
                              ),
                            ),
                            if (_fmtFaDate(r['created_at']?.toString())
                                .isNotEmpty)
                              Text(
                                _fmtFaDate(r['created_at']?.toString()),
                                style: const TextStyle(
                                  color: PigptColors.inkFaint,
                                  fontSize: 11,
                                ),
                              ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                reason,
                                style: const TextStyle(
                                  color: PigptColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (status == 'pending' && id.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed:
                                    _busyId == id ? null : () => _cancel(id),
                                child: Text(
                                  _busyId == id ? '…' : 'لغو درخواست',
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
