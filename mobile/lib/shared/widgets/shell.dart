import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import 'app_chrome.dart';
import 'ui.dart';

/// Main chrome: no bottom nav. Right-side dense drawer + page body.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(rootScaffoldKeyProvider);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final menu = const PigptDrawer();
    return Scaffold(
      key: key,
      // RTL start = physical right; LTR uses endDrawer so the panel stays right.
      drawer: rtl ? menu : null,
      endDrawer: rtl ? null : menu,
      drawerEnableOpenDragGesture: true,
      endDrawerEnableOpenDragGesture: true,
      body: child,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = reduceMotionOf(context);
    Widget mark = const PigptMark(size: 88);
    Widget title = Text(
      PigptBrand.webDisplay,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
    Widget tag = Text(
      PigptBrand.taglineFa,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PigptColors.mutedOf(context),
          ),
    );
    if (!reduce) {
      mark = mark
          .animate()
          .fadeIn(duration: 500.ms)
          .scale(begin: const Offset(0.85, 0.85))
          .then()
          .shimmer(duration: 1200.ms, color: PigptColors.brandSoft);
      title = title.animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, end: 0);
      tag = tag.animate().fadeIn(delay: 200.ms);
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: dark
                ? const [Color(0xFF14302C), PigptColors.bg]
                : const [Color(0xFFD7EDEA), PigptColors.lightBg],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            mark,
            const SizedBox(height: 20),
            title,
            const SizedBox(height: 8),
            tag,
          ],
        ),
      ),
    );
  }
}
