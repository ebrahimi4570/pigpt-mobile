import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/media_io.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/ui.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
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
      final data =
          await ref.read(apiClientProvider).get<dynamic>(ApiPaths.billingPaymentsMe);
      final list = data is List
          ? data
          : (data is Map
              ? (data['payments'] ?? data['items'] ?? data['data'] ?? [])
              : []);
      setState(() {
        _items = (list as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
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

  String _label(Map<String, dynamic> p) {
    final plan = p['plan'];
    final pkg = p['token_package'];
    if (plan is Map) return '${plan['name_fa'] ?? plan['name'] ?? 'پلن'}';
    if (pkg is Map) return '${pkg['name_fa'] ?? pkg['name'] ?? 'بسته توکن'}';
    return '${p['description_fa'] ?? 'پرداخت'}';
  }

  String _statusFa(String s) {
    return switch (s) {
      'paid' || 'stub' => 'پرداخت‌شده',
      'pending' => 'در انتظار',
      'failed' => 'ناموفق',
      'canceled' || 'cancelled' => 'لغو',
      _ => s,
    };
  }

  Future<void> _openPdf(String id) async {
    setState(() => _busyId = id);
    try {
      final bytes =
          await ref.read(apiClientProvider).getBytes(ApiPaths.billingInvoicePdf(id));
      if (bytes.isEmpty) throw ApiException('فاکتور خالی بود');
      final file = await MediaIo.writeTempBytes(bytes, 'invoice-$id.pdf');
      await Share.shareXFiles([XFile(file.path)]);
    } on ApiException catch (e) {
      if (mounted) MediaIo.toast(context, e.message);
    } catch (e) {
      if (mounted) MediaIo.toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigptAppBar(title: 'فاکتورها', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  title: 'فاکتورها',
                  body: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('تلاش دوباره'),
                  ),
                )
              : _items.isEmpty
                  ? const EmptyState(
                      title: 'فاکتوری نیست',
                      body: 'پس از پرداخت موفق، فاکتور اینجا می‌آید.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _items[i];
                          final id = '${p['id'] ?? ''}';
                          final status = '${p['status'] ?? ''}';
                          final paid = status == 'paid' || status == 'stub';
                          return SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(_label(p),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_statusFa(status)}'
                                  '${p['amount_rial'] != null ? ' · ${p['amount_rial']} ریال' : ''}',
                                  style: TextStyle(
                                    color: PigptColors.mutedOf(context),
                                    fontSize: 12,
                                  ),
                                ),
                                if (p['created_at'] != null)
                                  Text(
                                    '${p['created_at']}',
                                    style: TextStyle(
                                      color: PigptColors.faintOf(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                if (paid && id.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _busyId == id ? null : () => _openPdf(id),
                                    icon: const Icon(Icons.picture_as_pdf_outlined),
                                    label: Text(_busyId == id
                                        ? '…'
                                        : 'دانلود / اشتراک PDF'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
