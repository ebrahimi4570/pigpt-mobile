import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand.dart';
import 'core/deep_links.dart';
import 'core/motion.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'shared/widgets/connectivity_banner.dart';

class PigptApp extends ConsumerWidget {
  const PigptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isFa = locale.languageCode != 'en';

    ref.listen<String?>(planLockedMessageProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      final nav = router.routerDelegate.navigatorKey.currentContext;
      if (nav == null) return;
      ref.read(planLockedMessageProvider.notifier).state = null;
      showDialog<void>(
        context: nav,
        builder: (ctx) => AlertDialog(
          title: const Text('محدودیت پلن'),
          content: Text(next),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                router.push('/account/plans');
              },
              child: const Text('مشاهده پلن‌ها'),
            ),
          ],
        ),
      );
    });

    return DeepLinkBootstrap(
      child: MaterialApp.router(
        title: PigptBrand.webDisplay,
        debugShowCheckedModeBanner: false,
        theme: PigptTheme.light(),
        darkTheme: PigptTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          syncReduceMotion(context);
          return Directionality(
            textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              children: [
                const ConnectivityBanner(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
          );
        },
        routerConfig: router,
      ),
    );
  }
}
