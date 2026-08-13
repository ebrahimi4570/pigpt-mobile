import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'ui.dart';

/// Root scaffold key so nested pages can open the right-side drawer.
final rootScaffoldKeyProvider =
    Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());

/// Contextual chat actions registered by the active thread (used by the drawer).
class ChatChromeActions {
  const ChatChromeActions({
    this.conversationId,
    this.title,
    required this.onNewChat,
    required this.onPickModel,
    this.onShare,
    this.onRename,
    this.onPin,
    this.onArchive,
    this.onDelete,
    this.onTemplates,
    this.onRegenerate,
  });

  final String? conversationId;
  final String? title;
  final VoidCallback onNewChat;
  final VoidCallback onPickModel;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onTemplates;
  final VoidCallback? onRegenerate;
}

final chatChromeProvider = StateProvider<ChatChromeActions?>((ref) => null);

void openPigptMenu(BuildContext context, WidgetRef ref) {
  HapticFeedback.selectionClick();
  final state = ref.read(rootScaffoldKeyProvider).currentState;
  if (state == null) return;
  final rtl = Directionality.of(context) == TextDirection.rtl;
  if (rtl) {
    state.openDrawer();
  } else {
    state.openEndDrawer();
  }
}

/// Clean app bar: menu + title (+ optional back). No history/model/share clutter.
class PigptAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const PigptAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = false,
    this.actions,
  });

  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      leadingWidth: 48,
      leading: IconButton(
        tooltip: 'منو',
        onPressed: () => openPigptMenu(context, ref),
        icon: const Icon(Icons.menu_rounded),
      ),
      title: titleWidget ??
          Text(
            title ?? PigptBrand.webDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      actions: [
        if (showBack)
          IconButton(
            tooltip: 'بازگشت',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/chat');
              }
            },
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
            ),
          ),
        ...?actions,
      ],
      backgroundColor: cs.surface.withValues(alpha: 0.94),
    );
  }
}

/// Dense web-like sidebar (icon + 12–13sp label, tight rows, section headers).
class PigptDrawer extends ConsumerWidget {
  const PigptDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final me = ref.watch(meProvider);
    final chrome = ref.watch(chatChromeProvider);
    final muted = PigptColors.mutedOf(context);
    final border = PigptColors.borderOf(context);

    return Drawer(
      width: 272,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0E1624)
          : const Color(0xFFF7F9FC),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(
                children: [
                  const PigptMark(size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PigptBrand.webDisplay,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (me?.greetingName != null)
                          Text(
                            me!.greetingName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 16, color: muted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                children: [
                  _section(context, 'گفتگو'),
                  _row(
                    context,
                    icon: Icons.edit_square,
                    label: 'گفتگوی جدید',
                    active: loc == '/chat' || loc == '/chat/new',
                    onTap: () {
                      Navigator.pop(context);
                      chrome?.onNewChat();
                      context.go('/chat');
                    },
                  ),
                  _row(
                    context,
                    icon: Icons.history_rounded,
                    label: 'تاریخچه',
                    active: loc.startsWith('/chat/history'),
                    onTap: () => _go(context, '/chat/history'),
                  ),
                  _row(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    label: 'مدل',
                    active: loc == '/models',
                    onTap: () {
                      Navigator.pop(context);
                      if (chrome != null) {
                        chrome.onPickModel();
                      } else {
                        context.push('/models');
                      }
                    },
                  ),
                  _row(
                    context,
                    icon: Icons.smart_toy_outlined,
                    label: 'ماموریت ایجنت',
                    active: loc.startsWith('/agent'),
                    onTap: () => _go(context, '/agent'),
                  ),
                  if (chrome?.conversationId != null) ...[
                    _section(context, 'این گفتگو'),
                    if (chrome?.onRename != null)
                      _row(
                        context,
                        icon: Icons.drive_file_rename_outline_rounded,
                        label: 'تغییر نام',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onRename!();
                        },
                      ),
                    if (chrome?.onShare != null)
                      _row(
                        context,
                        icon: Icons.ios_share_rounded,
                        label: 'اشتراک',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onShare!();
                        },
                      ),
                    if (chrome?.onTemplates != null)
                      _row(
                        context,
                        icon: Icons.article_outlined,
                        label: 'قالب‌ها',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onTemplates!();
                        },
                      ),
                    if (chrome?.onRegenerate != null)
                      _row(
                        context,
                        icon: Icons.refresh_rounded,
                        label: 'بازتولید پاسخ',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onRegenerate!();
                        },
                      ),
                    if (chrome?.onPin != null)
                      _row(
                        context,
                        icon: Icons.push_pin_outlined,
                        label: 'سنجاق',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onPin!();
                        },
                      ),
                    if (chrome?.onArchive != null)
                      _row(
                        context,
                        icon: Icons.archive_outlined,
                        label: 'بایگانی',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onArchive!();
                        },
                      ),
                    if (chrome?.onDelete != null)
                      _row(
                        context,
                        icon: Icons.delete_outline_rounded,
                        label: 'حذف گفتگو',
                        onTap: () {
                          Navigator.pop(context);
                          chrome!.onDelete!();
                        },
                      ),
                  ],
                  _section(context, 'شروع سریع'),
                  _row(
                    context,
                    icon: Icons.bolt_outlined,
                    label: 'شروع سریع',
                    active: loc.startsWith('/quick-start'),
                    onTap: () => _go(context, '/quick-start'),
                  ),
                  _section(context, 'استودیوها'),
                  _row(
                    context,
                    icon: Icons.grid_view_rounded,
                    label: 'استودیوها',
                    active: loc == '/studios',
                    onTap: () => _go(context, '/studios'),
                  ),
                  _row(
                    context,
                    icon: Icons.photo_library_outlined,
                    label: 'گالری',
                    active: loc.startsWith('/studios/gallery'),
                    onTap: () => _go(context, '/studios/gallery'),
                  ),
                  _row(
                    context,
                    icon: Icons.image_outlined,
                    label: 'تصویر',
                    active: loc.contains('studio-image'),
                    onTap: () => _go(context, '/studios/studio-image'),
                  ),
                  _row(
                    context,
                    icon: Icons.edit_note_rounded,
                    label: 'نوشتن',
                    active: loc.contains('studio-writing'),
                    onTap: () => _go(context, '/studios/studio-writing'),
                  ),
                  _row(
                    context,
                    icon: Icons.movie_outlined,
                    label: 'رسانه',
                    active: loc.contains('studio-media'),
                    onTap: () => _go(context, '/studios/studio-media'),
                  ),
                  _section(context, 'حساب'),
                  _row(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'پلن و کیف',
                    active: loc.startsWith('/account/plans'),
                    onTap: () => _go(context, '/account/plans'),
                  ),
                  _row(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'فاکتورها',
                    active: loc.startsWith('/account/invoices'),
                    onTap: () => _go(context, '/account/invoices'),
                  ),
                  _row(
                    context,
                    icon: Icons.bar_chart_rounded,
                    label: 'مصرف',
                    active: loc.startsWith('/account/usage'),
                    onTap: () => _go(context, '/account/usage'),
                  ),
                  _row(
                    context,
                    icon: Icons.tune_rounded,
                    label: 'تنظیمات',
                    active: loc.startsWith('/account/settings'),
                    onTap: () => _go(context, '/account/settings'),
                  ),
                  _row(
                    context,
                    icon: Icons.support_agent_rounded,
                    label: 'پشتیبانی',
                    active: loc.startsWith('/account/support'),
                    onTap: () => _go(context, '/account/support'),
                  ),
                  _row(
                    context,
                    icon: Icons.card_giftcard_rounded,
                    label: 'ارجاع',
                    active: loc.startsWith('/account/referral'),
                    onTap: () => _go(context, '/account/referral'),
                  ),
                  _row(
                    context,
                    icon: Icons.terminal_rounded,
                    label: 'راهنمای PiCode',
                    active: loc.startsWith('/account/picode'),
                    onTap: () => _go(context, '/account/picode'),
                  ),
                  _row(
                    context,
                    icon: Icons.info_outline_rounded,
                    label: 'درباره',
                    active: loc.startsWith('/account/about'),
                    onTap: () => _go(context, '/account/about'),
                  ),
                  _row(
                    context,
                    icon: Icons.logout_rounded,
                    label: 'خروج',
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/auth');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.pop(context);
    context.go(path);
  }

  Widget _section(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: PigptColors.faintOf(context),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final brand = Theme.of(context).colorScheme.primary;
    final muted = PigptColors.mutedOf(context);
    final ink = PigptColors.inkOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Material(
        color: active
            ? brand.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 16, color: active ? brand : muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? ink : muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
