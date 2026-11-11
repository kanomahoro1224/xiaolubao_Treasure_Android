import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'kano_palette.dart';

/// 统一图片组件：网络图走磁盘缓存，带占位底色与失败兜底。
///
/// 服务端已经把 X 的配图抓下来做成 `/media/<hash>` 代理，所以这里只连一个 host，
/// 不需要额外 referer 或 header。
class KanoImage extends StatelessWidget {
  const KanoImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.radius,
    this.width,
    this.height,
    this.fallbackIcon = Icons.image_outlined,
    this.fadeIn = true,
  });

  final String url;
  final BoxFit fit;
  final double? radius;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final placeholder = Container(
      width: width,
      height: height,
      color: palette.imagePlaceholder,
    );

    Widget content;
    if (url.isEmpty) {
      content = Container(
        width: width,
        height: height,
        color: palette.imagePlaceholder,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 22, color: palette.textTertiary),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: fadeIn ? const Duration(milliseconds: 180) : Duration.zero,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: palette.imagePlaceholder,
          alignment: Alignment.center,
          child: Icon(fallbackIcon, size: 22, color: palette.textTertiary),
        ),
      );
    }

    if (radius != null) {
      content = ClipRRect(borderRadius: BorderRadius.circular(radius!), child: content);
    }
    return content;
  }
}

/// 圆形头像：没有图时退回字母占位（鸿蒙版对没有头像的转推作者就是这么做）。
class KanoAvatar extends StatelessWidget {
  const KanoAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 40,
    this.ringColor,
    this.ringWidth = 0,
    this.letterBackground,
    this.letterForeground,
  });

  final String url;
  final String name;
  final double size;
  final Color? ringColor;
  final double ringWidth;

  /// 无头像时的首字占位底色 / 字色。
  /// 动态与帖子卡在鸿蒙那边是 `Circle(42).fill('#1D9BF0')` + 白色 17 号粗体，
  /// 不传则是通用的灰底占位。
  final Color? letterBackground;
  final Color? letterForeground;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final inner = size - ringWidth * 2;
    final styled = letterBackground != null;
    Widget avatar = url.isEmpty
        ? Container(
            width: inner,
            height: inner,
            alignment: Alignment.center,
            color: letterBackground ?? palette.imagePlaceholder,
            child: Text(
              _initial(name),
              style: TextStyle(
                // 鸿蒙 LetterAvatar 是 42 圆配 17 号字，17/42 ≈ 0.405
                fontSize: styled ? inner * 17 / 42 : inner * 0.4,
                fontWeight: styled ? FontWeight.bold : FontWeight.w600,
                color: letterForeground ?? palette.textSecondary,
              ),
            ),
          )
        : KanoImage(
            url: url,
            width: inner,
            height: inner,
            fit: BoxFit.cover,
            fallbackIcon: Icons.person_outline,
          );

    avatar = ClipOval(child: SizedBox(width: inner, height: inner, child: avatar));

    if (ringWidth > 0) {
      avatar = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor ?? palette.avatarRing,
        ),
        child: avatar,
      );
    }
    return avatar;
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
