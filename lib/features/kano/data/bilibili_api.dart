import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

/// UP 主账号信息（卡片头部用）
class BiliSpaceInfo {
  const BiliSpaceInfo({
    required this.name,
    required this.face,
    required this.fans,
    required this.likes,
    this.sign = '',
    this.isVip = false,
  });
  final String name;
  final String face;
  final int fans;

  /// 获赞总数（桌面卡片的「获赞」一栏）
  final int likes;

  /// 个性签名（桌面卡片中卡昵称下面那行）
  final String sign;

  /// 大会员：卡片把昵称与粉丝数换成 B 站粉（鸿蒙 isVip 口径 vipStatus == 1）
  final bool isVip;
}

class BiliVideoItem {
  const BiliVideoItem({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.durationSec,
    required this.playText,
    required this.danmaku,
    required this.timeMs,
    required this.url,
  });

  final String bvid;
  final String title;
  final String cover;
  final int durationSec;

  /// 播放量，接口给的就是「27.9万」这种字符串
  final String playText;
  final int danmaku;
  final int timeMs;
  final String url;

  String get durationText {
    if (durationSec <= 0) return '';
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    final mm = m < 10 ? '0$m' : '$m';
    final ss = s < 10 ? '0$s' : '$s';
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

class BiliVideoPage {
  const BiliVideoPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
  });
  final List<BiliVideoItem> items;
  final int page;
  final bool hasMore;
  final int total;
}

/// 一条动态（图文 / 转发 / 纯文字都归到这里，视频投稿不进这个列表）
/// 动态正文的一个片段。
///
/// B 站把表情当成**独立节点**放在 `rich_text_nodes` 里，同时把 `[xxx]` 这种
/// 占位符留在 `text` 字段里。只读 `text` 就只剩一堆方括号，所以正文要按节点
/// 拼：文字节点直接排，表情节点换成图。
class BiliRichNode {
  const BiliRichNode.text(this.text) : imageUrl = '', large = false;

  const BiliRichNode.emotion({
    required this.text,
    required this.imageUrl,
    required this.large,
  });

  /// 文字内容；表情节点上是它的 alt 文本（图挂了时用来兜底）
  final String text;

  /// 非空表示这是一枚表情图
  final String imageUrl;

  /// B 站 `emoticon.size == 2` 的大表情
  final bool large;

  bool get isEmotion => imageUrl.isNotEmpty;
}

class BiliDynamicItem {
  const BiliDynamicItem({
    required this.id,
    required this.type,
    required this.text,
    required this.title,
    required this.pics,
    required this.picRatio,
    required this.timeMs,
    required this.url,
    required this.like,
    required this.comment,
    required this.forward,
    required this.quoteText,
    required this.quoteAuthor,
    required this.quotePics,
    required this.isForward,
    required this.nodes,
    required this.quoteNodes,
  });

  final String id;
  final String type;

  /// 正文（转发时是转发语）
  final String text;

  /// 正文的富文本节点：含表情图时优先按它渲染，为空才退回 [text]
  final List<BiliRichNode> nodes;

  /// 转发原文的富文本节点
  final List<BiliRichNode> quoteNodes;

  /// opus 标题，多数为空
  final String title;

  /// 配图，已按展示尺寸加过缩放后缀
  final List<String> pics;

  /// 首图宽高比，单图时按它撑开（夹在 0.6~1.8，免得长图占满一屏）
  final double picRatio;
  final int timeMs;
  final String url;
  final int like;
  final int comment;
  final int forward;
  final String quoteText;
  final String quoteAuthor;
  final List<String> quotePics;
  final bool isForward;
}

class BiliDynamicPage {
  const BiliDynamicPage({required this.items, required this.offset, required this.hasMore});
  final List<BiliDynamicItem> items;

  /// 下一页游标，空串表示到底了
  final String offset;
  final bool hasMore;
}

/// UP 主空间投稿列表 + 账号信息。
///
/// 为什么走 `app.bilibili.com` 而不是 `api.bilibili.com`：
/// web 那套空间接口要 buvid 指纹 + wbi 签名，且对没有历史 Cookie 的新客户端直接回 412。
/// app 这套走 appkey+sign，不依赖 Cookie，分页按 pn 走，实测稳定。
class BiliFeedApi {
  BiliFeedApi._();

  static const _api = 'https://app.bilibili.com';
  static const _appkey = '1d8b6e7d45233436';
  static const _appsecret = '560c52ccd288fed045859ed18bffd973';
  static const _ua = 'Mozilla/5.0 BiliDroid/7.30.0 (bbcallen@gmail.com) os/android';

  /// 鹿乃的 B 站 mid，与鸿蒙版 `FeedPage.ets` 的 `BILI_MID` 一致。
  static const mid = '316381099';

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: const {
        'User-Agent': _ua,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.bilibili.com/',
      },
    ),
  );

  static BiliSpaceInfo? _spaceInfo;

  /// 参数按 key 升序拼串 → 补 appkey/ts → 拼 appsecret 求 MD5
  static String _signed(Map<String, String> params) {
    final merged = <String, String>{
      ...params,
      'appkey': _appkey,
      'ts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'mobi_app': 'android',
      'platform': 'android',
      'build': '7300000',
    };
    final keys = merged.keys.toList()..sort();
    final base = keys.map((k) => '$k=${merged[k] ?? ''}').join('&');
    // 签名口径：md5(排序后的 query + appsecret)
    final sign = crypto.md5.convert(utf8.encode('$base$_appsecret')).toString();
    return '$base&sign=$sign';
  }

  static Future<String> _get(String url) async {
    try {
      final res = await _dio.get<String>(url);
      return (res.statusCode == 200) ? (res.data ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  /// 图片统一升 https，并按 B 站自己的规则加缩放后缀
  static String imageUrl(String value, String style) {
    final url = value.replaceFirst(RegExp(r'^//'), 'https://').replaceFirst(RegExp(r'^http://'), 'https://');
    if (url.isEmpty || style.isEmpty) return url;
    return '$url@$style';
  }

  static String _playText(Map<dynamic, dynamic> raw) {
    final view = (raw['view_content'] ?? '').toString();
    if (view.isNotEmpty) return view;
    final play = (raw['play'] is num) ? (raw['play'] as num).toInt() : int.tryParse('${raw['play']}') ?? 0;
    if (play >= 10000) {
      final wan = play / 10000;
      return wan >= 10 ? '${wan.round()}万' : '${wan.toStringAsFixed(1)}万';
    }
    return '$play';
  }

  static BiliSpaceInfo? _parseSpace(String body) {
    if (body.isEmpty) return null;
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return null;
      final code = raw['code'];
      if (code != null && code != 0) return null;
      final data = raw['data'];
      if (data is! Map) return null;
      final card = data['card'];
      if (card is! Map) return null;
      final face = (card['face'] ?? '').toString();
      return BiliSpaceInfo(
        name: (card['name'] ?? '').toString(),
        face: face.isEmpty ? '' : imageUrl(face, '120w_120h_1c.webp'),
        fans: int.tryParse('${card['fans']}') ?? 0,
        likes: int.tryParse('${card['like_num']}') ?? 0,
        sign: (card['sign'] ?? '').toString(),
        isVip: _vipStatus(card['vip']) == 1,
      );
    } catch (_) {
      return null;
    }
  }

  /// 大会员状态：接口在不同端点上给 `vip.vipStatus`，缺字段按非会员处理
  static int _vipStatus(Object? vip) {
    if (vip is! Map) return 0;
    return int.tryParse('${vip['vipStatus']}') ?? 0;
  }

  static BiliVideoPage? _parseArchive(String body, int page, int pageSize) {
    if (body.isEmpty) return null;
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return null;
      final code = raw['code'];
      if (code != null && code != 0) return null;
      final data = raw['data'];
      if (data is! Map) return null;
      final total = int.tryParse('${data['count']}') ?? 0;
      final list = data['item'];
      final items = <BiliVideoItem>[];
      if (list is List) {
        for (final one in list) {
          if (one is! Map) continue;
          final bvid = (one['bvid'] ?? '').toString();
          if (bvid.isEmpty) continue;
          final cover = (one['cover'] ?? '').toString();
          items.add(BiliVideoItem(
            bvid: bvid,
            title: (one['title'] ?? '').toString(),
            cover: cover.isEmpty ? '' : imageUrl(cover, '640w_360h_1c.webp'),
            durationSec: int.tryParse('${one['duration']}') ?? 0,
            playText: _playText(one),
            danmaku: int.tryParse('${one['danmaku']}') ?? 0,
            timeMs: (int.tryParse('${one['ctime']}') ?? 0) * 1000,
            url: 'https://www.bilibili.com/video/$bvid',
          ));
        }
      }
      return BiliVideoPage(
        items: items,
        page: page,
        total: total,
        hasMore: items.isNotEmpty && page * pageSize < total,
      );
    } catch (_) {
      return null;
    }
  }

  /// UP 主账号信息：只在第一次进 B 站平台时取一次，之后走内存缓存。
  static Future<BiliSpaceInfo?> getSpaceInfo() async {
    final cached = _spaceInfo;
    if (cached != null) return cached;
    final body = await _get('$_api/x/v2/space?${_signed({'vmid': mid})}');
    final info = _parseSpace(body);
    if (info != null) _spaceInfo = info;
    return info;
  }

  /// 投稿列表（按发布时间倒序）。返回 null 表示请求失败，空列表才是「确实没有投稿」。
  static Future<BiliVideoPage?> getVideos(int page, {int pageSize = 12}) async {
    final body = await _get(
      '$_api/x/v2/space/archive?${_signed({
            'vmid': mid,
            'pn': '$page',
            'ps': '$pageSize',
            'order': 'pubdate',
          })}',
    );
    return _parseArchive(body, page, pageSize);
  }
}

/// B 站动态流（图文 / 转发 / 专栏）。
///
/// web 这套接口要求三样东西，少一样就 412 或空列表：
/// 1. `buvid3` Cookie —— 没有设备指纹直接 412（返回 HTML 错误页）
/// 2. wbi 签名 —— 缺了回 -352；密钥从 nav 接口的两个图片名拼出来，每 6 小时换一次
/// 3. `features` 参数 —— 不带就「正常」返回 code 0 但 items 是空的
///
/// 还有一条实测坑：同一指纹 1 秒内连发两次，第二次起返回空 items（不报错）。
/// 所以请求之间至少隔 1100ms，首页空列表时等一会儿重试。
class BiliDynamicApi {
  BiliDynamicApi._();

  static const _api = 'https://api.bilibili.com';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  /// B 站前端 JS 里写死的置换表，用来把两个 wbi 密钥文件名拼成 mixinKey。
  /// 顺序不能动 —— 这是「混洗」的语义，改一个字符签名就全错。
  static const _mixinTab = <int>[
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
    36, 20, 34, 44, 52
  ];

  /// 要新版 opus 结构就必须带这串；少一个字段都可能退化成空列表。
  static const _features =
      'itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,forwardListHidden,decorationCard,'
      'commentsNewVersion,onlyfansAssetsV2,ugcDelete,onlyfansQaCard';

  /// 两条请求之间的最小间隔：同指纹连发会被静默限流成空列表。
  static const _minGapMs = 1100;

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: const {
        'User-Agent': _ua,
        'Accept': 'application/json, text/plain, */*',
      },
    ),
  );

  static String _buvid = '';
  static String _mixinKey = '';
  static int _mixinAtMs = 0;
  static int _lastRequestMs = 0;
  static Future<void> _queue = Future<void>.value();

  static Future<void> _sleep(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  static Future<void> _waitGap() async {
    final gap = DateTime.now().millisecondsSinceEpoch - _lastRequestMs;
    if (_lastRequestMs > 0 && gap < _minGapMs) {
      await _sleep(_minGapMs - gap);
    }
    _lastRequestMs = DateTime.now().millisecondsSinceEpoch;
  }

  static Future<String> _get(String url, String cookie, String referer) async {
    await _waitGap();
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(headers: {
          'Referer': referer,
          if (cookie.isNotEmpty) 'Cookie': cookie,
        }),
      );
      return (res.statusCode == 200) ? (res.data ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  /// 设备指纹：拿一次就留着。
  static Future<String> _ensureBuvid() async {
    if (_buvid.isNotEmpty) return _buvid;
    final body = await _get('$_api/x/frontend/finger/spi', '', 'https://www.bilibili.com/');
    if (body.isEmpty) return '';
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return '';
      if (raw['code'] != 0) return '';
      final data = raw['data'];
      if (data is! Map) return '';
      final b3 = (data['b_3'] ?? '').toString();
      if (b3.isEmpty) return '';
      _buvid = b3;
      return _buvid;
    } catch (_) {
      return '';
    }
  }

  /// wbi 密钥：img_url + sub_url 各取文件名拼起来，再按置换表混洗取前 32 位。
  static Future<String> _ensureMixinKey() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 官方每 6 小时轮换一次，取短一点（4 小时）更稳
    if (_mixinKey.isNotEmpty && now - _mixinAtMs < 4 * 3600 * 1000) return _mixinKey;
    final buvid = await _ensureBuvid();
    final body = await _get(
      '$_api/x/web-interface/nav',
      buvid.isEmpty ? '' : 'buvid3=$buvid',
      'https://www.bilibili.com/',
    );
    if (body.isEmpty) return _mixinKey;
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return _mixinKey;
      final data = raw['data'];
      if (data is! Map) return _mixinKey;
      final img = data['wbi_img'];
      if (img is! Map) return _mixinKey;
      final imgUrl = (img['img_url'] ?? '').toString();
      final subUrl = (img['sub_url'] ?? '').toString();
      if (imgUrl.isEmpty || subUrl.isEmpty) return _mixinKey;
      String nameOf(String url) {
        final last = url.substring(url.lastIndexOf('/') + 1);
        return last.split('.').first;
      }

      final merged = '${nameOf(imgUrl)}${nameOf(subUrl)}';
      final buf = StringBuffer();
      for (final index in _mixinTab) {
        if (index < merged.length) buf.write(merged[index]);
      }
      final key = buf.toString();
      _mixinKey = key.length > 32 ? key.substring(0, 32) : key;
      _mixinAtMs = now;
      return _mixinKey;
    } catch (_) {
      return _mixinKey;
    }
  }

  /// wbi 签名：参数按 key 升序，值里剔除 `!'()*` 后 urlencode 拼串，
  /// 末尾接 mixinKey 求 MD5 得 w_rid。wts 是必带的时间戳。
  static String _sign(Map<String, String> params) {
    final merged = <String, String>{
      ...params,
      'wts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    };
    final keys = merged.keys.toList()..sort();
    final pairs = keys.map((k) {
      final value = (merged[k] ?? '').replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(value)}';
    }).join('&');
    final rid = crypto.md5.convert(utf8.encode('$pairs$_mixinKey')).toString();
    return '$pairs&w_rid=$rid';
  }

  /// B 站图片统一走 https，并按展示尺寸加 BFS 缩放后缀；要原图就把后缀摘掉。
  static String thumb(String url, String style) {
    if (url.isEmpty) return '';
    final clean = url
        .split('?')
        .first
        .replaceFirst(RegExp(r'^//'), 'https://')
        .replaceFirst(RegExp(r'^http://'), 'https://');
    if (style.isEmpty) return clean;
    return '$clean@$style';
  }

  /// 大图预览用：把 `@xxx.webp` 这类缩放后缀摘掉，回到原图。
  static String originalOf(String url) {
    if (url.isEmpty) return '';
    final index = url.lastIndexOf('@');
    return index > 0 ? url.substring(0, index) : url;
  }

  static String _absUrl(String raw, String idStr) {
    if (raw.isNotEmpty) {
      final withScheme = raw.replaceFirst(RegExp(r'^//'), 'https://');
      return withScheme.startsWith('http') ? withScheme : 'https://www.bilibili.com/$raw';
    }
    return idStr.isEmpty ? '' : 'https://www.bilibili.com/opus/$idStr';
  }

  static List<String> _picsOf(Object? pics) {
    if (pics is! List) return const [];
    final list = <String>[];
    for (final one in pics) {
      if (one is! Map) continue;
      final url = (one['url'] ?? '').toString();
      if (url.isEmpty) continue;
      list.add(thumb(url, '640w_640h_1c.webp'));
    }
    return list;
  }

  /// 正文优先取 `opus.summary`，老结构退回 `desc.text`（图文动态 desc 是空的）。
  static String _textOf(Object? dynamic) {
    if (dynamic is! Map) return '';
    final major = dynamic['major'];
    if (major is Map) {
      final opus = major['opus'];
      if (opus is Map) {
        final summary = opus['summary'];
        if (summary is Map) {
          final text = (summary['text'] ?? '').toString();
          if (text.isNotEmpty) return text;
        }
      }
    }
    final desc = dynamic['desc'];
    if (desc is Map) return (desc['text'] ?? '').toString();
    return '';
  }

  /// 正文的富文本节点。表情在 `rich_text_nodes` 里是独立节点，
  /// `text` 字段只留 `[xxx]` 占位，所以渲染必须走这一份。
  ///
  /// 新结构在 `major.opus.summary.rich_text_nodes`，老结构在 `desc.rich_text_nodes`；
  /// 两边都空时返回空列表，交给调用方退回纯文本。
  ///
  /// 公开是为了让测试能直接喂真实响应片段 —— 这套字段是 B 站的非公开接口，
  /// 哪天改名了，测试会先挂，而不是等用户看到一屏方括号。
  static List<BiliRichNode> richNodesOf(Object? node) {
    if (node is! Map) return const [];
    List<Object?>? raw;
    final major = node['major'];
    if (major is Map) {
      final opus = major['opus'];
      if (opus is Map) {
        final summary = opus['summary'];
        if (summary is Map) {
          final nodes = summary['rich_text_nodes'];
          if (nodes is List && nodes.isNotEmpty) raw = nodes;
        }
      }
    }
    if (raw == null) {
      final desc = node['desc'];
      if (desc is Map) {
        final nodes = desc['rich_text_nodes'];
        if (nodes is List && nodes.isNotEmpty) raw = nodes;
      }
    }
    if (raw == null) return const [];

    final out = <BiliRichNode>[];
    for (final one in raw) {
      if (one is! Map) continue;
      final type = (one['type'] ?? '').toString();
      final text = (one['text'] ?? '').toString();
      // 新版 opus 用 EMOJI（图在 `emoji`），老结构用 EMOTION（图在 `emoticon`）。
      // 两个都认，别只写文档里那个 —— 实测现在返回的全是 EMOJI。
      if (type == 'RICH_TEXT_NODE_TYPE_EMOJI' || type == 'RICH_TEXT_NODE_TYPE_EMOTION') {
        final emoji = one['emoji'];
        final emoticon = one['emoticon'];
        final meta = emoji is Map ? emoji : (emoticon is Map ? emoticon : null);
        if (meta != null) {
          // 三个地址各有分工：gif_url 是动图，icon_url 是静态首帧，webp_url 是静图。
          // 优先动图（B 站原版就是动的），普通小黄脸只有 icon_url，所以必须能回退 ——
          // 只认 gif_url 会让一大半表情变成 `[xxx]` 占位。
          final url = _firstUrlIn(meta, const ['gif_url', 'icon_url', 'url']);
          final alt = text.isNotEmpty ? text : (meta['text'] ?? '').toString();
          if (url.isNotEmpty) {
            out.add(BiliRichNode.emotion(
              text: alt.isEmpty ? '[表情]' : alt,
              imageUrl: url.startsWith('//') ? 'https:$url' : url,
              // size 在 JSON 里是数字 2，但也见过字符串，统一按字符串比
              large: '${meta['size']}' == '2',
            ));
            continue;
          }
        }
        // 拿不到图就退化成占位文字，总比丢字好
      }
      if (text.isNotEmpty) out.add(BiliRichNode.text(text));
    }
    return List<BiliRichNode>.unmodifiable(out);
  }

  /// 按顺序取第一个非空字段。B 站同一枚表情同时给 gif / png / webp 三份地址，
  /// 字段缺失时是空串而不是 null，所以不能只看 key 在不在。
  static String _firstUrlIn(Map meta, List<String> keys) {
    for (final key in keys) {
      final value = (meta[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static List<String> _picsFrom(Object? dynamic) {
    if (dynamic is! Map) return const [];
    final major = dynamic['major'];
    if (major is! Map) return const [];
    final opus = major['opus'];
    if (opus is Map) {
      final pics = opus['pics'];
      if (pics is List && pics.isNotEmpty) return _picsOf(pics);
    }
    final draw = major['draw'];
    if (draw is Map) {
      final items = draw['items'];
      if (items is List && items.isNotEmpty) return _picsOf(items);
    }
    return const [];
  }

  static BiliDynamicItem _parseItem(Map<dynamic, dynamic> raw) {
    final modules = raw['modules'];
    final modulesMap = modules is Map ? modules : const {};
    final dynamic = modulesMap['module_dynamic'];
    final author = modulesMap['module_author'];
    final authorMap = author is Map ? author : const {};

    var text = _textOf(dynamic);
    var nodes = richNodesOf(dynamic);
    var title = '';
    if (dynamic is Map) {
      final major = dynamic['major'];
      if (major is Map) {
        final opus = major['opus'];
        if (opus is Map) title = (opus['title'] ?? '').toString();
      }
    }
    var pics = _picsFrom(dynamic);
    var picRatio = 4 / 3;
    if (dynamic is Map) {
      final major = dynamic['major'];
      if (major is Map) {
        final opus = major['opus'];
        if (opus is Map) {
          final rawPics = opus['pics'];
          if (rawPics is List && rawPics.isNotEmpty && rawPics.first is Map) {
            final first = rawPics.first as Map;
            final w = int.tryParse('${first['width']}') ?? 0;
            final h = int.tryParse('${first['height']}') ?? 0;
            if (w > 0 && h > 0) picRatio = (w / h).clamp(0.6, 1.8);
          }
        }
      }
    }

    final basic = raw['basic'];
    final basicMap = basic is Map ? basic : const {};
    final idStr = (raw['id_str'] ?? '').toString();
    final url = _absUrl((basicMap['jump_url'] ?? '').toString(), idStr);

    var like = 0, comment = 0, forward = 0;
    final stat = modulesMap['module_stat'];
    if (stat is Map) {
      int countOf(String key) {
        final one = stat[key];
        if (one is Map) return int.tryParse('${one['count']}') ?? 0;
        return 0;
      }

      like = countOf('like');
      comment = countOf('comment');
      forward = countOf('forward');
    }

    var quoteText = '';
    var quoteNodes = const <BiliRichNode>[];
    var quoteAuthor = '';
    var quotePics = const <String>[];
    final isForward = raw['orig'] != null;
    if (raw['orig'] is Map) {
      final orig = raw['orig'] as Map;
      final origModules = orig['modules'];
      final origModulesMap = origModules is Map ? origModules : const {};
      final origDynamic = origModulesMap['module_dynamic'];
      final origAuthor = origModulesMap['module_author'];
      quoteText = _textOf(origDynamic);
      quoteNodes = richNodesOf(origDynamic);
      if (origAuthor is Map) quoteAuthor = (origAuthor['name'] ?? '').toString();
      quotePics = _picsFrom(origDynamic);
      // 转发时顶层常常是空的（只有转发语），图要退到原帖上，否则整张卡是空白
      if (pics.isEmpty) pics = quotePics;
      if (text.isEmpty && quoteText.isNotEmpty) {
        text = quoteText;
        // 正文退到原帖时，富文本也得跟着退，否则表情又变回方括号
        if (nodes.isEmpty) nodes = quoteNodes;
      }
    }

    return BiliDynamicItem(
      id: idStr,
      type: (raw['type'] ?? '').toString(),
      text: text,
      title: title,
      pics: pics,
      picRatio: picRatio,
      timeMs: (int.tryParse('${authorMap['pub_ts']}') ?? 0) * 1000,
      url: url,
      like: like,
      comment: comment,
      forward: forward,
      quoteText: quoteText,
      quoteAuthor: quoteAuthor,
      quotePics: quotePics,
      isForward: isForward,
      nodes: nodes,
      quoteNodes: quoteNodes,
    );
  }

  static BiliDynamicPage? _parsePage(String body) {
    if (body.isEmpty) return null;
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return null;
      final code = raw['code'];
      if (code != null && code != 0) return null;
      final data = raw['data'];
      final page = <BiliDynamicItem>[];
      var hasMore = false;
      var offset = '';
      if (data is Map) {
        final list = data['items'];
        if (list is List) {
          for (final one in list) {
            if (one is! Map) continue;
            final type = (one['type'] ?? '').toString();
            // 视频投稿在「视频」那一栏单独展示；装扮 / 商品这类纯广告卡没有正文也没有图，留着只是噪音
            if (type == 'DYNAMIC_TYPE_AV' || type == 'DYNAMIC_TYPE_COMMON_SQUARE') continue;
            final item = _parseItem(one);
            if (item.text.isEmpty && item.pics.isEmpty) continue;
            page.add(item);
          }
        }
        hasMore = data['has_more'] == true;
        offset = hasMore ? (data['offset'] ?? '').toString() : '';
      }
      return BiliDynamicPage(items: page, offset: offset, hasMore: hasMore);
    } catch (_) {
      return null;
    }
  }

  static Future<BiliDynamicPage?> _fetchPage(String mid, String offset) async {
    final buvid = await _ensureBuvid();
    final key = await _ensureMixinKey();
    if (key.isEmpty) return null;
    final params = <String, String>{
      'host_mid': mid,
      'timezone_offset': '-480',
      'platform': 'web',
      'features': _features,
      'web_location': '333.1387',
      if (offset.isNotEmpty) 'offset': offset,
    };
    final url = '$_api/x/polymer/web-dynamic/v1/feed/space?${_sign(params)}';
    final cookie = buvid.isEmpty ? '' : 'buvid3=$buvid';
    final body = await _get(url, cookie, 'https://space.bilibili.com/$mid/dynamic');
    return _parsePage(body);
  }

  /// 动态列表。offset 传空串拿第一页。
  /// 返回 null 才是「真的失败」；空列表表示这段时间确实没有图文动态。
  static Future<BiliDynamicPage?> getDynamics(String mid, String offset) async {
    if (mid.isEmpty) return null;
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    await previous;
    try {
      var page = await _fetchPage(mid, offset);
      // 空列表有两种可能：真的没有动态，或者被静默限流了（不报错，直接给空 + has_more=false）。
      // 两次都空才认账 —— 否则翻到一半会被误判成「已经到底了」。
      var retry = 0;
      while (page != null && page.items.isEmpty && !page.hasMore && retry < 2) {
        retry++;
        await _sleep(900 + retry * 400);
        page = await _fetchPage(mid, offset);
      }
      if (offset.isEmpty && page != null && !page.hasMore && page.items.length < 5) {
        await _sleep(900);
        final again = await _fetchPage(mid, offset);
        if (again != null && again.items.length > page.items.length) page = again;
      }
      // 整页都是视频投稿 / 装扮卡被过滤掉了，但后面还有内容：不往后走这一页会渲染成「没有动态」
      var guard = 0;
      while (page != null && page.items.isEmpty && page.hasMore && page.offset.isNotEmpty && guard < 2) {
        guard++;
        page = await _fetchPage(mid, page.offset);
      }
      return page;
    } finally {
      completer.complete();
    }
  }
}
