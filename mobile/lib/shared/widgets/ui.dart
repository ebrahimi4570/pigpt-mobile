import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';

class PigptMark extends StatelessWidget {
  const PigptMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        PigptBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: PigptBrand.webDisplay,
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.dense = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : padding;
    final mar = margin ?? (dense ? const EdgeInsets.only(bottom: 4) : null);
    final card = Container(
      margin: mar,
      padding: pad,
      constraints: dense ? const BoxConstraints(minHeight: 44) : null,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? PigptColors.bgElevated
            : Colors.white,
        borderRadius: BorderRadius.circular(dense ? 12 : 16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? PigptColors.border
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: card,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PigptColors.inkMuted,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.action,
  });
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PigptMark(size: 56)
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PigptColors.inkMuted,
                      height: 1.6,
                    ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(label: 'به‌زودی');
  }
}

class PlanLockBadge extends StatelessWidget {
  const PlanLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(label: 'قفل پلن');
  }
}

/// Badge for the user's active subscription plan (not «به‌زودی»).
class CurrentPlanBadge extends StatelessWidget {
  const CurrentPlanBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(label: 'پلن فعلی');
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PigptColors.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PigptColors.brand,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class WalletBanner extends StatelessWidget {
  const WalletBanner({
    super.key,
    required this.canGenerate,
    this.balance,
    this.dailyRemaining,
    this.dailyCap,
    this.dailyUnlimited = false,
    this.nearCap = false,
    this.onTopUp,
  });

  final bool canGenerate;
  final num? balance;
  final num? dailyRemaining;
  final num? dailyCap;
  final bool dailyUnlimited;
  final bool nearCap;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    if (canGenerate &&
        !nearCap &&
        dailyRemaining == null &&
        balance == null) {
      return const SizedBox.shrink();
    }
    final blocked = !canGenerate;
    final warn = !blocked && nearCap;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            blocked
                ? Icons.warning_amber_rounded
                : warn
                    ? Icons.timelapse_rounded
                    : Icons.account_balance_wallet_outlined,
            color: blocked || warn ? PigptColors.warning : PigptColors.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocked
                      ? 'سقف روزانه یا موجودی کافی نیست'
                      : warn
                          ? 'باقیمانده امروز کم است: ${dailyRemaining ?? '—'}'
                          : dailyUnlimited
                              ? 'موجودی کیف: ${balance ?? '—'} · بدون سقف روزانه'
                              : 'موجودی کیف: ${balance ?? '—'} · باقیمانده امروز: ${dailyRemaining ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (blocked)
                  Text(
                    'برای ادامه، پلن را ارتقا دهید یا منتظر ریست سقف تهران بمانید.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PigptColors.inkMuted,
                        ),
                  )
                else if (warn)
                  Text(
                    'قبل از اتمام سقف، کیف را شارژ کنید.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PigptColors.inkMuted,
                        ),
                  ),
              ],
            ),
          ),
          if (onTopUp != null)
            TextButton(onPressed: onTopUp, child: const Text('شارژ')),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: -0.08, end: 0);
  }
}

class LtrCodeBlock extends StatelessWidget {
  const LtrCodeBlock({super.key, required this.code, this.onCopy});
  final String code;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PigptColors.codeBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PigptColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: PigptColors.inkOf(context),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'کپی',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              HapticFeedback.lightImpact();
              onCopy?.call();
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key, this.label = 'در حال بارگذاری…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PigptMark(size: 64)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  duration: 900.ms,
                ),
            const SizedBox(height: 20),
            Text(label),
          ],
        ),
      ),
    );
  }
}
