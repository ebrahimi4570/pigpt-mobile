import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import 'ui.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = navigationShell.currentIndex;
    return Scaffold(
      // Keep indexed-stack branch state; motion lives in destinations + nav chrome.
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: PigptColors.bgElevated,
          indicatorColor: PigptColors.brandSoft,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? PigptColors.brand : PigptColors.inkFaint,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected ? PigptColors.brand : PigptColors.inkMuted,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: _goBranch,
          backgroundColor: PigptColors.bgElevated,
          indicatorColor: PigptColors.brandSoft,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded,
                  color: PigptColors.inkMuted),
              selectedIcon: Icon(Icons.chat_bubble_rounded,
                  color: PigptColors.brand),
              label: 'گفتگو',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined, color: PigptColors.inkMuted),
              selectedIcon:
                  Icon(Icons.bolt_rounded, color: PigptColors.brand),
              label: 'شروع سریع',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded, color: PigptColors.inkMuted),
              selectedIcon:
                  Icon(Icons.grid_view_rounded, color: PigptColors.brand),
              label: 'استودیوها',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded,
                  color: PigptColors.inkMuted),
              selectedIcon:
                  Icon(Icons.person_rounded, color: PigptColors.brand),
              label: 'حساب',
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15, end: 0),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color(0xFF14302C), PigptColors.bg],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PigptMark(size: 88)
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.85, 0.85))
                .then()
                .shimmer(duration: 1200.ms, color: PigptColors.brandSoft),
            const SizedBox(height: 20),
            Text(
              PigptBrand.webDisplay,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 8),
            Text(
              PigptBrand.taglineFa,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PigptColors.inkMuted,
                  ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
