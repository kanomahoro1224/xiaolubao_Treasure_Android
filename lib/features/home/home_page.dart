import 'dart:async';

import 'package:flutter/material.dart';

import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_brand_mark.dart';
import '../kano/presentation/kano_image.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_palette.dart';
import '../kano/presentation/kano_state.dart';
import '../kano/presentation/kano_calendar_export.dart';
import '../feed/kano_post_card.dart';

/// 主页 = kano-navi 的 KanoDashboard。
///
/// 手机单列顺序（与鸿蒙 `RecentPage` 一致）：
/// 资料卡 → 下一场 → 最新动态 → 最新视频 → 官方账号。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  /// 底栏切页用 PageView 承载，离开视口时必须保活，否则每次切回来都重新拉一遍数据
  @override
  bool get wantKeepAlive => true;

  KanoDashboard? _data;
  KanoSource _source = KanoSource.error;
  int _cachedAt = 0;
  bool _loading = false;
  bool _firstLoadDone = false;
  Timer? _ticker;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    // 每秒走一次，只为了让倒计时与「直播中」状态跟着变
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    });
    _load(force: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool force}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await KanoRepository.instance.dashboard(force: force);
    if (!mounted) return;
    setState(() {
      _data = result.data ?? _data;
      _source = result.source;
      _cachedAt = result.cachedAt;
      _loading = false;
      _firstLoadDone = true;
    });
  }

  /// 官方 B 站入口：dashboard resources 里按域名挑，和鸿蒙 `bilibiliUrl()` 一样。
  String _bilibiliUrl(List<KanoResource> items) {
    for (final item in items) {
      if (item.url.contains('bilibili.com')) return item.url;
    }
    return '';
  }

  String _countdownText(int remainMs) {
    if (remainMs <= 0) return KanoText.ui('recent_countdown_started');
    final totalSec = remainMs ~/ 1000;
    final days = totalSec ~/ 86400;
    final hours = (totalSec % 86400) ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    if (days > 0) return '$days:${pad(hours)}:${pad(minutes)}';
    return '${pad(hours)}:${pad(minutes)}:${pad(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = KanoPalette.of(context);
    final data = _data;

    return RefreshIndicator(
      color: palette.berry,
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header(palette)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(KanoGap.page, 0, KanoGap.page, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                KanoStatusBar(
                  isStale: _source.isStale,
                  isError: _source == KanoSource.error,
                  cachedAt: _cachedAt,
                  loading: _loading && data != null,
                  onRetry: () => _load(force: true),
                ),
                if (!_firstLoadDone && data == null)
                  _HomeSkeleton(palette: palette)
                else if (data == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: KanoErrorView(onRetry: () => _load(force: true)),
                  )
                else ...[
                  _ProfileCard(
                    profile: data.profile,
                    accounts: data.xAccounts,
                    bilibiliUrl: _bilibiliUrl(data.resources),
                    palette: palette,
                  ),
                  const SizedBox(height: KanoGap.section),
                  KanoSectionLabel(KanoText.ui('recent_section_next')),
                  _NextEventCard(
                    data: data,
                    nowMs: _nowMs,
                    palette: palette,
                    countdownText: _countdownText,
                  ),
                  if (data.latestPost != null) ...[
                    const SizedBox(height: KanoGap.section),
                    KanoSectionLabel(KanoText.ui('recent_section_post')),
                    _LatestPost(post: data.latestPost!, profile: data.profile),
                  ],
                  if (data.latestVideo != null) ...[
                    const SizedBox(height: KanoGap.section),
                    KanoSectionLabel(KanoText.ui('recent_section_video')),
                    _LatestVideoCard(video: data.latestVideo!, palette: palette),
                  ],
                  if (data.resources.isNotEmpty) ...[
                    const SizedBox(height: KanoGap.section),
                    KanoSectionLabel(KanoText.ui('journey_section_accounts')),
                    _ResourcePanel(items: data.resources, palette: palette),
                  ],
                  if (data.lastSyncMs > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          KanoText.uiFmt('kano_synced_at', KanoTime.relativeTime(data.lastSyncMs)),
                          style: TextStyle(fontSize: 11, color: palette.textTertiary),
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(KanoPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KanoGap.page, 8, KanoGap.page, 10),
      child: Row(
        children: [
          Text(
            KanoText.ui('tab_recent'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
              height: 1.15,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _load(force: true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                _loading ? KanoText.ui('kano_syncing') : KanoText.ui('kano_refresh'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.berry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 资料卡：横幅 128 + 头像 84 上移 42 + kicker / 名字 / 罗马字 / 标语 / 平台入口。
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.accounts,
    required this.bilibiliUrl,
    required this.palette,
  });

  final KanoProfile? profile;
  final List<String> accounts;
  final String bilibiliUrl;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return KanoSurface(
      padding: EdgeInsets.zero,
      radius: KanoRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: p != null && p.banner.isNotEmpty
                ? KanoImage(url: p.banner)
                : Container(color: palette.berryWash),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p != null)
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: KanoAvatar(
                      url: p.avatar,
                      name: p.displayName,
                      size: 84,
                      ringColor: palette.avatarRing,
                      ringWidth: 4,
                    ),
                  ),
                if (p != null) const SizedBox(height: 0) else const SizedBox(height: 12),
                Transform.translate(
                  offset: p != null ? const Offset(0, -34) : Offset.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          KanoText.ui('hero_kicker').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
                            color: palette.berry,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p?.displayName ?? '',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p != null && p.romanizedName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          p.romanizedName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: palette.textTertiary,
                          ),
                          maxLines: 1,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        KanoText.ui('hero_catchphrase'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.berry,
                        ),
                      ),
                      // RecentPage.ProfileCard 不画 profile.bio。
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final account in accounts)
                            _LinkChip(
                              label: '@$account',
                              brand: 'x',
                              palette: palette,
                              onTap: () => KanoLauncher.open(context, 'https://x.com/$account'),
                            ),
                          if (p != null && p.youtubeUrl.isNotEmpty)
                            _LinkChip(
                              brand: 'youtube',
                              palette: palette,
                              onTap: () => KanoLauncher.open(context, p.youtubeUrl),
                            ),
                          if (bilibiliUrl.isNotEmpty)
                            _LinkChip(
                              brand: 'bilibili',
                              palette: palette,
                              onTap: () => KanoLauncher.open(context, bilibiliUrl),
                            ),
                        ],
                      ),
                    ],
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

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.brand,
    required this.palette,
    required this.onTap,
    this.label,
  });

  final String brand;
  final String? label;
  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: EdgeInsets.only(left: hasLabel ? 12 : 0, right: hasLabel ? 14 : 0),
        width: hasLabel ? null : 34,
        decoration: BoxDecoration(
          color: palette.panelBg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: palette.hairline, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KanoBrandMark(kind: brand, size: hasLabel ? 13 : 17, color: palette.textPrimary),
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 下一场：JST 是官方口径，本地时间另起一行。
class _NextEventCard extends StatelessWidget {
  const _NextEventCard({
    required this.data,
    required this.nowMs,
    required this.palette,
    required this.countdownText,
  });

  final KanoDashboard data;
  final int nowMs;
  final KanoPalette palette;
  final String Function(int) countdownText;

  @override
  Widget build(BuildContext context) {
    final event = data.nextEvent;
    return KanoSurface(
      child: event == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  KanoText.ui('recent_no_stream'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  KanoText.ui('recent_no_stream_hint'),
                  style: TextStyle(fontSize: 12, height: 1.5, color: palette.textSecondary),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: event.liveStatus == 'live' ? palette.liveRed : palette.berry,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        event.statusText(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.timeText(),
                  style: TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
                if (event.detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.detail,
                    style: TextStyle(fontSize: 12, height: 1.5, color: palette.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.localTimeText().isNotEmpty)
                            Text(
                              event.localTimeText(),
                              style: TextStyle(fontSize: 12, color: palette.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 3),
                          Text(
                            '${event.provenanceText()}${event.source.isEmpty ? '' : ' · ${event.source}'}',
                            style: TextStyle(fontSize: 11, color: palette.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (event.timeMs > nowMs)
                      GestureDetector(
                        onTap: () => KanoCalendarExport.addEvent(context, event),
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.berry, width: 1.5),
                          ),
                          child: Icon(Icons.event_available_rounded, size: 19, color: palette.berry),
                        ),
                      ),
                    if (event.timeMs > nowMs)
                      Text(
                        countdownText(event.timeMs - nowMs),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: palette.berry,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        KanoText.ui('recent_countdown_started'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: palette.berry,
                        ),
                      ),
                  ],
                ),
                if (event.cancelNote().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    event.cancelNote(),
                    style: TextStyle(fontSize: 11, height: 1.45, color: palette.liveRed),
                  ),
                ],
              ],
            ),
    );
  }
}

/// 最新动态：直接复用动态页那张卡，保证两处视觉与交互一致。
///
/// 鸿蒙 `RecentPage` 给这张卡固定传 `slot: 2`（它在近况页是第 3 个区块），
/// 错落入场的延迟照抄，不要在主页里变成 0 抢在标题前面出来。
class _LatestPost extends StatelessWidget {
  const _LatestPost({required this.post, required this.profile});

  final KanoPost post;
  final KanoProfile? profile;

  @override
  Widget build(BuildContext context) {
    return KanoPostCard(post: post, profile: profile, slot: 2);
  }
}

class _LatestVideoCard extends StatelessWidget {
  const _LatestVideoCard({required this.video, required this.palette});

  final KanoVideo video;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    return KanoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: video.isShort ? 0.75 : 16 / 9,
            child: GestureDetector(
              onTap: () => KanoLauncher.open(context, video.url),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KanoImage(url: video.thumb, radius: KanoRadius.media),
                  if (video.durationText.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          video.durationText,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  if (video.isLive || video.isUpcoming)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: video.isLive ? palette.liveRed : palette.berry,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          video.isLive ? 'LIVE' : 'UPCOMING',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  video.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.play_circle_fill_rounded, size: 20, color: palette.berry),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PlatformPill(
                brand: 'youtube',
                label: 'YouTube',
                palette: palette,
                onTap: () => KanoLauncher.open(context, video.url),
              ),
              if (video.hasBilibili)
                _PlatformPill(
                  brand: 'bilibili',
                  label: 'bilibili',
                  palette: palette,
                  onTap: () => KanoLauncher.open(context, video.bilibiliUrl),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(KanoKind.colorValue(video.tag)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.tagLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (video.kind.isNotEmpty) video.kind,
                    KanoTime.relativeTime(
                      video.publishedAtMs > 0 ? video.publishedAtMs : video.scheduledAtMs,
                    ),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  const _PlatformPill({
    required this.brand,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String brand;
  final String label;
  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: palette.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.hairline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KanoBrandMark(kind: brand, size: 12, color: palette.textPrimary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcePanel extends StatelessWidget {
  const _ResourcePanel({required this.items, required this.palette});

  final List<KanoResource> items;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    return KanoSurface(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ResourceRow(item: items[i], palette: palette),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 58, right: 16),
                child: Divider(height: 1, thickness: 1, color: palette.hairline),
              ),
          ],
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.item, required this.palette});

  final KanoResource item;
  final KanoPalette palette;

  /// 按标题/副文案里出现的关键字判断平台标，判不出就用通用点。
  String get _brand {
    final hay = '${item.title} ${item.detail} ${item.url} ${item.icon}'.toLowerCase();
    if (hay.contains('youtube') || hay.contains('youtu.be')) return 'youtube';
    if (hay.contains('bilibili') || hay.contains('b23.tv')) return 'bilibili';
    if (hay.contains('x.com') || hay.contains('twitter')) return 'x';
    return item.icon;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KanoLauncher.open(context, item.url),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: palette.iconTileBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: KanoBrandMark(kind: _brand, size: 16, color: palette.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.north_east_rounded, size: 15, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.palette});

  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    return const KanoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              KanoBlock(width: 64, height: 64, radius: 32, strong: true),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KanoBlock(width: 120, height: 16, strong: true),
                    SizedBox(height: 8),
                    KanoBlock(width: 180, height: 12),
                    SizedBox(height: 8),
                    KanoBlock(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          KanoBlock(height: 84, radius: 20, strong: true),
          SizedBox(height: 10),
          KanoBlock(height: 120, radius: 20),
          SizedBox(height: 10),
          KanoBlock(width: 200, height: 14),
        ],
      ),
    );
  }
}
