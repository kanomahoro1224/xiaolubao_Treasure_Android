import 'kano_server.dart';
import 'kano_text.dart';
import 'kano_time.dart';

/// JSON 取值助手：服务端字段全是可空的，缺项一律退回默认值。
String _str(Object? v) => v == null ? '' : v.toString();

int _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return num.tryParse(v.toString())?.toInt() ?? 0;
}

bool _bool(Object? v) => v == true;

Map<String, dynamic> _obj(Object? v) =>
    v is Map ? v.map((k, value) => MapEntry(k.toString(), value)) : const <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => _obj(e)).toList(growable: false) : const [];

/// 日历摘要的类型。存的是语言无关的 key，显示文本与配色都按 key 查 ——
/// 一旦把中文当 key，切到日语界面配色就会全部失配。
class KanoKind {
  KanoKind._();
  static const song = 'song';
  static const game = 'game';
  static const talk = 'talk';
  static const video = 'video';
  static const live = 'live';

  /// 仅用于视频卡：Shorts 是形式，服务端的标签值域里没有它。
  static const short = 'short';

  static const all = <String>[song, game, talk, live, video];

  static bool isKindTag(String tag) => all.contains(tag);

  static String label(String kind) => KanoText.ui('kind_$kind');

  /// 配色：日程胶囊与视频卡共用一套（与鸿蒙 `kindColor` 一致）。
  static int colorValue(String kind) => switch (kind) {
        song => 0xFFD6336C,
        game => 0xFF5F3DC4,
        talk => 0xFF099268,
        live => 0xFFC2410C,
        video => 0xFF1971C2,
        short => 0xFF0C8599,
        _ => 0xFF495057,
      };
}

class KanoMedia {
  const KanoMedia({
    required this.url,
    required this.width,
    required this.height,
    required this.alt,
    required this.ready,
  });

  factory KanoMedia.fromJson(Map<String, dynamic> json) => KanoMedia(
        url: KanoServer.absolute(_str(json['url'])),
        width: _num(json['width']),
        height: _num(json['height']),
        alt: _str(json['alt']),
        ready: _str(json['status']).isEmpty || _str(json['status']) == 'ready',
      );

  final String url;
  final int width;
  final int height;
  final String alt;
  final bool ready;

  /// 宽/高；缺失时退回 16:9（1.6），卡片用它决定配图比例。
  double get ratio => (width > 0 && height > 0) ? width / height : 1.6;
}

class KanoQuote {
  const KanoQuote({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.text,
    required this.timeMs,
    required this.url,
    required this.media,
    required this.unavailable,
  });

  factory KanoQuote.fromJson(Map<String, dynamic> json) => KanoQuote(
        id: _str(json['id']),
        authorName: _str(json['authorName']),
        authorHandle: _str(json['authorHandle']),
        text: _str(json['text']),
        timeMs: KanoTime.parseIso(_str(json['publishedAt'])),
        url: _str(json['url']),
        unavailable: _bool(json['unavailable']),
        media: _list(json['media']).map(KanoMedia.fromJson).toList(growable: false),
      );

  final String id;
  final String authorName;
  final String authorHandle;
  final String text;
  final int timeMs;
  final String url;
  final List<KanoMedia> media;
  final bool unavailable;
}

/// 转推的原帖作者；正文、图片、翻译都还挂在外层 KanoPost 上。
class KanoRepost {
  const KanoRepost({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.avatarUrl,
    required this.timeMs,
    required this.url,
  });

  factory KanoRepost.fromJson(Map<String, dynamic> json) => KanoRepost(
        id: _str(json['id']),
        authorName: _str(json['authorName']),
        authorHandle: _str(json['authorHandle']),
        avatarUrl: KanoServer.absolute(_str(json['authorAvatar'])),
        timeMs: KanoTime.parseIso(_str(json['publishedAt'])),
        url: _str(json['url']),
      );

  final String id;
  final String authorName;
  final String authorHandle;
  final String avatarUrl;
  final int timeMs;
  final String url;
}

class _PickedText {
  const _PickedText(this.text, this.translated);
  final String text;
  final bool translated;
}

/// App 语言优先的取译文口径：缺当前语言、或译文与原文一模一样时都退回原文，
/// 并告诉调用方「这条到底是译文还是原文」——卡片底下那个「显示原文」只在是译文时出现。
_PickedText _pickTranslation(Map<String, dynamic> table, String original) {
  if (table.isEmpty) return _PickedText(original, false);
  final want = KanoText.preferredLang;
  final key = want == 'zh-Hant' ? 'zh-CN' : want;
  final direct = _obj(table[key]);
  final text = _str(direct['text']);
  if (text.isNotEmpty && text != original) return _PickedText(text, true);
  return _PickedText(original, false);
}

class KanoPost {
  const KanoPost({
    required this.id,
    required this.type,
    required this.label,
    required this.handle,
    required this.accountUrl,
    required this.source,
    required this.text,
    required this.originalText,
    required this.timeMs,
    required this.media,
    required this.quote,
    required this.repost,
    required this.url,
    required this.translated,
    required this.likes,
    required this.replies,
    required this.reposts,
  });

  factory KanoPost.fromJson(Map<String, dynamic> json) {
    final original = _str(json['text']);
    final picked = _pickTranslation(_obj(json['translations']), original);
    final quoteJson = json['quote'];
    final repostJson = json['repost'];
    return KanoPost(
      id: _str(json['id']),
      type: _str(json['type']),
      label: _str(json['label']),
      handle: _str(json['accountHandle']),
      accountUrl: _str(json['accountUrl']),
      source: _str(json['source']),
      text: picked.text,
      originalText: original,
      timeMs: KanoTime.parseIso(_str(json['publishedAt'])),
      url: _str(json['url']),
      quote: quoteJson is Map ? KanoQuote.fromJson(_obj(quoteJson)) : null,
      repost: repostJson is Map ? KanoRepost.fromJson(_obj(repostJson)) : null,
      media: _list(json['media']).map(KanoMedia.fromJson).toList(growable: false),
      translated: picked.translated,
      // 服务端有、鸿蒙客户端没解析的三项互动数
      likes: _num(json['likes']),
      replies: _num(json['replies']),
      reposts: _num(json['reposts']),
    );
  }

  final String id;
  final String type;
  final String label;
  final String handle;
  final String accountUrl;
  final String source;
  final String text;
  final String originalText;
  final int timeMs;
  final List<KanoMedia> media;
  final KanoQuote? quote;
  final KanoRepost? repost;
  final String url;
  final bool translated;
  final int likes;
  final int replies;
  final int reposts;

  String get timeText => KanoTime.relativeTime(timeMs);

  bool get hasCounts => likes > 0 || replies > 0 || reposts > 0;
}

class KanoEvent {
  const KanoEvent({
    required this.id,
    required this.title,
    required this.detail,
    required this.eventType,
    required this.source,
    required this.startsOn,
    required this.timeMs,
    required this.endsAtMs,
    required this.approximate,
    required this.status,
    required this.liveStatus,
    required this.confirmed,
    required this.cancelled,
    required this.cancellationStatus,
    required this.cancellationReason,
    required this.cancellationEvidence,
    required this.url,
    required this.translated,
    required this.tag,
  });

  factory KanoEvent.fromJson(Map<String, dynamic> json) {
    final picked = _pickTranslation(_obj(json['translations']), _str(json['title']));
    return KanoEvent(
      id: _str(json['id']),
      title: picked.text,
      translated: picked.translated,
      detail: _str(json['detail']),
      eventType: _str(json['eventType']).isEmpty ? 'stream' : _str(json['eventType']),
      source: _str(json['source']),
      startsOn: _str(json['startsOn']),
      timeMs: KanoTime.parseIso(_str(json['startsAt'])),
      endsAtMs: KanoTime.parseIso(_str(json['endsAt'])),
      approximate: (_str(json['timePrecision']).isEmpty ? 'exact' : _str(json['timePrecision'])) != 'exact',
      status: _str(json['status']),
      liveStatus: _str(json['liveStatus']),
      confirmed: (_str(json['provenance']).isEmpty ? 'automatic' : _str(json['provenance'])) != 'automatic',
      cancelled: (_str(json['cancellationStatus']).isEmpty ? 'none' : _str(json['cancellationStatus'])) != 'none',
      cancellationStatus: _str(json['cancellationStatus']).isEmpty ? 'none' : _str(json['cancellationStatus']),
      cancellationReason: _str(json['cancellationReason']),
      cancellationEvidence: _str(json['cancellationEvidence']),
      url: _str(json['url']),
      tag: _str(json['tag']),
    );
  }

  final String id;
  final String title;
  final String detail;
  final String eventType;
  final String source;
  final String startsOn;
  final int timeMs;
  final int endsAtMs;
  final bool approximate;
  final String status;
  final String liveStatus;

  /// automatic = 自动识别，confirmed/manual = 已确认
  final bool confirmed;
  final bool cancelled;

  /// none / llm_suspected / manual_confirmed
  final String cancellationStatus;
  final String cancellationReason;
  final String cancellationEvidence;
  final String url;
  final bool translated;

  /// 后台打的标签，空串表示没打，按标题猜
  final String tag;

  /// 日历数字下面那枚摘要胶囊的类型 key。
  String kind() {
    // 后台打过标签就以标签为准，运营比标题更清楚这场是什么内容
    if (KanoKind.isKindTag(tag)) return tag;
    final hay = '$title $detail'.toLowerCase();
    if (eventType == 'release') return KanoKind.video;
    if (RegExp(r'歌枠|歌ってみた|うた|karaoke|cover|song|sing').hasMatch(hay)) return KanoKind.song;
    if (RegExp(r'雑談|free talk|talk|chat|しゅみ').hasMatch(hay)) return KanoKind.talk;
    if (RegExp(r'game|playing|playthrough|rank match|apex|valorant|minecraft|フォートナイト|マインクラフト|ゲーム')
        .hasMatch(hay)) {
      return KanoKind.game;
    }
    return KanoKind.live;
  }

  String kindLabel() => KanoKind.label(kind());

  /// JST 口径，approximate 的事件前面挂「约」。
  String timeText() {
    if (timeMs <= 0) return KanoText.ui('time_tbd');
    final end = endsAtMs > 0 ? ' ~ ${KanoTime.jstText(endsAtMs)}' : '';
    final head = approximate
        ? KanoText.uiFmt('approximate', KanoTime.jstText(timeMs))
        : KanoTime.jstText(timeMs);
    return '$head$end JST';
  }

  String localTimeText() =>
      timeMs > 0 ? KanoText.uiFmt('local_time', KanoTime.localText(timeMs)) : '';

  /// 与官网 eventStatus 同一口径：确认过的状态优先，其次按起止时间推。
  String statusText() {
    if (cancelled) return KanoText.ui('status_cancelled');
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStream = eventType == 'stream' || eventType == 'member';
    if (liveStatus == 'live' && !(endsAtMs > 0 && endsAtMs <= now)) {
      return KanoText.ui('status_live');
    }
    if (liveStatus != 'ended' &&
        timeMs > 0 &&
        timeMs <= now &&
        ((endsAtMs > 0 && endsAtMs > now) ||
            (endsAtMs <= 0 && isStream && timeMs > now - 3 * 3600000))) {
      return KanoText.ui('status_live');
    }
    if (liveStatus == 'upcoming') return KanoText.ui('status_scheduled');
    final upcoming = timeMs > 0
        ? timeMs >= now
        : startsOn.isNotEmpty && startsOn.compareTo(KanoTime.dayKeyOfMs(now)) >= 0;
    if (upcoming) return KanoText.ui('status_scheduled');
    if (timeMs <= 0) return KanoText.ui('time_tbd');
    if (eventType == 'release') return KanoText.ui('status_released');
    return KanoText.ui('status_ended');
  }

  String provenanceText() =>
      confirmed ? KanoText.ui('provenance_confirmed') : KanoText.ui('provenance_auto');

  /// 取消说明：疑似取消要先亮明这是 LLM 的判断，人工确认的则以原因为主。
  String cancelNote() {
    final parts = <String>[];
    if (cancellationStatus == 'llm_suspected') {
      parts.add(KanoText.ui('cancel_review'));
      if (cancellationReason.isNotEmpty) parts.add(cancellationReason);
    } else if (cancellationStatus == 'manual_confirmed') {
      parts.add(cancellationReason.isEmpty ? KanoText.ui('cancel_manual') : cancellationReason);
    } else {
      return '';
    }
    if (cancellationEvidence.isNotEmpty) parts.add(cancellationEvidence);
    return parts.join(' · ');
  }
}

class KanoVideo {
  const KanoVideo({
    required this.id,
    required this.title,
    required this.kind,
    required this.source,
    required this.url,
    required this.thumb,
    required this.publishedAtMs,
    required this.scheduledAtMs,
    required this.endsAtMs,
    required this.durationSeconds,
    required this.isShort,
    required this.isUpcoming,
    required this.isCancelled,
    required this.liveStatus,
    required this.hasBilibili,
    required this.bilibiliUrl,
    required this.tag,
    required this.translated,
  });

  factory KanoVideo.fromJson(Map<String, dynamic> json) {
    final picked = _pickTranslation(_obj(json['translations']), _str(json['title']));
    var biliUrl = '';
    for (final alt in _list(json['alternates'])) {
      if (_str(alt['source']).contains('bili') && _str(alt['url']).isNotEmpty) {
        biliUrl = _str(alt['url']);
        break;
      }
    }
    final raw = <String, dynamic>{
      'isShort': json['isShort'],
      'tag': json['tag'],
      'kind': json['kind'],
      'title': _str(json['title']),
      'isUpcoming': json['isUpcoming'],
      'liveStatus': json['liveStatus'],
    };
    return KanoVideo(
      id: _str(json['id']),
      title: picked.text,
      translated: picked.translated,
      kind: _str(json['kind']),
      source: _str(json['source']),
      url: _str(json['url']),
      thumb: KanoServer.absolute(_str(json['thumbnailUrl'])),
      publishedAtMs: KanoTime.parseIso(_str(json['publishedAt'])),
      scheduledAtMs: KanoTime.parseIso(_str(json['scheduledAt'])),
      endsAtMs: KanoTime.parseIso(_str(json['endsAt'])),
      durationSeconds: _num(json['durationSeconds']),
      isShort: _bool(json['isShort']),
      isUpcoming: _bool(json['isUpcoming']),
      isCancelled: _bool(json['isCancelled']),
      liveStatus: _str(json['liveStatus']),
      hasBilibili: biliUrl.isNotEmpty,
      bilibiliUrl: KanoServer.absolute(biliUrl),
      tag: videoTag(raw),
    );
  }

  final String id;
  final String title;
  final String kind;
  final String source;
  final String url;
  final String thumb;
  final int publishedAtMs;
  final int scheduledAtMs;
  final int endsAtMs;
  final int durationSeconds;
  final bool isShort;
  final bool isUpcoming;
  final bool isCancelled;
  final String liveStatus;
  final bool hasBilibili;
  final String bilibiliUrl;

  /// live / game / talk / song / video，外加竖屏短片的 short；永远有值。
  final String tag;
  final bool translated;

  String get tagLabel => KanoKind.label(tag);

  bool get isLive => liveStatus == 'live';

  /// `mm:ss` / `h:mm:ss`，零时长返回空串。
  String get durationText {
    if (durationSeconds <= 0) return '';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    final mm = m < 10 ? '0$m' : '$m';
    final ss = s < 10 ? '0$s' : '$s';
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Shorts 是形式而不是内容，先于服务端标签显示。
  static String videoTag(Map<String, dynamic> raw) {
    if (_bool(raw['isShort'])) return KanoKind.short;
    final pinned = _str(raw['tag']).toLowerCase();
    if (KanoKind.isKindTag(pinned)) return pinned;
    return classify(_str(raw['title']), _str(raw['kind']), _bool(raw['isUpcoming']), _str(raw['liveStatus']));
  }

  /// 兜底判定：只有直播 / 预告 / 直播存档才细分歌回、游戏播、杂谈，
  /// 其余（含所有短片与投稿）一律算「投稿」。
  static String classify(String title, String kind, bool isUpcoming, String liveStatus) {
    final broadcast = kind == 'stream' || liveStatus == 'live' || liveStatus == 'upcoming' || isUpcoming;
    if (!broadcast) return KanoKind.video;
    final hay = title.toLowerCase();
    if (RegExp(r'歌枠|歌配信|歌回|歌ってみた|カラオケ|karaoke|sing|song|cover|弾き語り|カバー|歌唱|うた')
        .hasMatch(hay)) {
      return KanoKind.song;
    }
    if (RegExp(
            r'ゲー|実況|gameplay|\bgame\b|apex|valorant|minecraft|フォートナイト|マインクラフト|爆弾|マリオ|ポケモン|スプラ|原神|スタレ|among|ホラー|steam|ps5|switch|雀|ポーカー|ほの暮|リズム天国|supermarket|drop the cake|bombanana|wardogs|how to fish')
        .hasMatch(hay)) {
      return KanoKind.game;
    }
    if (RegExp(r'雑談|free talk|\btalk\b|chat|しゅみ|ラジオ|radio|おつかれ|挨拶|報告|質問|メン限').hasMatch(hay)) {
      return KanoKind.talk;
    }
    return KanoKind.live;
  }
}

class KanoProfile {
  const KanoProfile({
    required this.displayName,
    required this.romanizedName,
    required this.bio,
    required this.avatar,
    required this.banner,
    required this.xUrl,
    required this.youtubeUrl,
    required this.mainHandle,
    required this.ownerHandles,
  });

  factory KanoProfile.fromJson(Map<String, dynamic> json) {
    final xUrl = _str(json['xUrl']);
    return KanoProfile(
      displayName: _str(json['displayName']),
      romanizedName: _str(json['romanizedName']),
      bio: _str(json['bio']),
      avatar: KanoServer.absolute(_str(json['avatarUrl'])),
      banner: KanoServer.absolute(_str(json['bannerUrl'])),
      xUrl: xUrl,
      youtubeUrl: _str(json['youtubeUrl']),
      mainHandle: KanoServer.accountOf(xUrl),
      ownerHandles: const [],
    );
  }

  final String displayName;
  final String romanizedName;
  final String bio;
  final String avatar;
  final String banner;
  final String xUrl;
  final String youtubeUrl;

  /// 主号 handle（小写），用来把 dashboard 的头像挂到对应账号的卡片上。
  final String mainHandle;

  /// 同一个人的 X 账号（主号 + 小号，均小写），这些账号的帖子共用同一张头像。
  final List<String> ownerHandles;

  KanoProfile withOwnerHandles(List<String> handles) => KanoProfile(
        displayName: displayName,
        romanizedName: romanizedName,
        bio: bio,
        avatar: avatar,
        banner: banner,
        xUrl: xUrl,
        youtubeUrl: youtubeUrl,
        mainHandle: mainHandle,
        ownerHandles: handles.map((e) => e.toLowerCase()).toList(growable: false),
      );

  /// 某条帖子是否属于这个人名下的账号。
  bool owns(String handle) {
    final h = handle.toLowerCase();
    return h == mainHandle || ownerHandles.contains(h);
  }
}

class KanoMilestone {
  const KanoMilestone({required this.year, required this.title, required this.detail});

  factory KanoMilestone.fromJson(Map<String, dynamic> json) => KanoMilestone(
        year: _str(json['year']),
        title: KanoText.localizeSeed(_str(json['title'])),
        detail: KanoText.localizeSeed(_str(json['detail'])),
      );

  final String year;
  final String title;
  final String detail;
}

class KanoResource {
  const KanoResource({
    required this.id,
    required this.title,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.url,
    required this.sortOrder,
  });

  factory KanoResource.fromJson(Map<String, dynamic> json) => KanoResource(
        id: _num(json['id']),
        title: KanoText.localizeSeed(_str(json['title'])),
        detail: KanoText.localizeSeed(_str(json['detail'])),
        icon: _str(json['icon']),
        tone: _str(json['tone']),
        url: _str(json['url']),
        sortOrder: _num(json['sortOrder']),
      );

  final int id;
  final String title;
  final String detail;
  final String icon;
  final String tone;
  final String url;
  final int sortOrder;
}

class KanoDashboard {
  const KanoDashboard({
    required this.revision,
    required this.generatedAt,
    required this.lastSyncMs,
    required this.lastSyncStatus,
    required this.postWindowDays,
    required this.xAccounts,
    required this.profile,
    required this.counts,
    required this.latestPost,
    required this.latestVideo,
    required this.nextEvent,
    required this.nextStream,
    required this.posts,
    required this.events,
    required this.videos,
    required this.timeline,
    required this.resources,
  });

  factory KanoDashboard.fromJson(Map<String, dynamic> json) {
    final meta = _obj(json['meta']);
    final accounts = <String>[];
    final rawAccounts = meta['xAccounts'];
    if (rawAccounts is List) {
      for (final a in rawAccounts) {
        final s = _str(a);
        if (s.isNotEmpty) accounts.add(s);
      }
    }
    final summary = _obj(json['summary']);
    final profileJson = json['profile'];
    var profile = profileJson is Map ? KanoProfile.fromJson(_obj(profileJson)) : null;
    profile = profile?.withOwnerHandles(accounts);

    final latestPostJson = summary['latestPost'];
    final latestVideoJson = summary['latestVideo'];
    final nextEventJson = summary['nextEvent'];
    final nextStreamJson = summary['nextStream'];

    final counts = <String, int>{};
    final rawCounts = _obj(summary['counts']);
    rawCounts.forEach((k, v) => counts[k] = _num(v));

    return KanoDashboard(
      revision: _num(meta['revision']),
      generatedAt: _str(meta['generatedAt']),
      lastSyncMs: KanoTime.parseIso(_str(_obj(meta['lastSync'])['startedAt'])),
      lastSyncStatus: _str(_obj(meta['lastSync'])['status']),
      postWindowDays: _num(meta['postWindowDays']),
      xAccounts: accounts,
      profile: profile,
      counts: counts,
      latestPost: latestPostJson is Map ? KanoPost.fromJson(_obj(latestPostJson)) : null,
      latestVideo: latestVideoJson is Map ? KanoVideo.fromJson(_obj(latestVideoJson)) : null,
      nextEvent: nextEventJson is Map ? KanoEvent.fromJson(_obj(nextEventJson)) : null,
      nextStream: nextStreamJson is Map ? KanoEvent.fromJson(_obj(nextStreamJson)) : null,
      posts: _list(json['posts']).map(KanoPost.fromJson).toList(growable: false),
      events: _list(json['events']).map(KanoEvent.fromJson).toList(growable: false),
      videos: _list(json['videos']).map(KanoVideo.fromJson).toList(growable: false),
      timeline: _list(json['timeline']).map(KanoMilestone.fromJson).toList(growable: false),
      resources: _list(json['resources']).map(KanoResource.fromJson).toList(growable: false),
    );
  }

  final int revision;
  final String generatedAt;
  final int lastSyncMs;
  final String lastSyncStatus;
  final int postWindowDays;
  final List<String> xAccounts;
  final KanoProfile? profile;
  final Map<String, int> counts;
  final KanoPost? latestPost;
  final KanoVideo? latestVideo;
  final KanoEvent? nextEvent;
  final KanoEvent? nextStream;
  final List<KanoPost> posts;
  final List<KanoEvent> events;
  final List<KanoVideo> videos;
  final List<KanoMilestone> timeline;
  final List<KanoResource> resources;

  /// 未来 7 天的日程（主页「即将开始」与日程表顶部列表共用）。
  List<KanoEvent> upcomingEvents({int days = 7}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = now + days * KanoTime.dayMs;
    final list = events.where((e) {
      if (e.cancelled) return false;
      if (e.timeMs > 0) return e.timeMs >= now && e.timeMs <= limit;
      return e.startsOn.isNotEmpty &&
          e.startsOn.compareTo(KanoTime.dayKeyOfMs(now)) >= 0 &&
          e.startsOn.compareTo(KanoTime.dayKeyOfMs(limit)) <= 0;
    }).toList()
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return list;
  }
}

class KanoPostPage {
  const KanoPostPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.revision,
    required this.accountCounts,
  });

  factory KanoPostPage.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    _obj(json['accountCounts']).forEach((k, v) => counts[k] = _num(v));
    return KanoPostPage(
      items: _list(json['items']).map(KanoPost.fromJson).toList(growable: false),
      page: _num(json['page']) == 0 ? 1 : _num(json['page']),
      pageSize: _num(json['pageSize']) == 0 ? 30 : _num(json['pageSize']),
      total: _num(json['total']),
      totalPages: _num(json['totalPages']),
      hasNext: _bool(json['hasNext']),
      revision: _num(json['revision']),
      accountCounts: counts,
    );
  }

  final List<KanoPost> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasNext;
  final int revision;
  final Map<String, int> accountCounts;
}

class KanoCalendarPage {
  const KanoCalendarPage({
    required this.events,
    required this.dayCounts,
    required this.total,
    required this.revision,
  });

  /// 服务端这个端点返回的是 `events` 而不是 `items`——实测踩过，两种都兼容。
  factory KanoCalendarPage.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    _obj(json['dayCounts']).forEach((k, v) => counts[k] = _num(v));
    final rawEvents = json['events'] is List ? json['events'] : json['items'];
    return KanoCalendarPage(
      events: _list(rawEvents).map(KanoEvent.fromJson).toList(growable: false),
      dayCounts: counts,
      total: _num(json['total']),
      revision: _num(json['revision']),
    );
  }

  final List<KanoEvent> events;
  final Map<String, int> dayCounts;
  final int total;
  final int revision;

  int countOf(String dayKey) => dayCounts[dayKey] ?? 0;

  List<KanoEvent> eventsOn(String dayKey) {
    final list = events.where((e) {
      if (e.startsOn.isNotEmpty) return e.startsOn == dayKey;
      return e.timeMs > 0 && KanoTime.dayKeyOfMs(e.timeMs) == dayKey;
    }).toList()
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return list;
  }

  KanoCalendarPage merge(KanoCalendarPage other) {
    final merged = <String, KanoEvent>{};
    for (final e in [...events, ...other.events]) {
      merged[e.id.isEmpty ? '${e.title}|${e.startsOn}|${e.timeMs}' : e.id] = e;
    }
    final counts = <String, int>{...dayCounts};
    other.dayCounts.forEach((k, v) => counts[k] = v);
    return KanoCalendarPage(
      events: merged.values.toList(growable: false),
      dayCounts: counts,
      total: merged.length,
      revision: other.revision > revision ? other.revision : revision,
    );
  }
}

class KanoHealth {
  const KanoHealth({
    required this.ok,
    required this.nowMs,
    required this.syncStatus,
    required this.syncStartedMs,
    required this.syncMessage,
  });

  factory KanoHealth.fromJson(Map<String, dynamic> json) {
    final sync = json['lastSync'];
    final syncMap = sync is Map ? _obj(sync) : const <String, dynamic>{};
    return KanoHealth(
      ok: _bool(json['ok']),
      nowMs: KanoTime.parseIso(_str(json['now'])),
      syncStatus: _str(syncMap['status']),
      syncStartedMs: KanoTime.parseIso(_str(syncMap['startedAt'])),
      syncMessage: _str(syncMap['message']),
    );
  }

  final bool ok;
  final int nowMs;
  final String syncStatus;
  final int syncStartedMs;
  final String syncMessage;
}

/// 数据来源：net 新鲜拿到 / mem 内存命中 / cache 磁盘快照兜底 / error 什么都没有
enum KanoSource {
  net,
  mem,
  cache,
  error;

  bool get isStale => this == KanoSource.cache || this == KanoSource.error;
  bool get hasData => this != KanoSource.error;
}

class KanoTextResult {
  const KanoTextResult(this.text, this.source);

  final String text;
  final KanoSource source;

  static const empty = KanoTextResult('', KanoSource.error);
}

/// `/api/videos` 的分页结果。服务端额外给了 `categoryCounts`，
/// YouTube 三个子 tab 可以直接用它分，不用客户端自己数。
class KanoVideoPage {
  const KanoVideoPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
    required this.revision,
    required this.categoryCounts,
  });

  factory KanoVideoPage.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    _obj(json['categoryCounts']).forEach((k, v) => counts[k] = _num(v));
    return KanoVideoPage(
      items: _list(json['items']).map(KanoVideo.fromJson).toList(growable: false),
      page: _num(json['page']) == 0 ? 1 : _num(json['page']),
      pageSize: _num(json['pageSize']) == 0 ? 30 : _num(json['pageSize']),
      total: _num(json['total']),
      hasNext: _bool(json['hasNext']),
      revision: _num(json['revision']),
      categoryCounts: counts,
    );
  }

  final List<KanoVideo> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;
  final int revision;
  final Map<String, int> categoryCounts;
}
