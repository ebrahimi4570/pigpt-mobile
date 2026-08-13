import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Honor OS Reduce Motion (`MediaQuery.disableAnimations`).
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Apply once from [MaterialApp.builder] so flutter_animate respects the OS.
void syncReduceMotion(BuildContext context) {
  Animate.restartOnHotReload = false;
  // flutter_animate 4.x: setting default duration to zero effectively skips motion.
  if (MediaQuery.disableAnimationsOf(context)) {
    Animate.defaultDuration = Duration.zero;
  } else {
    Animate.defaultDuration = const Duration(milliseconds: 300);
  }
}
