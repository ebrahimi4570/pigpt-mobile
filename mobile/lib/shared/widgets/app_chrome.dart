import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'command_palette.dart';
import 'ui.dart';

/// Root scaffold key so nested pages can open the right-side drawer.
final rootScaffoldKeyProvider =
    Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());

/// Contextual actions for the open thread (shown in the app-bar ⋮ menu, not the drawer).
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

/// Clean app bar: menu + title + thread ⋮ + avatar. Drawer is app-level nav only.
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
        ...?actions,
        const _ChatOverflowButton(),
        const _AccountAvatarButton(),
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
      ],
      backgroundColor: cs.surface.withValues(alpha: 0.94),
    );
  }
}

class _ChatOverflowButton extends ConsumerWidget {
  const _ChatOverflowButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(chatChromeProvider);
    if (chrome == null) return const SizedBox.shrink();
    final muted = PigptColors.mutedOf(context);
    return PopupMenuButton<String>(
      tooltip: 'این گفتگو',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      icon: Icon(Icons.more_vert_rounded, color: muted),
      onSelected: (value) {
        HapticFeedback.selectionClick();
        final c = ref.read(chatChromeProvider);
        if (c == null) return;
        switch (value) {
          case 'model':
            c.onPickModel();
          case 'rename':
            c.onRename?.call();
          case 'share':
            c.onShare?.call();
          case 'templates':
            c.onTemplates?.call();
          case 'regen':
            c.onRegenerate?.call();
          case 'pin':
            c.onPin?.call();
          case 'archive':
            c.onArchive?.call();
          case 'delete':
            c.onDelete?.call();
          default:
            break;
        }
      },
      itemBuilder: (ctx) {
        final c = ref.read(chatChromeProvider);
        if (c == null) return const [];
        final danger = PigptColors.danger;
        return <PopupMenuEntry<String>>[
          const PopupMenuItem(
            value: 'model',
            child: _OverflowRow(
              icon: Icons.auto_awesome_rounded,
              label: 'مدل این گفتگو',
            ),
          ),
          if (c.onRename != null)
            const PopupMenuItem(
              value: 'rename',
              child: _OverflowRow(
                icon: Icons.drive_file_rename_outline_rounded,
                label: 'تغییر نام',
              ),
            ),
          if (c.onShare != null)
            const PopupMenuItem(
              value: 'share',
              child: _OverflowRow(
                icon: Icons.ios_share_rounded,
                label: 'اشتراک',
              ),
            ),
          if (c.onTemplates != null)
            const PopupMenuItem(
              value: 'templates',
              child: _OverflowRow(
                icon: Icons.article_outlined,
                label: 'قالب‌ها',
              ),
            ),
          if (c.onRegenerate != null)
            const PopupMenuItem(
              value: 'regen',
              child: _OverflowRow(
                icon: Icons.refresh_rounded,
                label: 'بازتولید پاسخ',
              ),
            ),
          if (c.onPin != null)
            const PopupMenuItem(
              value: 'pin',
              child: _OverflowRow(
                icon: Icons.push_pin_outlined,
                label: 'سنجاق',
              ),
            ),
          if (c.onArchive != null)
            const PopupMenuItem(
              value: 'archive',
              child: _OverflowRow(
                icon: Icons.archive_outlined,
                label: 'بایگانی',
              ),
            ),
          if (c.onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: _OverflowRow(
                icon: Icons.delete_outline_rounded,
                label: 'حذف گفتگو',
                color: danger,
              ),
            ),
        ];
      },
    );
  }
}

class _OverflowRow extends StatelessWidget {
  const _OverflowRow({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PigptColors.inkOf(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _AccountAvatarButton extends ConsumerWidget {
  const _AccountAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final name = me?.greetingName ?? 'PiGPT';
    final letter = name.isNotEmpty ? name.characters.first : 'π';
    final onAccount = GoRouterState.of(context).uri.path.startsWith('/account');
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Tooltip(
        message: 'حساب و تنظیمات',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            if (onAccount) return;
            context.go('/account');
          },
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: onAccount ? 0.28 : 0.18),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dense web-like sidebar: app-level nav only (icon ~20px, label ~14sp).
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
      width: 284,
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
                    icon: Icons.smart_toy_outlined,
                    label: 'ایجنت',
                    active: loc.startsWith('/agent'),
                    onTap: () => _go(context, '/agent'),
                  ),
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
                  _section(context, 'ابزار'),
                  _row(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    label: 'مدل‌ها',
                    active: loc == '/models' || loc.startsWith('/models'),
                    onTap: () => _go(context, '/models'),
                  ),
                  _row(
                    context,
                    icon: Icons.search_rounded,
                    label: 'جستجو',
                    onTap: () {
                      Navigator.pop(context);
                      showPigptCommandPalette(context, ref);
                    },
                  ),
                  _row(
                    context,
                    icon: Icons.terminal_rounded,
                    label: 'برنامه‌نویسی / PiCode',
                    active: loc.startsWith('/account/picode') ||
                        loc.startsWith('/app/cli'),
                    onTap: () => _go(context, '/account/picode'),
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
                    icon: Icons.menu_book_outlined,
                    label: 'بلاگ',
                    onTap: () async {
                      Navigator.pop(context);
                      await launchUrl(
                        Uri.parse('${PigptBrand.webUrl}/blog'),
                        mode: LaunchMode.externalApplication,
                      );
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
          fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active
            ? brand.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? brand : muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
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
