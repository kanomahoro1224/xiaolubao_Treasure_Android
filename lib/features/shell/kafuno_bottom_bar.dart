// Ported from Asasfans-Next `lib/shared/widgets/glass/app_glass_navigation.dart`
// (pointer-deferred commit + GlassTabBar.bottom capsule), on
// liquid_glass_widgets 0.30.2. Three tabs, no separate Tools capsule.
import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'shell_tab.dart';
import '../kano/data/kano_theme.dart';
import '../kano/presentation/kano_haptics.dart';
import '../settings/settings_controller.dart';

class KafunoBottomBar extends StatefulWidget {
  const KafunoBottomBar({
    required this.selectedIndex,
    required this.onTabSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// 56 at 1x: a 48 tab inside the 4 px indicator inset.
  static double heightFor(TextScaler scaler) => 40 + scaler.scale(16);

  static const iconSize = 22.0;

  @override
  State<KafunoBottomBar> createState() => _KafunoBottomBarState();
}

class _KafunoBottomBarState extends State<KafunoBottomBar> {
  static const tabs = ShellTab.values;

  int? pointer;
  Offset down = Offset.zero;
  bool moved = false;
  bool cancelled = false;
  int? pending;
  bool pendingWhileDown = false;
  int? visual;
  bool scheduled = false;

  void _select(int index) {
    if (cancelled) return;
    pending = index;
    pendingWhileDown = pointer != null;
    setState(() => visual = index);
    if (pointer == null) _scheduleCommit();
  }

  void _scheduleCommit() {
    if (scheduled) return;
    scheduled = true;
    // Listener runs before the library's release recognizer. Let its final
    // selection replace a speculative tap-down before changing the tab.
    scheduleMicrotask(() {
      scheduled = false;
      if (!mounted || pointer != null) return;
      final index = pending;
      final stalePress = moved && pendingWhileDown;
      final wasCancelled = cancelled;
      pending = null;
      moved = cancelled = pendingWhileDown = false;
      setState(() => visual = null);
      if (wasCancelled || index == null || stalePress) return;
      if (index != widget.selectedIndex) {
        KanoHaptics.select();
        widget.onTabSelected(index);
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (pointer != null) {
      cancelled = true;
      pending = null;
      return;
    }
    pointer = event.pointer;
    down = event.position;
    moved = cancelled = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == pointer &&
        (event.position - down).distance > kTouchSlop) {
      moved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != pointer) return;
    pointer = null;
    _scheduleCommit();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != pointer) return;
    pointer = null;
    cancelled = true;
    pending = null;
    _scheduleCommit();
  }

  Widget _label(ShellTab tab, bool selected) {
    // 主题态：换成主题包的 tail_icon（选中取 selected 版），缺图回落矢量图标
    final theme = KanoThemeManager.instance.active;
    final themedPath = theme?.tailIcon(tab.themeIconKey, selected);
    final themedProvider = theme?.providerOf(themedPath);
    final themed = themedProvider != null;
    // 平板（≥600vp）不铺主题底图，退回玻璃浮岛；但图标仍是主题包的 tail_icon，
    // 尺寸按鸿蒙 `FloatingTabItem` 的 44×33（不是主题底栏那套 55 的贴纸，
    // 55 会把文字挤出浮岛）。
    final Widget icon = themed
        ? SizedBox(
            width: 44,
            height: 33,
            child: Image(image: themedProvider, fit: BoxFit.contain),
          )
        : Icon(
            selected ? tab.activeIcon : tab.icon,
            size: KafunoBottomBar.iconSize,
          );
    // 个性化 → 特效与排版 → 隐藏栏文字：只留图标（鸿蒙 barHideText）
    if (SettingsController.instance.barHideText) return icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 1.5),
        Text(
          tab.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            height: 1.1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 换主题要换图标，底栏自己听主题管理器（不必让整页重建）
    return ListenableBuilder(
      listenable: KanoThemeManager.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = Theme.of(context).colorScheme;
    final height = KafunoBottomBar.heightFor(MediaQuery.textScalerOf(context));
    final sysBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      // 浮岛态保持 12：这一层是「没有激活主题」时用的玻璃底栏，
      // 主题态的下移在 ThemedBottomBar 里单独做，别在这里动。
      padding: EdgeInsets.fromLTRB(12, 12, 12, sysBottom + 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: GlassTabBar.bottom(
              tabs: [
                for (final tab in tabs)
                  GlassTab(
                    semanticLabel: tab.label,
                    icon: _label(tab, false),
                    activeIcon: _label(tab, true),
                  ),
              ],
              selectedIndex: visual ?? widget.selectedIndex,
              onTabSelected: _select,
              spacing: 12,
              horizontalPadding: 0,
              verticalPadding: 0,
              barHeight: height,
              barBorderRadius: height / 2,
              // Asasfans AppGlassStyle.settings(): fixed legible tint, no
              // extra saturation, softer rim glow. Applies only in light mode.
              settings: LiquidGlassSettings(
                glassColor: brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: .40)
                    : Colors.white.withValues(alpha: .50),
                saturation: 1.0,
                glowIntensity: .4,
                shadow: brightness == Brightness.dark
                    ? const []
                    : const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
              ),
              selectedIconColor: colors.primary,
              unselectedIconColor: colors.onSurfaceVariant,
              selectedLabelColor: colors.primary,
              unselectedLabelColor: colors.onSurfaceVariant,
              indicatorColor: colors.primary.withValues(alpha: .38),
              // 固定高精度蒙版：图标透过指示器放大。原来挂过一个「启用新版玻璃」
              // 的开关，但那是鸿蒙 HDS 的概念，Android 侧没有对应物，已删。
              maskingQuality: MaskingQuality.high,
              // Previous decision kept: press glow halved (1.5 -> 0.75).
              interactionGlowRadius: 0.75,
            ),
          ),
        ),
      ),
    );
  }
}
