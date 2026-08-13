import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_chrome.dart';
import '../../shared/widgets/ui.dart';

/// PiCode guide / install only — no embedded CLI runtime.
class PiCodeGuideScreen extends ConsumerStatefulWidget {
  const PiCodeGuideScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<PiCodeGuideScreen> createState() => _PiCodeGuideScreenState();
}

class _PiCodeGuideScreenState extends ConsumerState<PiCodeGuideScreen> {
  late final TextEditingController _code;
  String? _msg;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
            ApiPaths.cliDeviceConfirm,
            data: {'user_code': _code.text.trim().toUpperCase()},
            parser: (d) => Map<String, dynamic>.from(d as Map),
          );
      setState(() {
        _msg = '${res['message_fa'] ?? 'تأیید شد'}';
        _code.clear();
      });
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PigptAppBar(title: 'راهنمای ${PigptBrand.cliDisplay}', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${PigptBrand.cliDisplay} چیست؟',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'CLI خواهر PiGPT برای دسکتاپ. در اپ موبایل فقط راهنمای نصب و تأیید دستگاه ارائه می‌شود — بدون ترمینال یا runtime.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: PigptColors.inkMuted,
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'API پیش‌فرض:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                LtrCodeBlock(code: PigptBrand.apiBase),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'نصب Unix / macOS / WSL'),
                const SizedBox(height: 8),
                LtrCodeBlock(code: PigptBrand.installUnix),
                const SizedBox(height: 16),
                const SectionHeader(title: 'نصب Windows'),
                const SizedBox(height: 8),
                LtrCodeBlock(code: PigptBrand.installWindows),
                const SizedBox(height: 8),
                LtrCodeBlock(code: PigptBrand.installWindowsAlt),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(PigptBrand.downloadsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('صفحه دانلود'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'ورود CLI'),
                const SizedBox(height: 8),
                Text(
                  'در ترمینال دسکتاپ دستور زیر را بزنید؛ مرورگر باز می‌شود.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: PigptColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 8),
                LtrCodeBlock(code: '${PigptBrand.cliName} login'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'تأیید کد دستگاه (اختیاری)',
                  subtitle: 'فقط اگر picode login --manual لازم شد',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _code,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'کد دستگاه',
                    hintText: 'ABCD-EFGH',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('تأیید'),
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
