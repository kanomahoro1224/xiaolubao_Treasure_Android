import 'package:flutter/material.dart';

import '../kano/data/bilibili_api.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_brand_mark.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_image.dart';
import '../kano/presentation/kano_image_viewer.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_palette.dart';
import '../kano/presentation/kano_state.dart';
import '../kano/presentation/staggered_enter.dart';

/// 动态页的三种卡片，逐条照鸿蒙 `FeedPage.ets` 的对应 @Builder 复刻：
///
/// | 鸿蒙 | 这里 |
/// |---|---|
/// | `YoutubeTile` | [YoutubeTile] |
/// | `BiliVideoTile` | [BiliVideoTile] |
/// | `BiliDynamicCard` | [BiliDynamicCard] |
/// | `VideoTagChip` | [VideoTagChip] |
/// | `DynamicPics` + `DynPic` | [BiliPics] |
/// | `DynStat` | [_DynStat] |
///
/// 三条容易做错、之前确实做错了的地方：
/// 1. **标签在封面左上角**（`position({x: 6, y: 6})`），不是放在标题下面；
/// 2. **播放量在封面左下、时长在封面右下**，与 B 站自己的版式一致；
/// 3. 网格 tile **没有卡片底、没有内边距**，只有封面圆角 10 + 标题 + 日期。

/// 图片区圆角：鸿蒙 `borderRadius(10)`（帖子卡里的配图是 12，别混用）
const double _mediaRadius = 10;

/// 一秒数 → `mm:ss` / `h:mm:ss`，零返回空串（鸿蒙 `durationText`）
String durationText(int sec) {
  final total = sec;
  if (total <= 0) return '';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m < 10 ? '0$m' : '$m';
  final ss = s < 10 ? '0$s' : '$s';
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// 计数缩写，对齐鸿蒙 `CountFormatUtil.format`
String countText(int value) {
  if (value >= 100000000) {
    final v = value / 100000000;
    return '${v.toStringAsFixed(1)}亿';
  }
  if (value >= 10000) {
    final v = value / 10000;
    return '${v.toStringAsFixed(1)}万';
  }
  return '$value';
}

/// 视频类别标签（封面左上角那枚）。
///
/// 鸿蒙：`Text(KanoText.ui('kind_$tag')).fontSize(9.5).fontWeight(Medium).fontColor(White)
/// .padding(l5,r5,t2,b2).borderRadius(4).backgroundColor(KanoApi.kindColor(tag)).position(x:6,y:6)`
class VideoTagChip extends StatelessWidget {
  const VideoTagChip({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    if (tag.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Color(KanoKind.colorValue(tag)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        KanoText.ui('kind_$tag'),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 封面右下角的状态角标：直播中 / 待开始 / 时长
class _CoverBadge extends StatelessWidget {
  const _CoverBadge({this.text, this.color, this.dot = false, this.leadingPlay = false});

  final String? text;
  final Color? color;
  final bool dot;
  final bool leadingPlay;

  @override
  Widget build(BuildContext context) {
    final label = text;
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? const Color(0x9E000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingPlay) ...[
            // 鸿蒙用 sys.symbol.play_fill + fontSize(10)，间距 4
            const Icon(Icons.play_arrow_rounded, size: 10, color: Colors.white),
            const SizedBox(width: 4),
          ],
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// YouTube 网格卡片：封面（角标 + 标签）+ 标题两行 + 日期。
///
/// 鸿蒙 `YoutubeTile`：`Column({space: 6})` + `aspectRatio(tileRatio)` + `borderRadius(10)`
/// + 标题 `13/18 Medium` 两行 + 日期 `11` 次要色。
class YoutubeTile extends StatelessWidget {
  const YoutubeTile({super.key, required this.video, this.slot = 0});

  final KanoVideo video;

  /// 列表序号：只用于错落入场的延迟（鸿蒙 `Math.min(slot, 9)`）
  final int slot;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final isLive = video.liveStatus == 'live';
    final isUpcoming = video.liveStatus == 'upcoming';

    return StaggeredEnter(
      index: slot,
      child: GestureDetector(
      onTap: () {
        KanoHaptics.tap();
        KanoLauncher.open(context, video.url);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_mediaRadius),
            child: AspectRatio(
              // 鸿蒙 tileRatio：Shorts 9:16，其余 16:9
              aspectRatio: video.isShort ? 9 / 16 : 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: palette.skeletonSoft,
                      child: KanoImage(url: video.thumb, radius: 0),
                    ),
                  ),
                  // 角标在右下：直播红底白点、待开始半透明黑、其余时长
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: isLive
                        ? _CoverBadge(text: KanoText.ui('status_live'), color: const Color(0xFFF0263C), dot: true)
                        : isUpcoming
                            ? _CoverBadge(text: KanoText.ui('status_scheduled'), color: const Color(0x8C000000))
                            : _CoverBadge(text: durationText(video.durationSeconds)),
                  ),
                  // 标签在左上，与角标分开不打架
                  Positioned(
                    left: 6,
                    top: 6,
                    child: VideoTagChip(tag: video.tag),
                  ),
                ],
              ),
            ),
          ),
          if (video.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
            ),
          if (cardDate(video.publishedAtMs) case final date when date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                date,
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// 卡片下方的日期，与鸿蒙 `FeedPage.cardDate()` 逐字一致：
/// 中文「10月25日周日」、日文「10月25日(日)」、英文「Oct 25 Sun」，不是今年补年份。
String cardDate(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final lang = KanoText.langIndex;
  // Dart 的 weekday 是周一起算的 1..7，与 KanoText.week* 表一致，减一即下标
  final weekIndex = d.weekday - 1;
  final thisYear = DateTime.now().year;
  if (lang == 3) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final md = '${months[d.month - 1]} ${d.day} ${KanoText.weekShort(weekIndex)}';
    return d.year == thisYear ? md : '$md, ${d.year}';
  }
  if (lang == 2) {
    return '${d.month}月${d.day}日(${KanoText.weekShort(weekIndex)})';
  }
  return '${d.month}月${d.day}日${KanoText.weekFull(weekIndex)}';
}

/// B 站投稿网格卡片，与 [YoutubeTile] 同一套版式，只是角标换成「播放量 + 时长」。
///
/// 鸿蒙 `BiliVideoTile`：左下 `play_fill + playText`、右下时长、左上固定「投稿」标签、
/// 标题 `13/18 Medium` 两行、副行 `bilibili · 相对时间` `11`。
class BiliVideoTile extends StatelessWidget {
  const BiliVideoTile({super.key, required this.item, this.slot = 0});

  final BiliVideoItem item;

  /// 列表序号：只用于错落入场的延迟
  final int slot;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return StaggeredEnter(
      index: slot,
      child: GestureDetector(
      onTap: () {
        KanoHaptics.tap();
        KanoLauncher.open(context, item.url);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_mediaRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: palette.skeletonSoft,
                      child: KanoImage(url: item.cover, radius: 0),
                    ),
                  ),
                  // 底部一行：左播放量、右时长（与 B 站自己一致）
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Row(
                      children: [
                        // 鸿蒙两枚角标都是 rgba(0,0,0,0.55)
                        _CoverBadge(
                          text: item.playText,
                          color: const Color(0x8C000000),
                          leadingPlay: true,
                        ),
                        const Spacer(),
                        _CoverBadge(
                          text: durationText(item.durationSec),
                          color: const Color(0x8C000000),
                        ),
                      ],
                    ),
                  ),
                  // B 站这一栏拉的全是空间投稿，标签固定「投稿」
                  const Positioned(
                    left: 6,
                    top: 6,
                    child: VideoTagChip(tag: KanoKind.video),
                  ),
                ],
              ),
            ),
          ),
          if (item.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
            ),
          if (KanoTime.relativeTime(item.timeMs) case final time when time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  KanoBrandMark(kind: 'bilibili', size: 11, color: palette.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'bilibili · $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// B 站动态卡：头像行 → 标题 → 正文 → 转发引用 → 配图 → 统计。
///
/// 鸿蒙 `BiliDynamicCard` 的尺寸：头像 42、名字 15 Bold、副行 `bilibili · 相对时间` 12、
/// 标题 15 Bold/21 两行 margin top 10、正文 14.5/22 十行 margin top 8、
/// 引用块 padding 10 radius 10 margin top 8、统计行 space 22 margin top 12、
/// 整卡 padding 14 radius 18。
class BiliDynamicCard extends StatelessWidget {
  const BiliDynamicCard({super.key, required this.item, this.space, this.slot = 0});

  final BiliDynamicItem item;
  final BiliSpaceInfo? space;

  /// 列表序号：只用于错落入场的延迟
  final int slot;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final name = (space != null && space!.name.isNotEmpty) ? space!.name : 'bilibili';
    final face = space?.face ?? '';
    final time = KanoTime.relativeTime(item.timeMs);

    return StaggeredEnter(
      index: slot,
      child: GestureDetector(
      onTap: () {
        KanoHaptics.tap();
        KanoLauncher.open(context, item.url);
      },
      behavior: HitTestBehavior.opaque,
      child: KanoSurface(
        padding: const EdgeInsets.all(14),
        radius: 18,
        border: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头像行
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KanoAvatar(
                  url: face,
                  name: name,
                  size: 42,
                  letterBackground: const Color(0xFF1D9BF0),
                  letterForeground: const Color(0xFFFFFFFF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        time.isEmpty ? 'bilibili' : 'bilibili · $time',
                        maxLines: 1,
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            if (item.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  item.text,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 22 / 14.5,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            // 转发：正文已经在上面，这里只留被转原文摘要，不重复渲染图
            if (item.isForward && (item.quoteAuthor.isNotEmpty || item.quoteText.isNotEmpty))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.isLight ? const Color(0x0A000000) : const Color(0x0FFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.quoteAuthor.isNotEmpty)
                      Text(
                        '@${item.quoteAuthor}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: palette.textSecondary,
                        ),
                      ),
                    if (item.quoteText.isNotEmpty) ...[
                      if (item.quoteAuthor.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        item.quoteText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 19 / 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (item.pics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: BiliPics(pics: item.pics, ratio: item.picRatio),
              ),
            if (item.like > 0 || item.comment > 0 || item.forward > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (item.forward > 0) ...[
                      _DynStat(icon: Icons.repeat_rounded, value: item.forward),
                      const SizedBox(width: 22),
                    ],
                    if (item.comment > 0) ...[
                      _DynStat(icon: Icons.chat_bubble_outline_rounded, value: item.comment),
                      const SizedBox(width: 22),
                    ],
                    if (item.like > 0) _DynStat(icon: Icons.favorite_border_rounded, value: item.like),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _DynStat extends StatelessWidget {
  const _DynStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          countText(value),
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// 动态配图网格，照鸿蒙 `DynamicPics` / `picColumns` / `picWidth`：
/// 1 张 100% 宽按原比例，2 张各 49% 方图，3 张及以上 32% 三列方图，行间 6。
class BiliPics extends StatelessWidget {
  const BiliPics({super.key, required this.pics, required this.ratio});

  final List<String> pics;
  final double ratio;

  static int _columns(int count) {
    if (count <= 1) return 1;
    return count == 2 ? 2 : 3;
  }

  void _open(BuildContext context, int index) {
    KanoHaptics.tap();
    // 列表里是带 @640w 的缩略图，预览要原图
    final originals = pics.map(BiliDynamicApi.originalOf).toList(growable: false);
    KanoImageViewer.show(context, originals, index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final cols = _columns(pics.length);
    final rows = <List<int>>[];
    for (var i = 0; i < pics.length; i += cols) {
      rows.add([for (var j = i; j < i + cols && j < pics.length; j++) j]);
    }
    // 鸿蒙 `picWidth()` 用的是百分比：1 列 100%、2 列 49%、3 列 32%，
    // 行内 `SpaceBetween` 把剩下的分掉。用固定百分比而不是均分，
    // 才不会在不同屏宽下把缝越拉越宽。
    final percent = cols == 1 ? 1.0 : (cols == 2 ? 0.49 : 0.32);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth * percent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var slot = 0; slot < cols; slot++)
                    if (slot < rows[r].length)
                      SizedBox(
                        width: tileWidth,
                        child: GestureDetector(
                          onTap: () => _open(context, rows[r][slot]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(_mediaRadius),
                            child: AspectRatio(
                              // 单图按首图比例（接口已夹在 0.6~1.8），多图方图
                              aspectRatio: cols == 1 ? ratio.clamp(0.6, 1.8) : 1,
                              child: ColoredBox(
                                color: palette.skeletonSoft,
                                child: KanoImage(url: pics[rows[r][slot]], radius: 0),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      // 缺的槽位按同宽留白，最后一行不会被拉伸
                      SizedBox(width: tileWidth),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 「加载更多 / 加载中 / 到底了」的收尾行，照鸿蒙 `XMoreRow` / `BiliMoreRow` / `DynMoreRow`。
class FeedMoreRow extends StatelessWidget {
  const FeedMoreRow({
    super.key,
    required this.hasMore,
    required this.loading,
    required this.onMore,
  });

  final bool hasMore;
  final bool loading;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    if (loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: palette.textSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              KanoText.ui('feed_loading'),
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: Text(
            KanoText.ui('feed_reached_end'),
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: GestureDetector(
          onTap: onMore,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.hairline, width: 1),
            ),
            child: Text(
              KanoText.ui('feed_load_more'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                // 与鸿蒙一致：链接蓝，不用主题粉
                color: Color(0xFF1D9BF0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// B 站 / YouTube 一栏专用的空态，照鸿蒙 `MediaEmptyState`：图标 34 + 文案 14 Medium，
/// 上下各 34，卡片底 18 圆角。
class FeedMediaEmpty extends StatelessWidget {
  const FeedMediaEmpty({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return KanoSurface(
      padding: const EdgeInsets.symmetric(vertical: 34),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_outlined, size: 34, color: palette.skeletonStrong),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 失败态，照鸿蒙 `BiliFailedState`：图标 + 一句「连不上」+ 蓝边重试钮，上下各 30。
class FeedFailed extends StatelessWidget {
  const FeedFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return KanoSurface(
      padding: const EdgeInsets.symmetric(vertical: 30),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 34, color: palette.skeletonStrong),
          const SizedBox(height: 10),
          Text(
            KanoText.ui('kano_unreachable'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1D9BF0), width: 1),
              ),
              child: Text(
                KanoText.ui('feed_retry'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D9BF0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// X 卡片流骨架，照鸿蒙 `XSkeletonCard`：头像 40 + 两行标题占位 + 三行正文 + 三个计数。
class FeedXSkeletonCard extends StatelessWidget {
  const FeedXSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const KanoSurface(
      padding: EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              KanoBlock(width: 40, height: 40, radius: 20, strong: true),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  KanoBlock(width: 120, height: 14, radius: 5, strong: true),
                  SizedBox(height: 6),
                  KanoBlock(width: 78, height: 11, radius: 4),
                ],
              ),
              Spacer(),
              KanoBlock(width: 18, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: 12),
          KanoBlock(height: 12, radius: 4, strong: true),
          SizedBox(height: 8),
          KanoBlock(height: 12, radius: 4, strong: true),
          SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.58,
            child: KanoBlock(height: 12, radius: 4),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              KanoBlock(width: 44, height: 11, radius: 4),
              SizedBox(width: 26),
              KanoBlock(width: 44, height: 11, radius: 4),
              SizedBox(width: 26),
              KanoBlock(width: 44, height: 11, radius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// 网格骨架，照鸿蒙 `GridSkeleton` + `GridSkeletonTile`：
/// 封面按分类换比例（Shorts 9:16、其余 16:9），下面两条文字占位，行间 14。
class FeedGridSkeleton extends StatelessWidget {
  const FeedGridSkeleton({super.key, required this.cols, required this.tileWidth, required this.shorts});

  final int cols;
  final double tileWidth;
  final bool shorts;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    Widget tile() => SizedBox(
          width: tileWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: shorts ? 9 / 16 : 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.skeletonStrong,
                    borderRadius: BorderRadius.circular(_mediaRadius),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const KanoBlock(height: 12, radius: 4, strong: true),
              const SizedBox(height: 6),
              const FractionallySizedBox(
                widthFactor: 0.66,
                child: KanoBlock(height: 12, radius: 4),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < cols; c++) tile(),
            ],
          ),
        ],
      ],
    );
  }
}
