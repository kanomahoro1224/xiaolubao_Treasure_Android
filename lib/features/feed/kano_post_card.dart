import 'package:flutter/material.dart';

import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_image.dart';
import '../kano/presentation/kano_image_viewer.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_palette.dart';
import '../kano/presentation/staggered_enter.dart';

/// X 帖子卡。主页「最新动态」与动态页共用同一张。
///
/// 版式逐项对齐鸿蒙 `KanoPostCard.ets`：转推抬头 → 头像行 → 正文（可切译文）→ 图片 →
/// 引用块，容器 padding 14 / 圆角 18 / 半透明底 + 背景模糊、**无描边**。
/// 鸿蒙那份没有互动数行，这里也不画（服务端虽然有 likes/reposts/replies）。
class KanoPostCard extends StatefulWidget {
  const KanoPostCard({
    super.key,
    required this.post,
    this.profile,
    this.slot = 0,
    this.onOpen,
  });

  final KanoPost post;
  final KanoProfile? profile;

  /// 列表里的序号，只用来算错落入场的延迟（鸿蒙 `Math.min(slot, 9)`）
  final int slot;
  final VoidCallback? onOpen;

  @override
  State<KanoPostCard> createState() => _KanoPostCardState();
}

class _KanoPostCardState extends State<KanoPostCard> {
  bool _showOriginal = false;

  KanoPost get post => widget.post;

  KanoProfile? get profile => widget.profile;

  bool get _translated => post.translated && post.originalText != post.text;

  String _avatarFor(String handle) {
    final p = profile;
    if (p == null || p.avatar.isEmpty) return '';
    final lower = handle.toLowerCase();
    if (p.mainHandle.isNotEmpty && p.mainHandle == lower) return p.avatar;
    // 小号与主号是同一个人：后台只维护一张头像，直接共用
    if (p.ownerHandles.contains(lower)) return p.avatar;
    return '';
  }

  String _displayNameFor(String handle) {
    final p = profile;
    if (p != null && p.mainHandle.isNotEmpty && p.mainHandle == handle.toLowerCase()) {
      return p.displayName;
    }
    return '@$handle';
  }

  String get _shownHandle {
    final repost = post.repost;
    return (repost != null && repost.authorHandle.isNotEmpty) ? repost.authorHandle : post.handle;
  }

  String get _shownName {
    final repost = post.repost;
    if (repost == null) return _displayNameFor(post.handle);
    return repost.authorName.isNotEmpty
        ? repost.authorName
        : (repost.authorHandle.isNotEmpty ? '@${repost.authorHandle}' : post.handle);
  }

  String get _shownAvatar {
    final repost = post.repost;
    if (repost != null && repost.avatarUrl.isNotEmpty) return repost.avatarUrl;
    return _avatarFor(_shownHandle);
  }

  int get _shownTimeMs {
    final repost = post.repost;
    return (repost != null && repost.timeMs > 0) ? repost.timeMs : post.timeMs;
  }

  String get _shownMeta {
    final repost = post.repost;
    final handle = repost != null
        ? (repost.authorHandle.isNotEmpty ? '@${repost.authorHandle}' : '')
        : '@${post.handle}';
    final time = KanoTime.relativeTime(_shownTimeMs);
    return handle.isEmpty ? time : '$handle · $time';
  }

  String get _openTarget {
    final repost = post.repost;
    return (repost != null && repost.url.isNotEmpty) ? repost.url : post.url;
  }

  void _open() {
    KanoHaptics.tap();
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    KanoLauncher.open(context, _openTarget);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return StaggeredEnter(
      index: widget.slot,
      child: GestureDetector(
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: KanoSurface(
          padding: const EdgeInsets.all(14),
          radius: 18,
          // 鸿蒙卡片只有半透明底 + backgroundBlurStyle(Thin)，没有描边
          border: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.repost != null) ...[
              Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 13, color: palette.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      KanoText.uiFmt('feed_reposted', _displayNameFor(post.handle)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KanoAvatar(
                  url: _shownAvatar,
                  name: _shownName,
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
                        _shownName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _shownMeta,
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showOriginal ? post.originalText : post.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 22 / 14.5,
                      color: palette.textPrimary,
                    ),
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_translated)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _showOriginal = !_showOriginal),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.translate_rounded, size: 13, color: Color(0xFF1D9BF0)),
                            const SizedBox(width: 4),
                            Text(
                              KanoText.ui(_showOriginal ? 'feed_show_translation' : 'feed_show_original'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1D9BF0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (post.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _MediaBlock(post: post),
              ),
            if (post.quote != null) _QuotedBlock(quote: post.quote!),
          ],
        ),
        ),
      ),
    );
  }
}

/// 配图：1 张按原比例（长图夹在 0.55~2.2），2 张并排，≥3 张走 2 列方格。
class _MediaBlock extends StatelessWidget {
  const _MediaBlock({required this.post});

  final KanoPost post;

  List<String> get _urls => post.media.map((m) => m.url).toList(growable: false);

  void _openViewer(BuildContext context, int index) {
    KanoImageViewer.show(context, _urls, index);
  }

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    if (media.isEmpty) return const SizedBox.shrink();

    if (media.length == 1) {
      final ratio = media.first.ratio.clamp(0.55, 2.2);
      return LayoutBuilder(
        builder: (context, constraints) {
          // 整宽按比例推出来的高度超过 480 时收窄宽度，免得一张长图顶出两屏。
          // 480 是鸿蒙 `ResponsiveLayout.MEDIA_MAX_HEIGHT`，之前这里误写成 420，
          // 长图会比鸿蒙那边小一号。
          const maxHeight = 480.0;
          final fullWidth = constraints.maxWidth;
          var width = fullWidth;
          var height = width / ratio;
          if (height > maxHeight) {
            height = maxHeight;
            width = (maxHeight * ratio).floorToDouble();
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => _openViewer(context, 0),
              child: SizedBox(
                width: width,
                height: height,
                child: KanoImage(url: media.first.url, radius: 12),
              ),
            ),
          );
        },
      );
    }

    if (media.length == 2) {
      return Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: () => _openViewer(context, i),
                  child: KanoImage(url: media[i].url, radius: 12),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // ≥3 张：左列 [0, 3]，右列 [1, 2]；只有 3 张时右下留空对齐
    Widget tile(int index) => AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onTap: () => _openViewer(context, index),
            child: KanoImage(url: media[index].url, radius: 12),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              tile(0),
              const SizedBox(height: 6),
              if (media.length >= 4) tile(3) else const AspectRatio(aspectRatio: 1),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              tile(1),
              const SizedBox(height: 6),
              if (media.length >= 3) tile(2) else const AspectRatio(aspectRatio: 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuotedBlock extends StatelessWidget {
  const _QuotedBlock({required this.quote});

  final KanoQuote quote;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  quote.authorName.isNotEmpty ? quote.authorName : '@${quote.authorHandle}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (quote.authorName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '@${quote.authorHandle}',
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (quote.unavailable)
            Text(
              KanoText.ui('feed_quote_gone'),
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            )
          else
            Text(
              quote.text,
              style: TextStyle(fontSize: 12.5, height: 18 / 12.5, color: palette.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (quote.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => KanoImageViewer.show(
                  context,
                  quote.media.map((m) => m.url).toList(growable: false),
                  0,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: KanoImage(url: quote.media.first.url, radius: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
