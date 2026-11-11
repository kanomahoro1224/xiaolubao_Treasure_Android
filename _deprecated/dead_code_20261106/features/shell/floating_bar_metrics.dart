import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingBarMetrics {
  const FloatingBarMetrics._();

  static const maxWidth = 360.0;
  static const horizontalRatio = 0.94;
  static const bottomBarHeight = 56.0;
  static const miniPlayerHeight = 52.0;
  static const contentPadding = 8.0;
  static const glowAlpha = 0.34;
  static const glowRadius = 1.55;
  static const pressDuration = Duration(milliseconds: 150);

  static double widthFor(BuildContext context) {
    return math.min(MediaQuery.sizeOf(context).width * horizontalRatio, maxWidth);
  }
}
