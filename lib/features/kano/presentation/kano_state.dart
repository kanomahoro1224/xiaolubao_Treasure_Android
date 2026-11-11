import 'package:flutter/material.dart';

import '../domain/kano_text.dart';
import '../domain/kano_time.dart';
import 'kano_palette.dart';

/// 骨架块（加载中的灰条）
class KanoBlock extends StatelessWidget {
  const KanoBlock({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.strong = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: strong ? palette.skeletonStrong : palette.skeletonSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 通用的「加载中 / 空 / 出错」三种状态条。
///
/// 离线时不是一句干巴巴的「加载失败」——服务端本身就是快照模型，
/// 客户端也留了磁盘快照，所以这里显示「显示的是上次同步的内容 + 时间」。
class KanoStatusBar extends StatelessWidget {
  const KanoStatusBar({
    super.key,
    required this.isStale,
    required this.isError,
    required this.cachedAt,
    this.onRetry,
    this.loading = false,
  });

  final bool isStale;
  final bool isError;
  final int cachedAt;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: palette.berry),
            ),
            const SizedBox(width: 8),
            Text(
              KanoText.ui('feed_loading'),
              style: TextStyle(fontSize: 12, color: palette.textTertiary),
            ),
          ],
        ),
      );
    }
    if (!isStale) return const SizedBox.shrink();

    final when = cachedAt > 0 ? KanoTime.relativeTime(cachedAt) : '';
    final message = isError ? KanoText.ui('kano_unreachable') : KanoText.ui('kano_offline_snapshot');
    final subtitle = when.isEmpty ? '' : KanoText.uiFmt('kano_synced_at', when);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.berryWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 14, color: palette.berry),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: palette.berry, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: palette.berry.withValues(alpha: 0.75)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: Text(
                  KanoText.ui('feed_retry'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.berry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 整页错误态（真的一条数据都没有时）
class KanoErrorView extends StatelessWidget {
  const KanoErrorView({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 42, color: palette.textTertiary),
            const SizedBox(height: 14),
            Text(
              message ?? KanoText.ui('kano_unreachable'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              KanoText.ui('kano_offline_snapshot'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: palette.berryWash,
                foregroundColor: palette.berry,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(KanoText.ui('feed_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空态
class KanoEmptyView extends StatelessWidget {
  const KanoEmptyView({super.key, required this.text, this.icon = Icons.inbox_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: palette.textTertiary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
