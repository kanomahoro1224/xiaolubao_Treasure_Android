import 'package:flutter/widgets.dart';

import '../kano/data/kano_theme.dart';
import 'themed_bottom_bar.dart';

/// 底栏占位高度。
///
/// `GlassScaffold` 开着 `extendBody: true` 时 body 是 `Positioned.fill`，
/// **不会**自动给底栏让位，所以每个滚动页都要自己按这个值补底部内边距，
/// 否则最后一项会藏在浮岛底下、怎么滑都滑不出来。
class ShellMetrics {
  const ShellMetrics._();

  /// 浮岛底栏的总高：上留白 12 + 岛高 56 + 下留白 12
  static const double floatingBarHeight = 80;

  /// 手机 + 有激活主题时才换成主题底图栏，口径与 `app_shell` 里
  /// `isThemedTailBarShown()` 保持一致（宽 ≥ 600 退回浮岛）。
  static bool usesThemedBar(BuildContext context) =>
      KanoThemeManager.instance.hasActive &&
      MediaQuery.sizeOf(context).width < 600;

  /// 底栏在窗口底部占掉的高度，不含系统手势区。
  static double bottomBarHeight(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return usesThemedBar(context)
        ? ThemedBottomBar.heightFor(safeBottom) - safeBottom
        : floatingBarHeight;
  }

  /// 滚动内容底部要留的总高度：系统手势区 + 底栏 + 一点余量。
  static double scrollBottomInset(BuildContext context, {double gap = 12}) =>
      MediaQuery.viewPaddingOf(context).bottom +
      bottomBarHeight(context) +
      gap;
}
