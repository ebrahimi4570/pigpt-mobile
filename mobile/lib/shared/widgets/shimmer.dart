import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme.dart';

/// Dark-theme-friendly list skeleton using the shimmer package.
class ListShimmer extends StatelessWidget {
  const ListShimmer({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF1A2436) : const Color(0xFFE8EEF5);
    final highlight = dark ? const Color(0xFF243044) : const Color(0xFFF5F8FC);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: PigptColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class ChatThreadShimmer extends StatelessWidget {
  const ChatThreadShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF1A2436) : const Color(0xFFE8EEF5);
    final highlight = dark ? const Color(0xFF243044) : const Color(0xFFF5F8FC);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 64,
              width: 220,
              decoration: BoxDecoration(
                color: PigptColors.bgElevated,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 96,
              width: 280,
              decoration: BoxDecoration(
                color: PigptColors.bgElevated,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 48,
              width: 160,
              decoration: BoxDecoration(
                color: PigptColors.bgElevated,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardShimmer extends StatelessWidget {
  const CardShimmer({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1A2436) : const Color(0xFFE8EEF5),
      highlightColor: dark ? const Color(0xFF243044) : const Color(0xFFF5F8FC),
      child: Container(
        height: height,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PigptColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class GridShimmer extends StatelessWidget {
  const GridShimmer({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1A2436) : const Color(0xFFE8EEF5),
      highlightColor: dark ? const Color(0xFF243044) : const Color(0xFFF5F8FC),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: PigptColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
