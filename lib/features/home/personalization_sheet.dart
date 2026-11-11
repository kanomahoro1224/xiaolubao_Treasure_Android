import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../kano/data/kano_theme.dart';
import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_motion.dart';
import '../kano/presentation/kano_palette.dart';
import '../kano/presentation/staggered_enter.dart';
import '../settings/settings_controller.dart';
import '../shell/app_background_layer.dart' show isVideoPath;

/// 个性化四个覆盖层的共同外壳。
///
/// 对应鸿蒙 `WallpaperOverlayLayer` / `EffectsOverlayLayer` / `ThemeOverlayLayer`：
/// ```ts
/// Stack() {
///   PersonalizationOverlayBackdrop()   // 黑 20% + backdropBlur(8)
///   XxxSheetBuilder()
///   PersonalizationOverlayTitleBar(主标题, 副标题, 返回)
///   PersonalizationBackGestureZone()
/// }
/// .borderRadius(28 * (1 - enterProgress))
/// .translate({ x: enterTranslate })
/// .transition(getPersonalizationOverlayEnterEffect())   // 从右 100% 滑入 280ms
/// ```
///
/// 注意它**不是**底部半屏 sheet——整层铺满、从右侧推入、带标题栏。
class PersonalizationSheet extends StatefulWidget {
  const PersonalizationSheet({
    required this.title,
    required this.onClose,
    required this.child,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  PersonalizationSheetState createState() => PersonalizationSheetState();
}

class PersonalizationSheetState extends State<PersonalizationSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KanoMotion.pageEnter,
    );
    _progress = CurvedAnimation(parent: _controller, curve: KanoMotion.pageSpring);
    _slide = Tween(begin: const Offset(1, 0), end: Offset.zero).animate(_progress);
    // 鸿蒙入场把整层透明度从 0.9 抬到 1，不是从 0 —— 避免滑入时先闪一下黑
    _fade = Tween(begin: 0.9, end: 1.0).animate(_progress);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 退场：鸿蒙 `closePersonalizationOverlay` 会先把整层向右滑出去再拆，不是直接消失。
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final topSafe = MediaQuery.viewPaddingOf(context).top;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value.clamp(0.0, 1.0);
        // 入场过程中 28 → 0，贴合屏幕后不再有圆角（鸿蒙 getPersonalizationOverlayRadius）
        final radius = 28 * (1 - t);
        return Stack(
          fit: StackFit.expand,
          children: [
            // 背板：鸿蒙是 `backgroundColor('rgba(0,0,0,0.2)')` + `backdropBlur(8)`。
            // 模糊半径必须小，否则背后的首页会被糊成一块纯色，实时预览就没了。
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.2 * t),
              ),
            ),
            SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Column(
                    children: [
                      _TitleBar(
                        title: widget.title,
                        subtitle: KanoText.ui('vip_benefit_personalize_title'),
                        palette: palette,
                        topInset: topSafe,
                        onClose: close,
                      ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 覆盖层顶栏：与设置页同款（主标题 + 副标题 + 左上返回）
class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.topInset,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final KanoPalette palette;
  final double topInset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              KanoHaptics.tap();
              onClose();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.panelBg,
                shape: BoxShape.circle,
                border: Border.all(color: palette.hairline),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 24,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 错落入场动画（`StaggeredEnter`）已抽到 kano/presentation/staggered_enter.dart，
// 面板与动态卡片共用同一份实现。

/// 位置紧凑的包装：`_Stagger(i, child)`
Widget _stagger(int index, Widget child) =>
    StaggeredEnter(index: index, child: child);

/// 鸿蒙 `SettingItem` 的等价行：左侧 label + desc，右侧控件。
class KanoSettingRow extends StatelessWidget {
  const KanoSettingRow({
    required this.label,
    this.desc,
    this.trailing,
    this.disabled = false,
    this.stacked = false,
    super.key,
  });

  final String label;
  final String? desc;
  final Widget? trailing;
  final bool disabled;

  /// 选项多到右侧摆不下时，控件落到第二行
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, color: palette.textPrimary),
        ),
        if (desc != null && desc!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              desc!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.textTertiary),
            ),
          ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.48 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (trailing != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
      ),
    );
  }
}

/// 鸿蒙 `SlidingSegment` 的等价物：一排小胶囊，选中项填主题色。
class KanoSegment extends StatelessWidget {
  const KanoSegment({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
    this.wrap = false,
    super.key,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool enabled;

  /// 4 档以上横排放不下，交给调用方决定是否换行
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final chips = [
      for (var i = 0; i < options.length; i++)
        GestureDetector(
          onTap: enabled
              ? () {
                  KanoHaptics.tap();
                  onSelect(i);
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: i == selected
                  ? palette.berry
                  : (palette.isLight
                      ? const Color(0x0F000000)
                      : const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              options[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                color: i == selected ? Colors.white : palette.textSecondary,
              ),
            ),
          ),
        ),
    ];

    if (wrap) {
      return Wrap(spacing: 6, runSpacing: 6, children: chips);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Flexible(child: chips[i]),
        ],
      ],
    );
  }
}

/// label + 数值 + 滑块（鸿蒙 `SettingItem` 的 slider 分支）
class KanoSliderRow extends StatelessWidget {
  const KanoSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.display,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final divisions = step <= 0 ? null : ((max - min) / step).round();
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 16, color: palette.textPrimary),
                  ),
                ),
                Text(
                  display,
                  style: TextStyle(fontSize: 12, color: palette.textTertiary),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: palette.berry,
                inactiveTrackColor: palette.textTertiary.withValues(alpha: 0.22),
                thumbColor: Colors.white,
                overlayColor: palette.berry.withValues(alpha: 0.12),
                trackHeight: 4,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 壁纸 ====================

/// 对应鸿蒙 `WallpaperSheetBuilder`：
/// 提示 → 选图 / 选视频 / 编辑 → 背景横向列表（默认 + 预设 + 自定义）→ 遮罩 / 模糊滑块。
class WallpaperPanel extends StatefulWidget {
  const WallpaperPanel({super.key});

  @override
  State<WallpaperPanel> createState() => _WallpaperPanelState();
}

class _WallpaperPanelState extends State<WallpaperPanel> {
  /// 对应鸿蒙 `isBgEditMode`：进入后自定义背景右上角出现删除
  bool _editMode = false;
  bool _picking = false;

  Future<void> _pick({required bool video}) async {
    // 鸿蒙 `selectFromGallery`：主题生效时直接返回（`if (this.hasAppliedTheme()) return;`），
    // 壁纸不允许覆盖主题底图
    if (KanoThemeManager.instance.hasActive) return;
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = video
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      // image_picker 给的是缓存路径，系统随时会清；复制进应用私有目录再记
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/bg');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final name = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final saved = await File(picked.path).copy('${dir.path}/$name');
      await SettingsController.instance.addCustomBackground(saved.path);
      await SettingsController.instance.setBgPreset(saved.path);
    } catch (error) {
      debugPrint('pick background failed: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final settings = SettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final items = <_BgItem>[
          const _BgItem.plain(),
          const _BgItem.preset(),
          for (final path in settings.customBackgrounds) _BgItem.custom(path),
        ];
        final current = settings.bgPreset;
        // 鸿蒙 `backgroundLockedByTheme: this.hasAppliedTheme()`：
        // 主题生效时背景列表整体只读，点卡片和删除都不响应
        final locked = KanoThemeManager.instance.hasActive;

        // 与鸿蒙 WallpaperSheetBuilder 一致：提示 → 三个按钮 → 背景列表 → 两个滑块，
        // 每块按序号错落入场
        final blocks = <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                KanoText.ui('home_bg_pick_hint'),
                style: TextStyle(fontSize: 12, color: palette.textTertiary),
              ),
            ),
            // 选图 / 选视频 / 编辑
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      label: KanoText.ui('home_bg_pick_image'),
                      palette: palette,
                      onTap: () => _pick(video: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickButton(
                      label: KanoText.ui('home_bg_pick_video'),
                      palette: palette,
                      onTap: () => _pick(video: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickButton(
                      label: _editMode
                          ? KanoText.ui('common_done')
                          : KanoText.ui('common_edit'),
                      palette: palette,
                      highlighted: _editMode,
                      onTap: () {
                        KanoHaptics.tap();
                        setState(() => _editMode = !_editMode);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 背景横向列表
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = item.matches(current);
                  return _BgTile(
                    item: item,
                    selected: selected,
                    editMode: _editMode,
                    palette: palette,
                    onTap: locked
                        ? null
                        : () {
                            KanoHaptics.tap();
                            settings.setBgPreset(item.value);
                          },
                    onDelete: item.isCustom && !locked
                        ? () {
                            KanoHaptics.tap();
                            settings.removeCustomBackground(item.value);
                          }
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            KanoSliderRow(
              label: KanoText.ui('home_bg_mask_opacity'),
              value: settings.bgMask.toDouble(),
              min: 0,
              max: 100,
              step: 1,
              display: '${settings.bgMask}%',
              onChanged: (v) => settings.setBgMask(v.round()),
            ),
            KanoSliderRow(
              label: KanoText.ui('home_bg_blur_radius'),
              value: settings.bgBlur.toDouble(),
              min: 0,
              max: 100,
              step: 1,
              display: '${settings.bgBlur}',
              onChanged: (v) => settings.setBgBlur(v.round()),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ResetChip(
                label: KanoText.ui('home_effect_reset_default'),
                palette: palette,
                onTap: () {
                  KanoHaptics.tap();
                  settings.resetBackground();
                },
              ),
            ),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++) _stagger(i, blocks[i]),
            ],
          ),
        );
      },
    );
  }
}

class _BgItem {
  const _BgItem.plain() : value = SettingsController.bgPresetPlain, isCustom = false;
  const _BgItem.preset() : value = SettingsController.bgPresetSakura, isCustom = false;
  const _BgItem.custom(this.value) : isCustom = true;

  final String value;
  final bool isCustom;

  bool matches(String current) => current == value;
}

class _BgTile extends StatelessWidget {
  const _BgTile({
    required this.item,
    required this.selected,
    required this.editMode,
    required this.palette,
    required this.onTap,
    this.onDelete,
  });

  final _BgItem item;
  final bool selected;
  final bool editMode;
  final KanoPalette palette;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.berry : palette.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _thumb(),
              if (selected)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: palette.berry,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (editMode && onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xCC000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    if (item.value == SettingsController.bgPresetPlain) {
      return ColoredBox(
        color: palette.isLight
            ? const Color(0xFFF1F3F5)
            : const Color(0xFF121212),
        child: Icon(
          Icons.wallpaper_rounded,
          size: 20,
          color: palette.textTertiary,
        ),
      );
    }
    if (item.value == SettingsController.bgPresetSakura) {
      return Image.asset(
        'assets/images/kado_sakura21.png',
        fit: BoxFit.cover,
      );
    }
    final file = File(item.value);
    final isVideo = isVideoPath(item.value);
    if (isVideo) {
      return const ColoredBox(
        color: Color(0xFF1A1A1A),
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 22,
          color: Colors.white70,
        ),
      );
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: palette.imagePlaceholder,
        child: Icon(Icons.broken_image_outlined, size: 18, color: palette.textTertiary),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.label,
    required this.palette,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final KanoPalette palette;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted
              ? palette.berry.withValues(alpha: 0.18)
              : (palette.isLight
                  ? const Color(0x0A000000)
                  : const Color(0x14FFFFFF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: highlighted ? palette.berry : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.isLight
              ? const Color(0x0D000000)
              : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restart_alt_rounded, size: 16, color: palette.berry),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.berry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 效果 ====================

/// 对应鸿蒙 `EffectsSheetBuilder` 的 15 项。
///
/// 材质厚度 / 材质等级 / 按压颜色 / 点光源是 HDS 或沉浸光感专有能力，Android 侧
/// 没有可映射的开关，条目保留但置灰——和鸿蒙自己把「点光源」标成 TODO 一样，
/// 不删条目，免得面板比鸿蒙少一截。
class EffectsPanel extends StatefulWidget {
  const EffectsPanel({super.key});

  @override
  State<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends State<EffectsPanel> {
  @override
  Widget build(BuildContext context) {
    final s = SettingsController.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final off = KanoText.ui('setting_off');
        final on = KanoText.ui('setting_on');
        // 先只保留「隐藏底栏文字」这一项，其余特效项等后续再补。
        final items = <Widget>[
          KanoSettingRow(
            label: KanoText.ui('setting_hide_bar_text'),
            desc: KanoText.ui('setting_hide_bar_text_desc'),
            trailing: KanoSegment(
              options: [off, on],
              selected: s.barHideText ? 1 : 0,
              onSelect: (i) => s.setBarHideText(i == 1),
            ),
          ),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) _stagger(i, items[i]),
            ],
          ),
        );
      },
    );
  }
}

/// 入场错落预览框（鸿蒙 `StaggerPreviewBox`）：每轮飞出 → 销毁 → 重建，
/// 用真实参数重播，所以拖滑块能立刻看到幅度/间隔/速度的变化。
class _StaggerPreview extends StatefulWidget {
  const _StaggerPreview();

  @override
  State<_StaggerPreview> createState() => _StaggerPreviewState();
}

class _StaggerPreviewState extends State<_StaggerPreview>
    with SingleTickerProviderStateMixin {
  static const _slots = 3;

  late final AnimationController _controller;
  bool _visible = true;
  bool _flyingOut = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1));
    _loop();
  }

  @override
  void dispose() {
    _token++;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loop() async {
    final token = ++_token;
    while (mounted && token == _token) {
      final s = SettingsController.instance;
      final hold = (_slots - 1) * s.staggerInterval +
          s.staggerResponse * 10 +
          800;
      await Future<void>.delayed(Duration(milliseconds: hold));
      if (!mounted || token != _token) return;
      setState(() => _flyingOut = true);
      await Future<void>.delayed(
        const Duration(milliseconds: (_slots - 1) * 40 + 260 + 60),
      );
      if (!mounted || token != _token) return;
      setState(() {
        _visible = false;
        _flyingOut = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || token != _token) return;
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final s = SettingsController.instance;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.isLight ? const Color(0x05000000) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                KanoText.ui('home_effect_preview'),
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
              const Spacer(),
              Text(
                KanoText.ui('home_effect_loop'),
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 178,
            child: _visible
                ? AnimatedListPreview(
                    flyingOut: _flyingOut,
                    palette: palette,
                    distance: s.staggerDistance.toDouble(),
                    interval: s.staggerInterval,
                    curve: KanoMotion.staggerCurve(s.staggerResponse),
                  )
                : const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

/// 预览里的三行示例，错落入场 + 飞出都走真实参数
class AnimatedListPreview extends StatefulWidget {
  const AnimatedListPreview({
    required this.flyingOut,
    required this.palette,
    required this.distance,
    required this.interval,
    required this.curve,
    super.key,
  });

  final bool flyingOut;
  final KanoPalette palette;
  final double distance;
  final int interval;
  final Curve curve;

  @override
  State<AnimatedListPreview> createState() => _AnimatedListPreviewState();
}

class _AnimatedListPreviewState extends State<AnimatedListPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.curve is SpringMotionCurve
          ? ((widget.curve as SpringMotionCurve).durationMs).round()
          : 550),
    )..forward();
  }

  @override
  void didUpdateWidget(AnimatedListPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flyingOut != widget.flyingOut) {
      if (widget.flyingOut) {
        _controller.reverse();
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delayed = ((_controller.value - i * (widget.interval / 1000)) /
                      (1 - 0.001))
                  .clamp(0.0, 1.0);
              final v = widget.curve.transform(delayed);
              return Transform.translate(
                offset: Offset(
                  _controller.status == AnimationStatus.reverse
                      ? (1 - _controller.value) * -widget.distance
                      : (1 - v) * widget.distance,
                  0,
                ),
                child: Opacity(
                  opacity: _controller.status == AnimationStatus.reverse
                      ? _controller.value
                      : v.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: widget.palette.isLight
                    ? const Color(0x0A000000)
                    : const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: widget.palette.berry,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          KanoText.ui('home_effect_sample_component')
                              .replaceFirst('%1\$s', '${i + 1}'),
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.palette.textPrimary,
                          ),
                        ),
                        Text(
                          KanoText.ui('home_effect_preview_hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== 主题 ====================

/// 对应鸿蒙 `ThemeSheetBuilder`：外观模式 + 主题色（6 个预设 + HEX 自定义）。
///
/// 鸿蒙在中间还挂了一个 `PackagedThemeSelectorBuilder`（KCM 主题商店的打包主题），
/// Android 侧没有这套主题包来源，这里不摆一个空壳。
/// 打包主题选择器，对齐鸿蒙 `PackagedThemeSelectorBuilder`。
///
/// 一排 100×140 的卡片（圆角 12、间距 8）：默认 → 内置/导入的主题 → 导入主题包。
/// 选中的卡片描 2px 主题色边、底部压一个对勾，名字同步变主题色。
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.palette});

  final KanoPalette palette;

  Future<void> _import(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final result = await KanoThemeManager.instance.importZip(path);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(KanoText.ui('theme_import_action')),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(KanoText.ui('common_ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = KanoThemeManager.instance;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final themes = manager.themes;
        // 鸿蒙 PackagedThemeSelectorBuilder：标题 + 横向卡片（列间距 16、整块 padding 16）
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                KanoText.ui('home_app_theme'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 「默认」卡：鸿蒙用 nosign 图标表示「不套主题」
                  _ThemeCard(
                    label: KanoText.ui('common_default'),
                    selected: manager.activeName.isEmpty,
                    palette: palette,
                    placeholderIcon: Icons.block,
                    onTap: () {
                      KanoHaptics.tap();
                      manager.setActive('');
                    },
                  ),
                  const SizedBox(width: 16),
                  for (final theme in themes) ...[
                    _ThemeCard(
                      label: theme.name,
                      selected: manager.activeName == theme.name,
                      palette: palette,
                      image: theme.providerOf(theme.cardCover),
                      onTap: () {
                        KanoHaptics.tap();
                        manager.setActive(theme.name);
                      },
                    ),
                    const SizedBox(width: 16),
                  ],
                  _ThemeImportCard(
                    palette: palette,
                    onTap: () {
                      KanoHaptics.tap();
                      _import(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.image,
    this.placeholderIcon,
  });

  final String label;
  final bool selected;
  final KanoPalette palette;
  final VoidCallback onTap;
  final ImageProvider? image;
  final IconData? placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final accent = palette.berry;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            height: 140,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.chipBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? accent : palette.hairline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: image != null
                        // 卡片只有 100 宽，按 240 解码足够清晰，也省下大图内存
                        ? Image(
                            image: ResizeImage(image!, width: 240),
                            fit: BoxFit.cover,
                          )
                        : placeholderIcon != null
                        ? Center(
                            child: Icon(
                              placeholderIcon,
                              size: 24,
                              color: palette.textPrimary.withValues(alpha: 0.55),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Center(
                      child: Icon(Icons.check_rounded, size: 24, color: accent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? accent : palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeImportCard extends StatelessWidget {
  const _ThemeImportCard({required this.palette, required this.onTap});

  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.isLight
                  ? const Color(0x08000000)
                  : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: palette.isLight
                    ? const Color(0x1F000000)
                    : const Color(0x2EFFFFFF),
              ),
            ),
            child: Text(
              '＋',
              style: TextStyle(fontSize: 28, color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              KanoText.ui('theme_import_action'),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class ThemePanel extends StatelessWidget {
  const ThemePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final s = SettingsController.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final mode = switch (s.themeMode) {
          ThemeMode.system => 0,
          ThemeMode.light => 1,
          ThemeMode.dark => 2,
        };
        // 外观模式 → 打包主题（默认/四套内置/导入）→ 主题色，
        // 与鸿蒙 ThemeSheetBuilder 的排列一致
        final items = <Widget>[
          KanoSettingRow(
            label: KanoText.ui('setting_appearance_mode'),
            trailing: KanoSegment(
              options: [
                KanoText.ui('setting_follow'),
                KanoText.ui('setting_light'),
                KanoText.ui('setting_dark'),
              ],
              selected: mode,
              onSelect: (i) => s.setThemeMode(switch (i) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              }),
            ),
          ),
          const SizedBox(height: 8),
          _ThemeSelector(palette: palette),
          _ThemeColorSection(palette: palette),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) _stagger(i, items[i]),
            ],
          ),
        );
      },
    );
  }
}

/// 主题色区域，对应鸿蒙 `ThemeSheetBuilder` 里 `home_app_theme_color` 那一块：
/// 标题 + 6 个预设色 + 分隔线 + HEX 输入 + 色盘取色。
class _ThemeColorSection extends StatefulWidget {
  const _ThemeColorSection({required this.palette});

  final KanoPalette palette;

  @override
  State<_ThemeColorSection> createState() => _ThemeColorSectionState();
}

class _ThemeColorSectionState extends State<_ThemeColorSection> {
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController(text: SettingsController.instance.themeColor);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Future<void> _openWheel() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _ColorWheelDialog(
        initial: SettingsController.instance.themeColor,
        palette: widget.palette,
      ),
    );
    if (picked == null || !mounted) return;
    _hex.text = picked;
    await SettingsController.instance.setThemeColor(picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final s = SettingsController.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              KanoText.ui('home_app_theme_color'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              KanoText.ui('home_theme_preset_colors'),
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final hex in SettingsController.themeColorPresets)
                  GestureDetector(
                    onTap: () {
                      KanoHaptics.tap();
                      _hex.text = hex;
                      s.setThemeColor(hex);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: KanoPalette.parseHex(hex),
                            shape: BoxShape.circle,
                            border: s.themeColor.toUpperCase() ==
                                    hex.toUpperCase()
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 0.5, thickness: 0.5, color: palette.hairline),
            const SizedBox(height: 12),
            Text(
              KanoText.ui('home_theme_custom_value'),
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'HEX',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    color: palette.isLight
                        ? const Color(0x0A000000)
                        : const Color(0x0FFFFFFF),
                    child: TextField(
                      controller: _hex,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (value) {
                        if (RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$')
                            .hasMatch(value)) {
                          s.setThemeColor(value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 鸿蒙：22 圆点，点开色盘 popup
                GestureDetector(
                  onTap: () {
                    KanoHaptics.tap();
                    _openWheel();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: KanoPalette.parseHex(_hex.text) ?? palette.berry,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                KanoText.ui('home_theme_pick_hint'),
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 色盘弹层，逻辑照抄鸿蒙 `ColorPickerPopup`：
/// 200×200 圆图，按触点角度取色相、按半径取饱和度，松手才提交。
class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initial, required this.palette});

  final String initial;
  final KanoPalette palette;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  static const _size = 200.0;
  static const _radius = _size / 2;

  late Color _color;
  double _x = _radius;
  double _y = _radius;

  @override
  void initState() {
    super.initState();
    _color = KanoPalette.parseHex(widget.initial) ?? const Color(0xFFFFC0CB);
    final hsv = HSVColor.fromColor(_color);
    final radians = (hsv.hue - 90) * math.pi / 180;
    final r = hsv.saturation * _radius;
    _x = _radius + math.cos(radians) * r;
    _y = _radius + math.sin(radians) * r;
  }

  void _handle(Offset local) {
    final dx = local.dx - _radius;
    final dy = local.dy - _radius;
    final distance = math.sqrt(dx * dx + dy * dy);
    final clamped = distance > _radius ? _radius : distance;
    final angle = math.atan2(dy, dx);
    final hue = ((angle * 180 / math.pi) + 90 + 360) % 360;
    final saturation = (clamped / _radius).clamp(0.0, 1.0);
    setState(() {
      _color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
      _x = _radius + (distance == 0 ? 0 : dx / distance) * clamped;
      _y = _radius + (distance == 0 ? 0 : dy / distance) * clamped;
    });
  }

  String get _hex {
    final rgb = _color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AlertDialog(
      backgroundColor: palette.isLight ? Colors.white : const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            KanoText.ui('home_pick_color'),
            style: TextStyle(fontSize: 14, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTapDown: (d) => _handle(d.localPosition),
            onPanDown: (d) => _handle(d.localPosition),
            onPanUpdate: (d) => _handle(d.localPosition),
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/color_wheel.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _x - 8,
                    top: _y - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(KanoText.ui('common_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_hex),
                child: Text(KanoText.ui('common_ok')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
