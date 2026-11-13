import 'package:flutter/material.dart';

import 'kano_glass_backdrop.dart';

/// 界面色板，与鸿蒙 `RecentPage` 里那组私有方法一一对应。
///
/// 为什么不直接用 `Theme.of(context).colorScheme`：鸿蒙侧的颜色是手调的
/// （面板 20% 白、发丝线 8% 黑、莓色 #DC4560），用 Material 生成的色阶做不出同样观感。
class KanoPalette {
  const KanoPalette._({required this.isLight});

  factory KanoPalette.of(BuildContext context) =>
      KanoPalette._(isLight: Theme.of(context).brightness == Brightness.light);

  final bool isLight;

  /// 用户在「个性化 → 主题 → 主题色」里挑的颜色。
  /// null 表示没改过，仍然用官网那对莓色——避免默认就把对比度调低。
  static Color? _customAccent;

  /// 启动时和改色时调用。传空串或非法值都等于恢复默认。
  static void applyThemeColor(String hex) => _customAccent = parseHex(hex);

  static Color? parseHex(String raw) {
    final body = raw.replaceFirst('#', '').trim();
    if (body.length != 6 && body.length != 8) return null;
    final value = int.tryParse(body, radix: 16);
    if (value == null) return null;
    return Color(body.length == 6 ? 0xFF000000 | value : value);
  }

  /// 主文本
  Color get textPrimary => isLight ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);

  /// 次要文本（说明、时间）
  Color get textSecondary => isLight ? const Color(0xFF6B6B70) : const Color(0xFF9E9EA3);

  /// 三级文本（来源、同步时间）
  Color get textTertiary => isLight ? const Color(0xFF9A9A9F) : const Color(0xFF6E6E73);

  /// 卡片底色：**纯白，只稍微透一点**。
  /// 0xF7 ≈ 97% 不透明 —— 底下的模糊背景只在边缘渗出一点点，
  /// 卡片本身看上去仍是干净的白色面（不是 0x26 那种透明玻璃）。
  Color get panelBg => isLight ? const Color(0xF7FFFFFF) : const Color(0xF71E1E1E);

  /// 官网 `--berry`：浅色 #DC4560、深色 #FF7088；资料卡的 kicker 与标语共用。
  /// 用户改过主题色时以自定义色为准。
  Color get berry =>
      _customAccent ?? (isLight ? const Color(0xFFDC4560) : const Color(0xFFFF7088));

  /// **不跟主题色**的莓色，恒定 #DC4560 / #FF7088。
  /// 鸿蒙 `RecentPage.berryColor()` 就是这么写的，只给资料卡的 kicker 与标语用；
  /// 跟着主题色走的话，用户选了土金色这两行就变成土金色，和鸿蒙对不上。
  Color get berryBrand =>
      isLight ? const Color(0xFFDC4560) : const Color(0xFFFF7088);

  /// 横幅缺图时的淡莓底
  Color get berryWash => isLight ? const Color(0x1ADC4560) : const Color(0x1FFF7088);

  /// 头像 4px 描边：跟卡片底色同族，压边才看得出是「挖」出来的
  Color get avatarRing => isLight ? const Color(0xEBFFFFFF) : const Color(0xEB282828);

  /// 发丝线
  Color get hairline => isLight ? const Color(0x14000000) : const Color(0x1FFFFFFF);

  /// 实心色块上的文字
  Color get onAccent => Colors.white;

  /// 图片占位底色
  Color get imagePlaceholder => isLight ? const Color(0xFFE9E9EC) : const Color(0xFF252528);

  /// 骨架块（浅）
  Color get skeletonSoft => isLight ? const Color(0x14000000) : const Color(0x14FFFFFF);

  /// 骨架块（深）
  Color get skeletonStrong => isLight ? const Color(0x22000000) : const Color(0x24FFFFFF);

  /// 平台胶囊 / 圆钮的底
  Color get chipBg => isLight ? const Color(0x59FFFFFF) : const Color(0x12FFFFFF);

  /// 图标方块底（资源面板左侧那个圆角块）
  Color get iconTileBg => isLight ? const Color(0x0D000000) : const Color(0x14FFFFFF);

  /// 直播状态红
  Color get liveRed => const Color(0xFFE91916);

  /// 主题强调色（粉色）——页面里的可点文字、进度、选中态
  Color get accent => const Color(0xFFFFC0CB);

  /// 强调色的文字版本：粉色本身在浅底上对比太低，文字用莓色更清楚
  Color get accentText => berry;
}

/// 圆角与间距，对齐鸿蒙那套「卡片 24、内部元素 16、列表行 14」
class KanoRadius {
  const KanoRadius._();
  static const card = 24.0;
  static const panel = 20.0;
  static const media = 16.0;
  static const row = 14.0;
  static const pill = 999.0;
}

class KanoGap {
  const KanoGap._();
  static const page = 20.0;
  static const card = 18.0;
  static const section = 14.0;
  static const block = 10.0;
}

/// 卡片外框：半透明底 + 背景模糊裁剪 + 细边。
///
/// 鸿蒙那边是 `backgroundColor(panelBg).backgroundBlurStyle(BlurStyle.Thin)`：
/// 卡片只做 20% 覆盖，底下的壁纸被材质层模糊后才透过来。
///
/// 这里**不用 `BackdropFilter`**：那玩意是向合成器读当前 framebuffer 的内容，
/// 卡片上方的 layer 树一变（滚动视口重排、`OpacityLayer`、父节点重挂）读取就
/// 失效，毛玻璃会闪或彻底消失。鸿蒙的材质层不受这个限制。改成从
/// [KanoGlassLayer] 画的「整屏背景模糊快照」里按卡片位置裁一块，不读 backdrop，
/// 因此结构上不可能因为滚动/动画而消失。
///
/// [blur] <= 0 时不叠模糊层，退回纯半透明色块。
class KanoSurface extends StatelessWidget {
  const KanoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KanoGap.card),
    this.radius = KanoRadius.card,
    this.border = true,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool border;

  /// 背景模糊半径（sigma）；0 表示不要模糊，退回半透明色块
  final double blur;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final shape = BorderRadius.circular(radius);
    final panel = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.panelBg,
        borderRadius: shape,
        border: border ? Border.all(color: palette.hairline, width: 1) : null,
      ),
      child: child,
    );
    if (blur <= 0) return panel;
    return ClipRRect(
      borderRadius: shape,
      child: KanoGlassLayer(child: panel),
    );
  }
}

/// 区块小标题（「下一场」「最新动态」）
class KanoSectionLabel extends StatelessWidget {
  const KanoSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
