import 'package:flutter/material.dart';

import '../kano/data/kano_theme.dart';
import '../kano/presentation/kano_haptics.dart';
import '../settings/settings_controller.dart';
import 'shell_tab.dart';

/// 主题底栏，只在手机宽度下出现（鸿蒙 `isThemedTailBarShown()`：`screenWidth < 600`）。
///
/// 对应 `Home.ets` 的 `ThemedFloatingBottomBar` + `BottomTabItemView(tab, true)`：
///
/// ```ts
/// Image(getTailBgPath()).width('106%').height(70).position({ x: '-3%', y: 0 })
/// Column({ space: 2 }) { Image(55x55); Text(10).margin({ top: -10 }) }
///   .height(56).margin({ top: -50 })        // 图标整体上提，浮在底图上方
/// .padding({ left: '3%', right: '3%', bottom: 12 })
/// ```
///
/// 三个关键点，少一个就还原不出来：
/// 1. 底图是 5:1 的整幅画，从页签行的顶边往下铺 70，比行高多出 14 压到手势区上沿；
/// 2. 页签行仍是 56 高，但整块上提 50，于是图标浮在底图上方、文字压在底图上；
/// 3. 文字固定深色（底图是浅色画），不跟随系统深浅色 —— `themedBarTextColor`。
class ThemedBottomBar extends StatefulWidget {
  const ThemedBottomBar({
    required this.selectedIndex,
    required this.onTabSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// 页签行高（鸿蒙 `BottomTabItemView` 的 `.height(56)`）
  static const double rowHeight = 56;

  /// 图标上提量（鸿蒙 `.margin({ top: -50 })`）
  static const double iconLift = 50;

  /// 页签整体下移量。鸿蒙把整行上提 50，55 的图标几乎全悬在底图上方、
  /// 离底图太远；这里把「图标 + 文字」这一整块往下靠，让图标多压进底图一截。
  ///
  /// 只动页签行，底图位置和 `heightFor()` 都不动，所以滚动留白、浮岛位置
  /// 不用跟着改。页签行下沿 = `tabDrop + rowHeight`，要保证仍落在底图
  /// （`iconLift ~ iconLift + tailHeight`，即 50~120）之内，否则文字会掉出画面。
  static const double tabDrop = 18;

  /// 底边留白（鸿蒙外层 `padding bottom 12`）
  static const double bottomPad = 12;

  /// 底图高度（鸿蒙 `.height(70)`）
  static const double tailHeight = 70;

  /// 主题图标尺寸（鸿蒙 `.width(55).height(55)`）
  static const double iconSize = 55;

  static double heightFor(double safeBottom) =>
      iconLift + rowHeight + bottomPad + safeBottom;

  @override
  State<ThemedBottomBar> createState() => _ThemedBottomBarState();
}

class _ThemedBottomBarState extends State<ThemedBottomBar> {
  int? _pressed;

  @override
  Widget build(BuildContext context) {
    final manager = KanoThemeManager.instance;
    final theme = manager.active;
    final tailBg = theme?.tailBg;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final hideText = SettingsController.instance.barHideText;

    final tabs = <Widget>[
      for (var i = 0; i < ShellTab.values.length; i++)
        Expanded(
          child: _ThemedTab(
            tab: ShellTab.values[i],
            theme: theme,
            selected: i == widget.selectedIndex,
            hideText: hideText,
            pressed: _pressed == i,
            onPressedChanged: (pressed) {
              if (pressed) {
                setState(() => _pressed = i);
              } else if (_pressed == i) {
                setState(() => _pressed = null);
              }
            },
            onTap: () {
              if (i == widget.selectedIndex) return;
              KanoHaptics.select();
              widget.onTabSelected(i);
            },
          ),
        ),
    ];

    return SizedBox(
      height: ThemedBottomBar.heightFor(safeBottom),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 底图：主题包不一定带 tail_bg，缺就不铺，底栏留透（鸿蒙同款）
          if (theme != null && tailBg != null)
            Positioned(
              left: 0,
              right: 0,
              top: ThemedBottomBar.iconLift,
              height: ThemedBottomBar.tailHeight,
              child: Image(
                image: theme.providerOf(tailBg)!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          // 页签行：左右各外扩 3%，底部 12 留给手势区（鸿蒙 `.padding`）
          Positioned(
            left: width * 0.03,
            right: width * 0.03,
            top: ThemedBottomBar.tabDrop,
            height: ThemedBottomBar.rowHeight,
            child: Row(children: tabs),
          ),
        ],
      ),
    );
  }
}

class _ThemedTab extends StatelessWidget {
  const _ThemedTab({
    required this.tab,
    required this.theme,
    required this.selected,
    required this.hideText,
    required this.pressed,
    required this.onPressedChanged,
    required this.onTap,
  });

  final ShellTab tab;
  final KanoTheme? theme;
  final bool selected;
  final bool hideText;
  final bool pressed;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback onTap;

  /// 鸿蒙 `themedBarTextColor`：底图是浅色画，固定深色，选中更深一档
  Color get _textColor =>
      selected ? const Color(0xE6000000) : const Color(0x8C000000);

  @override
  Widget build(BuildContext context) {
    final path = theme?.tailIcon(tab.themeIconKey, selected);
    final provider = theme?.providerOf(path);

    // 主题只给部分页签配了图标时，缺图的那几个用同尺寸 55 盒子兜住矢量图标，
    // 否则 55 的图片和 22 的矢量图标混排会大小不齐（鸿蒙同样处理）
    final icon = provider != null
        ? Image(image: provider, fit: BoxFit.contain, width: 55, height: 55)
        : SizedBox(
            width: 55,
            height: 55,
            child: Center(
              child: Icon(
                selected ? tab.activeIcon : tab.icon,
                size: 22,
                color: _textColor,
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressedChanged(true),
      onTapUp: (_) => onPressedChanged(false),
      onTapCancel: () => onPressedChanged(false),
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: SizedBox(
          height: ThemedBottomBar.rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 55 图标立在 56 行的顶上，文字压在图标下沿、再上提 10
              Positioned(top: hideText ? 0.5 : 0, child: icon),
              if (!hideText)
                Positioned(
                  top: 47,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.0,
                      color: _textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
