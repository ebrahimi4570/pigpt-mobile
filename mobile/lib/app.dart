import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand.dart';
import 'core/deep_links.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

class PigptApp extends ConsumerWidget {
  const PigptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isFa = locale.languageCode != 'en';

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
          return Directionality(
            textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        routerConfig: router,
      ),
    );
  }
}
