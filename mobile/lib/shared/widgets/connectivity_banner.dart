import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';

/// Always-on live connectivity surface. One banner; updates in place.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(netStatusProvider);
    if (ui == NetUi.online) return const SizedBox.shrink();
    final offline = ui == NetUi.offline;
    return Material(
      color: offline ? const Color(0xFFF59E0B) : const Color(0xFF059669),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            offline
                ? 'اتصال اینترنت قطع است — پس از وصل شدن، همین نوار به‌روز می‌شود.'
                : 'متصل شد',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: offline ? const Color(0xFF451A03) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
