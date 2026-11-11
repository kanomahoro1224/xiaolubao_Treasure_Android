import 'package:flutter/material.dart';

import '../kano/data/bilibili_api.dart';
import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_brand_mark.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_palette.dart';
import 'feed_tiles.dart';
import 'kano_post_card.dart';

// 动态页，逐条对齐鸿蒙 `FeedPage.ets`。
//
// 结构与鸿蒙完全一致：
//   Stack(alignContent: Top)
//     Scroll(padding: 16/16/headerHeight/168)   ← 内容整列
//     Column(space 8)                            ← 浮层头部
//       Scroll(height 48, padding h16)           ← 平台行（纯图标胶囊）
//       Scroll(height 60, padding h16 b4)        ← 分类行
//
// 三处曾经做错、这次按源文件改回来：
// 1. 平台行/分类行是浮层，内容是靠 top 内边距让位的（不是并排的 Column）；
// 2. 视频是网格：手机竖屏 16:9 两列、Shorts 三列（ResponsiveLayout），之前排成单列大卡；
// 3. 分类胶囊 60 高的行、48 高的胶囊、15 号字，按文案实测宽度定宽。

/// 平台。顺序与鸿蒙 `PLATFORMS` 一致；微博、twitch 在鸿蒙里 `hidden = true`，这里同样不上。
enum _Platform { x, bilibili, youtube }

class _TabDef {
  const _TabDef(this.key, this.labelKey, this.chipWidth);

  final String key;
  final String labelKey;

  /// 鸿蒙 `FeedTab.chipWidth`：文案变长（日语）时还要按字数再放宽
  final double chipWidth;
}

const _tabs = <_Platform, List<_TabDef>>{
  _Platform.x: [
    _TabDef('', 'filter_all', 74),
    _TabDef('kano_2525', 'filter_kano', 78),
    _TabDef('_kanotic', 'filter_kanotic', 108),
  ],
  _Platform.bilibili: [
    _TabDef('video', 'tab_video', 74),
    _TabDef('dynamic', 'tab_dynamic', 74),
  ],
  _Platform.youtube: [
    _TabDef('live', 'tab_live', 74),
    _TabDef('video', 'tab_video', 74),
    _TabDef('shorts', 'tab_shorts', 78),
  ],
};

const _platformBrand = <_Platform, String>{
  _Platform.x: 'x',
  _Platform.bilibili: 'bilibili',
  _Platform.youtube: 'youtube',
};

/// 与鸿蒙同名的四个常量
const double _platformBarHeight = 48;
const double _filterBarHeight = 60;
const double _platformChipWidth = 56;
const double _platformIconSize = 18;
const double _pagePadding = 16;

/// 卡片流列间距 12（鸿蒙 `Column({space: 12})`）
const double _cardGap = 12;

/// 网格行间距 14（鸿蒙 `Column({space: 14})`）
const double _gridRowGap = 14;

/// 16:9 媒体网格列数（`ResponsiveLayout.landscapeColumns`）
int _landscapeColumns(double width) {
  if (width >= 840) return 4;
  return width >= 600 ? 3 : 2;
}

/// 9:16 竖版网格列数（`ResponsiveLayout.portraitColumns`）
int _portraitColumns(double width) {
  if (width >= 840) return 5;
  return width >= 600 ? 4 : 3;
}

/// 胶囊按文案实测宽度：中日文 15vp/字、拉丁 8vp/字，再留 28 的内边距。
/// 鸿蒙 `tabChipWidth()` 的同一套估算。
double _chipWidthFor(String label, double min) {
  var textWidth = 0.0;
  for (final rune in label.runes) {
    textWidth += rune >= 0x2e80 ? 15 : 8;
  }
  final computed = textWidth.ceilToDouble() + 28;
  return computed > min ? computed : min;
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with AutomaticKeepAliveClientMixin {
  int _platformIndex = 0;
  int _filterIndex = 0;

  /// 每个平台各记一份选中项：B 站「动态」→ YouTube → 切回来仍是「动态」
  final List<int> _tabIndexCache = [0, 0, 0];

  bool _collapsed = false;

  // X
  final List<KanoPost> _xPosts = [];
  int _xPage = 0;
  int _xWindow = 0;
  bool _xHasMore = true;
  bool _xLoading = false;
  bool _xFailed = false;
  bool _xFromCache = false;
  bool _xLoaded = false;

  // bilibili 视频
  final List<BiliVideoItem> _biliItems = [];
  int _biliPage = 0;
  bool _biliHasMore = true;
  bool _biliLoading = false;
  bool _biliFailed = false;
  bool _biliLoaded = false;

  // bilibili 动态
  final List<BiliDynamicItem> _dynItems = [];
  String _dynOffset = '';
  bool _dynHasMore = true;
  bool _dynLoading = false;
  bool _dynFailed = false;
  bool _dynLoaded = false;

  BiliSpaceInfo? _biliSpace;

  // YouTube（数据来自 dashboard.videos，与鸿蒙同一来源）
  List<KanoVideo> _ytVideos = const [];
  bool _ytLoaded = false;
  bool _ytFailed = false;

  KanoProfile? _profile;

  final ScrollController _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  _Platform get _platform => _Platform.values[_platformIndex];

  List<_TabDef> get _tabsNow => _tabs[_platform]!;

  _TabDef get _tabNow => _tabsNow[_filterIndex.clamp(0, _tabsNow.length - 1)];

  /// 头部浮层占位高度：8 + 平台行 + (8 + 分类行) + 12
  double get _headerHeight =>
      8 + _platformBarHeight + (_tabsNow.isEmpty ? 0 : 8 + _filterBarHeight) + 12;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadProfile();
    _fetchX(append: false);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;

    // 滚过头部这段距离就收起平台行，回到之上自动放出来（鸿蒙 updatePlatformRowCollapsed）
    final collapsed = offset >= _headerHeight;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);

    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    switch (_platform) {
      case _Platform.x:
        if (_xHasMore && !_xLoading && !_xFailed) _fetchX(append: true);
      case _Platform.bilibili:
        if (_tabNow.key == 'dynamic') {
          if (_dynHasMore && !_dynLoading && !_dynFailed) _loadBiliDynamics(append: true);
        } else {
          if (_biliHasMore && !_biliLoading && !_biliFailed) _loadBiliFeed(append: true);
        }
      case _Platform.youtube:
        break;
    }
  }

  Future<void> _loadProfile() async {
    final result = await KanoRepository.instance.dashboard();
    if (!mounted) return;
    final data = result.data;
    setState(() {
      _profile = data?.profile;
      _ytVideos = data?.videos ?? const [];
      _ytLoaded = true;
      _ytFailed = data == null;
    });
  }

  /// 窗口 i = [今天-31i-30, 今天-31i+1]，仍是 31 天跨度，右边多留一天补 JST 与 UTC+8 的时差。
  List<String> _windowDays(int window) {
    final to = 1 - window * 31;
    return [KanoTime.dayKeyOffset(to - 30), KanoTime.dayKeyOffset(to)];
  }

  /// X 的筛选就是账号，切账号必须重拉；否则 `_xLoaded` 还是 true，点了没反应。
  String _xAccount = '';

  Future<void> _fetchX({required bool append}) async {
    if (_xLoading) return;
    setState(() {
      _xLoading = true;
      _xFailed = false;
    });
    final range = _windowDays(_xWindow);
    final account = _platform == _Platform.x ? _tabNow.key : '';
    final result = await KanoRepository.instance.posts(
      from: range[0],
      to: range[1],
      account: account,
      page: append ? _xPage + 1 : 1,
    );
    if (!mounted) return;
    final page = result.data;
    setState(() {
      _xFromCache = result.source == KanoSource.cache;
      _xAccount = account;
      if (page != null) {
        if (append) {
          _xPosts.addAll(page.items);
        } else {
          _xPosts
            ..clear()
            ..addAll(page.items);
        }
        _xPage = page.page;
        if (page.hasNext) {
          _xHasMore = true;
        } else if (page.items.isEmpty) {
          _xHasMore = false;
        } else {
          // 这一窗口翻完了，往前推一个月继续
          _xWindow += 1;
          _xPage = 0;
          _xHasMore = true;
        }
        _xLoaded = true;
      } else {
        _xFailed = true;
      }
      _xLoading = false;
    });
  }

  Future<void> _ensureBiliSpace() async {
    if (_biliSpace != null) return;
    final info = await BiliFeedApi.getSpaceInfo();
    if (info != null && mounted) setState(() => _biliSpace = info);
  }

  Future<void> _loadBiliFeed({required bool append}) async {
    if (_biliLoading) return;
    setState(() {
      _biliLoading = true;
      _biliFailed = false;
    });
    await _ensureBiliSpace();
    final page = await BiliFeedApi.getVideos(append ? _biliPage + 1 : 1);
    if (!mounted) return;
    setState(() {
      if (page != null) {
        if (append) {
          _biliItems.addAll(page.items);
        } else {
          _biliItems
            ..clear()
            ..addAll(page.items);
        }
        _biliPage = page.page;
        _biliHasMore = page.hasMore;
        _biliLoaded = true;
      } else {
        _biliFailed = true;
      }
      _biliLoading = false;
    });
  }

  Future<void> _loadBiliDynamics({required bool append}) async {
    if (_dynLoading) return;
    setState(() {
      _dynLoading = true;
      _dynFailed = false;
    });
    await _ensureBiliSpace();
    final page = await BiliDynamicApi.getDynamics(BiliFeedApi.mid, append ? _dynOffset : '');
    if (!mounted) return;
    setState(() {
      if (page != null) {
        if (append) {
          _dynItems.addAll(page.items);
        } else {
          _dynItems
            ..clear()
            ..addAll(page.items);
        }
        _dynOffset = page.offset;
        _dynHasMore = page.hasMore;
        _dynLoaded = true;
      } else {
        _dynFailed = true;
      }
      _dynLoading = false;
    });
  }

  void _selectPlatform(int index) {
    if (index == _platformIndex) return;
    KanoHaptics.select();
    _tabIndexCache[_platformIndex] = _filterIndex;
    setState(() {
      _platformIndex = index;
      final tabs = _tabs[_Platform.values[index]]!;
      _filterIndex = _tabIndexCache[index].clamp(0, tabs.length - 1);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _ensurePlatformData();
  }

  void _selectFilter(int index) {
    if (index == _filterIndex) return;
    KanoHaptics.select();
    setState(() {
      _filterIndex = index;
      // 切账号时先把上一个账号的帖子清掉，否则请求回来前会看到别人的内容
      if (_platform == _Platform.x) {
        _xPosts.clear();
        _xLoaded = false;
        _xFailed = false;
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _ensurePlatformData();
  }

  /// 按当前分类决定要不要拉数据：B 站两套接口各管一栏，YouTube 用 dashboard 里现成的
  void _ensurePlatformData() {
    switch (_platform) {
      case _Platform.x:
        // 账号筛选变了也要重拉（鸿蒙切筛选项就重新请求，不是只改本地筛选态）
        if (_xLoading) return;
        if (!_xLoaded || _xAccount != _tabNow.key) {
          _xWindow = 0;
          _xPage = 0;
          _xHasMore = true;
          _fetchX(append: false);
        }
      case _Platform.bilibili:
        if (_tabNow.key == 'dynamic') {
          if (!_dynLoaded && !_dynLoading) _loadBiliDynamics(append: false);
        } else {
          if (!_biliLoaded && !_biliLoading) _loadBiliFeed(append: false);
        }
      case _Platform.youtube:
        if (!_ytLoaded) _loadProfile();
    }
  }

  Future<void> _refresh() async {
    switch (_platform) {
      case _Platform.x:
        _xWindow = 0;
        _xPage = 0;
        _xHasMore = true;
        await _fetchX(append: false);
      case _Platform.bilibili:
        if (_tabNow.key == 'dynamic') {
          await _loadBiliDynamics(append: false);
        } else {
          await _loadBiliFeed(append: false);
        }
      case _Platform.youtube:
        await _loadProfile();
    }
  }

  /// 是不是一场直播：kano-navi 把「形式」和「内容」拆开了，
  /// kind 只表示 stream / premiere / upload。
  bool _isYoutubeStream(KanoVideo video) => video.kind.trim().toLowerCase() == 'stream';

  /// 等价于服务端的 videoMatchesFilter：Shorts 看 isShort 优先，其余按 kind 二分。
  List<KanoVideo> get _youtubeList {
    final key = _tabNow.key;
    final list = <KanoVideo>[];
    for (final video in _ytVideos) {
      if (video.isShort) {
        if (key == 'shorts') list.add(video);
        continue;
      }
      if (key == 'shorts') continue;
      if (_isYoutubeStream(video) == (key == 'live')) list.add(video);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = KanoPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 网格按「去掉左右内边距后的内容宽」算，不是整屏宽 ——
        // 用整屏宽会让每行比容器宽出 2×16，右边那格被裁掉一半。
        final contentWidth = constraints.maxWidth - _pagePadding * 2;
        return Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                color: palette.berry,
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    _pagePadding,
                    _headerHeight,
                    _pagePadding,
                    168,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _content(palette, contentWidth),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _headerOverlay(palette),
            ),
          ],
        );
      },
    );
  }

  /// 浮层头部：平台行 + 分类行，滚动后整块上移 56 并淡出平台行
  Widget _headerOverlay(KanoPalette palette) {
    final shift = _collapsed ? -(_platformBarHeight + 8) : 0.0;
    return Transform.translate(
      offset: Offset(0, shift),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IgnorePointer(
              ignoring: _collapsed,
              child: Opacity(
                opacity: _collapsed ? 0 : 1,
                child: SizedBox(
                  height: _platformBarHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                    itemCount: _Platform.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final platform = _Platform.values[i];
                      final active = i == _platformIndex;
                      return Center(
                        child: _Pill(
                          // HdsButton 的玻璃块：外框 56×48，绘制宽 chipWidth-4。
                          // 选中再叠 12% 的内容色，前景仍是深色，不是实心黑底白标。
                          width: _platformChipWidth - 4,
                          height: _platformBarHeight - 12,
                          active: active,
                          onTap: () => _selectPlatform(i),
                          child: KanoBrandMark(
                            kind: _platformBrand[platform]!,
                            size: _platformIconSize,
                            color: active ? palette.textPrimary : palette.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_tabsNow.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: SizedBox(
                height: _filterBarHeight - 4,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                  itemCount: _tabsNow.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tab = _tabsNow[i];
                    final label = KanoText.ui(tab.labelKey);
                    final active = i == _filterIndex;
                    return Center(
                      child: _Pill(
                        width: _chipWidthFor(label, tab.chipWidth) - 4,
                        height: _filterBarHeight - 12,
                        active: active,
                        onTap: () => _selectFilter(i),
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: active ? FontWeight.bold : FontWeight.w500,
                            color: active ? palette.textPrimary : palette.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 内容
  // ---------------------------------------------------------------------------

  List<Widget> _content(KanoPalette palette, double width) {
    switch (_platform) {
      case _Platform.x:
        return _xContent(palette);
      case _Platform.bilibili:
        return _tabNow.key == 'dynamic' ? _dynContent(palette) : _biliContent(palette, width);
      case _Platform.youtube:
        return _youtubeContent(palette, width);
    }
  }

  /// 卡片流：一个个往下堆，间距 12
  List<Widget> _xContent(KanoPalette palette) {
    final children = <Widget>[];
    if (_xPosts.isEmpty) {
      if (_xLoading) {
        return [for (var i = 0; i < 3; i++) _gapped(i, const FeedXSkeletonCard())];
      }
      if (_xFailed) return [FeedFailed(onRetry: () => _fetchX(append: false))];
      return [FeedMediaEmpty(text: KanoText.ui('feed_empty_account'))];
    }
    for (var i = 0; i < _xPosts.length; i++) {
      if (i == 0 && _xFromCache) {
        children.add(_OfflineHint(text: KanoText.ui('feed_offline_snapshot')));
      }
      children.add(KanoPostCard(post: _xPosts[i], profile: _profile, slot: i));
    }
    children.add(
      FeedMoreRow(
        hasMore: _xHasMore,
        loading: _xLoading,
        onMore: () => _fetchX(append: true),
      ),
    );
    return _spaced(children);
  }

  List<Widget> _biliContent(KanoPalette palette, double width) {
    if (_biliItems.isEmpty) {
      if (_biliLoading) return [_gridSkeleton(width, _landscapeColumns(width), false)];
      if (_biliFailed) return [FeedFailed(onRetry: () => _loadBiliFeed(append: false))];
      return [FeedMediaEmpty(text: KanoText.ui('feed_bili_empty'))];
    }
    return [
      _grid(
        cols: _landscapeColumns(width),
        width: width,
        count: _biliItems.length,
        builder: (i) => BiliVideoTile(item: _biliItems[i], slot: i),
      ),
      const SizedBox(height: 12),
      FeedMoreRow(
        hasMore: _biliHasMore,
        loading: _biliLoading,
        onMore: () => _loadBiliFeed(append: true),
      ),
    ];
  }

  List<Widget> _dynContent(KanoPalette palette) {
    if (_dynItems.isEmpty) {
      if (_dynLoading) {
        return [for (var i = 0; i < 3; i++) _gapped(i, const FeedXSkeletonCard())];
      }
      if (_dynFailed) return [FeedFailed(onRetry: () => _loadBiliDynamics(append: false))];
      return [FeedMediaEmpty(text: KanoText.ui('feed_bili_dyn_empty'))];
    }
    final children = <Widget>[
      for (var i = 0; i < _dynItems.length; i++)
        BiliDynamicCard(item: _dynItems[i], space: _biliSpace, slot: i),
      FeedMoreRow(
        hasMore: _dynHasMore,
        loading: _dynLoading,
        onMore: () => _loadBiliDynamics(append: true),
      ),
    ];
    return _spaced(children);
  }

  List<Widget> _youtubeContent(KanoPalette palette, double width) {
    if (!_ytLoaded) return [_gridSkeleton(width, _landscapeColumns(width), false)];
    if (_ytFailed) return [FeedFailed(onRetry: _loadProfile)];
    final list = _youtubeList;
    if (list.isEmpty) {
      return [
        FeedMediaEmpty(
          text: KanoText.uiFmt('feed_empty_platform', KanoText.ui(_tabNow.labelKey)),
        ),
      ];
    }
    final shorts = _tabNow.key == 'shorts';
    return [
      _grid(
        cols: shorts ? _portraitColumns(width) : _landscapeColumns(width),
        width: width,
        count: list.length,
        builder: (i) => YoutubeTile(video: list[i], slot: i),
      ),
    ];
  }

  /// 网格：每行 cols 个，缺的槽位留白（鸿蒙 `Row` + `SpaceBetween` + `tileWidth%`）。
  /// 单格宽 = (100 - 4×(cols-1)) / cols 百分比，缝正好 4%。
  Widget _grid({
    required int cols,
    required double width,
    required int count,
    required Widget Function(int index) builder,
  }) {
    final gap = width * 0.04;
    final tileWidth = (width - gap * (cols - 1)) / cols;
    final rows = <Widget>[];
    for (var start = 0; start < count; start += cols) {
      final inRow = (count - start).clamp(0, cols);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var slot = 0; slot < cols; slot++) ...[
              if (slot > 0) SizedBox(width: gap),
              if (slot < inRow)
                SizedBox(width: tileWidth, child: builder(start + slot))
              else
                SizedBox(width: tileWidth),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _gridRowGap),
          rows[i],
        ],
      ],
    );
  }

  Widget _gridSkeleton(double width, int cols, bool shorts) {
    return FeedGridSkeleton(
      cols: cols,
      tileWidth: (width - width * 0.04 * (cols - 1)) / cols,
      shorts: shorts,
    );
  }

  /// 在列表项之间插 12 的缝
  List<Widget> _spaced(List<Widget> items) {
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(height: _cardGap));
      out.add(items[i]);
    }
    return out;
  }

  Widget _gapped(int index, Widget child) {
    if (index == 0) return child;
    return Padding(padding: const EdgeInsets.only(top: _cardGap), child: child);
  }
}

/// 离线快照提示行
class _OfflineHint extends StatelessWidget {
  const _OfflineHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 11, color: palette.textTertiary)),
    );
  }
}

/// 平台/分类胶囊。对齐鸿蒙 `HdsButton`：半透明底，选中再叠 12% 内容色。
/// 不走 BackdropFilter。按压缩到 0.95（160ms EaseOut）。
class _Pill extends StatefulWidget {
  const _Pill({
    required this.width,
    required this.height,
    required this.active,
    required this.onTap,
    required this.child,
  });

  final double width;
  final double height;
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final radius = BorderRadius.circular(
      widget.height < widget.width ? widget.height / 2 : widget.width / 2,
    );
    final base = palette.isLight ? const Color(0xF2FFFFFF) : const Color(0x14FFFFFF);
    final activeWash = palette.textPrimary.withValues(alpha: 0.12);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        _set(false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.active ? Color.alphaBlend(activeWash, base) : base,
            borderRadius: radius,
            border: Border.all(color: palette.hairline, width: 1),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
