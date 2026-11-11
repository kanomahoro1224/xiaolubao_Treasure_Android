import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 平台品牌标。
///
/// 直接用鸿蒙工程的同一批单色 SVG：`F:\Huawei\xiaolubao\entry\src\main\resources\rawfile\brand\`
/// 逐字节复制到 `assets/brand/`，靠 `colorFilter` 上色，跟鸿蒙侧 `Image().fillColor()` 一个效果。
/// 不再手画轮廓 —— 手画的形状和官方标对不上，是之前的错。
class KanoBrandMark extends StatelessWidget {
  const KanoBrandMark({
    super.key,
    required this.kind,
    this.size = 16,
    this.color,
  });

  /// 品牌 id，与鸿蒙 `brand/<id>.svg` 同名
  final String kind;
  final double size;
  final Color? color;

  /// 鸿蒙侧出现过的全部品牌标。不在这张表里的一律退回地球，绝不拼出不存在的资源名。
  static const _known = <String>{
    'x',
    'youtube',
    'bilibili',
    'niconico',
    'weibo',
    'twitch',
    'stream',
    'agency',
    'shop',
    'globe',
  };

  /// 把上游各种写法收敛到文件名。规则照抄鸿蒙：
  /// `RecentPage.brandPath()` 一一对应，`FeedPage.brandMark()` 里未命中就落 bilibili。
  static String normalize(String raw, {bool feedStyle = false}) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return 'globe';
    if (lower == 'twitter' || lower == 'x' || lower.contains('x.com')) return 'x';
    if (lower == 'yt' || lower.contains('youtube')) return 'youtube';
    if (lower.contains('bili')) return 'bilibili';
    if (lower.contains('nico')) return 'niconico';
    if (lower.contains('weibo')) return 'weibo';
    if (lower.contains('twitch')) return 'twitch';
    if (lower == 'stream' || lower == 'live') return 'stream';
    if (lower == 'agency') return 'agency';
    if (lower == 'shop' || lower == 'store') return 'shop';
    if (lower == 'globe' || lower == 'web' || lower == 'site') return 'globe';
    // 调用方明确只要「平台行那三档」时，未知量按鸿蒙的做法落到 bilibili
    if (feedStyle) return 'bilibili';
    return _known.contains(lower) ? lower : 'globe';
  }

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.onSurface;
    final id = normalize(kind);
    return SvgPicture.asset(
      'assets/brand/$id.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 原 SVG 是无 fill 的纯 path，srcIn 染色等价于鸿蒙的 fillColor
      colorFilter: ColorFilter.mode(paintColor, BlendMode.srcIn),
      // 平台标是纯装饰，语义交给外层胶囊的 accessibilityLabel
      excludeFromSemantics: true,
    );
  }
}
