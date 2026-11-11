import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_palette.dart';
import '../settings/settings_controller.dart';
import 'home_edit_mode.dart';
import 'personalization_sheet.dart';

/// 首页编辑层，对应鸿蒙 `Home.ets` 的 `if (this.isEditMode)` 那一段：
///
/// ```ts
/// Rect().fill(Transparent).onClick(() => this.exitHomeEditMode())   // 点空白退出
/// Column(){ AdaptiveTopBarButton(chevron_backward) }.position({x:16, y:topSafe+8})
/// Row(){ EditToolButton('picture'|'star'|'paintpalette') }
///   .position({x:0, y:'85%'}).transition(move(BOTTOM) + OPACITY)
/// ```
///
/// 这一层与 `home_root_stack` **同级**（Home.ets:8897 起，缩进 6），所以在缩放容器外面：
/// 返回按钮与三个工具按全屏坐标摆，不跟着首页一起缩。
class HomeEditOverlay extends StatefulWidget {
  const HomeEditOverlay({required this.progress, super.key});

  /// 编辑态进出进度（0 = 完全退出，1 = 完全进入）
  final double progress;

  @override
  State<HomeEditOverlay> createState() => _HomeEditOverlayState();
}

enum _Panel { none, wallpaper, effects, theme }

class _HomeEditOverlayState extends State<HomeEditOverlay> {
  _Panel _panel = _Panel.none;
  final _sheetKey = GlobalKey<PersonalizationSheetState>();

  void _open(_Panel panel) {
    KanoHaptics.tap();
    setState(() => _panel = _panel == panel ? _Panel.none : panel);
  }

  void _closeSheet() {
    _sheetKey.currentState?.close();
  }

  void _onSheetClosed() {
    if (!mounted) return;
    setState(() => _panel = _Panel.none);
  }

  void _back() {
    KanoHaptics.tap();
    if (_panel != _Panel.none) {
      _closeSheet();
    } else {
      HomeEditMode.instance.exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final t = widget.progress.clamp(0.0, 1.0);

    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) => Stack(
        children: [
          // 点空白退出编辑态（鸿蒙那个全屏透明 Rect）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _back,
            ),
          ),
          // 左上返回：鸿蒙给它 56×56 的容器，按钮本体 44
          Positioned(
            left: 16,
            top: 8,
            child: SafeArea(
              bottom: false,
              child: Opacity(
                opacity: t,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: _RoundButton(
                      icon: Icons.chevron_left_rounded,
                      palette: palette,
                      onTap: _back,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 底部三个工具：`.position({ y: '85%' })` + `padding 16` + `SpaceEvenly`
          // + `move(BOTTOM).combine(OPACITY)`
          Positioned(
            left: 0,
            right: 0,
            top: screenHeight * 0.85,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 93),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolButton(
                        icon: Icons.image_outlined,
                        label: KanoText.ui('home_edit_wallpaper'),
                        palette: palette,
                        active: _panel == _Panel.wallpaper,
                        onTap: () => _open(_Panel.wallpaper),
                      ),
                      _ToolButton(
                        icon: Icons.auto_awesome_outlined,
                        label: KanoText.ui('home_edit_effects'),
                        palette: palette,
                        active: _panel == _Panel.effects,
                        onTap: () => _open(_Panel.effects),
                      ),
                      _ToolButton(
                        icon: Icons.palette_outlined,
                        label: KanoText.ui('home_edit_theme'),
                        palette: palette,
                        active: _panel == _Panel.theme,
                        onTap: () => _open(_Panel.theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 覆盖层：全屏、从右侧推入（不是底部半屏 sheet）
          if (_panel != _Panel.none)
            Positioned.fill(
              child: PersonalizationSheet(
                key: _sheetKey,
                title: switch (_panel) {
                  _Panel.wallpaper => KanoText.ui('player_background_title'),
                  _Panel.effects => KanoText.ui('home_effects_layout'),
                  _ => KanoText.ui('home_theme_and_appearance'),
                },
                onClose: _onSheetClosed,
                child: switch (_panel) {
                  _Panel.wallpaper => const WallpaperPanel(),
                  _Panel.effects => const EffectsPanel(),
                  _ => const ThemePanel(),
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.panelBg,
          shape: BoxShape.circle,
          border: Border.all(color: palette.hairline),
        ),
        child: Icon(icon, size: 22, color: palette.textPrimary),
      ),
    );
  }
}

/// 鸿蒙 `EditToolButton`：
/// ```ts
/// HdsButton({ barWidth: 56, barHeight: 68, contentPadding: 8 })
/// .borderRadius(barHeight < barWidth ? (barHeight-12)/2 : barWidth/2)
/// .width(barWidth).height(barHeight - 12)
/// ```
/// 68 < 56 不成立 → 圆角 = 56 / 2 = 28，尺寸 56×56：**正圆**。
/// 下面挂 12 号文字；按下缩到 0.92（160ms）。
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final KanoPalette palette;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _pressed ? 0.92 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.active
                          ? palette.berry.withValues(alpha: 0.22)
                          : palette.panelBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.active ? palette.berry : palette.hairline,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: widget.active ? palette.berry : palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                color: palette.textPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
