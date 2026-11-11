import 'dart:convert';

import '../domain/kano_models.dart';
import '../domain/kano_server.dart';
import '../domain/kano_time.dart';
import 'kano_cache.dart';
import 'kano_client.dart';

/// 带来源标记的数据结果：页面据此决定要不要显示「离线快照」提示条。
class KanoResult<T> {
  const KanoResult({
    required this.data,
    required this.source,
    required this.cachedAt,
  });

  final T? data;
  final KanoSource source;
  final int cachedAt;

  bool get hasData => data != null;
  bool get isStale => source.isStale;
  bool get isError => source == KanoSource.error;
}

/// kano-navi 的读取入口。所有页面只跟这一层打交道。
class KanoRepository {
  KanoRepository._();

  static final KanoRepository instance = KanoRepository._();

  /// 归档分页的默认条数，与服务端 `archivePageSize` 一致。
  static const pageSize = 30;

  static const _dashboardTtl = Duration(seconds: 60);
  static const _postsTtl = Duration(minutes: 5);
  static const _calendarTtl = Duration(minutes: 10);
  static const _pastCalendarTtl = Duration(hours: 12);

  KanoClient get _client => KanoClient.instance;

  Future<KanoResult<KanoDashboard>> dashboard({bool force = false}) async {
    const key = 'dashboard';
    final result = await _client.getText(key, '/api/dashboard', ttl: _dashboardTtl, force: force);
    if (result.text.isEmpty) {
      return KanoResult(data: null, source: result.source, cachedAt: 0);
    }
    final data = _parse(result.text, KanoDashboard.fromJson);
    return KanoResult(
      data: data,
      source: data == null ? KanoSource.error : result.source,
      cachedAt: await KanoCache.readAt(key),
    );
  }

  Future<KanoResult<KanoPostPage>> posts({
    required String from,
    required String to,
    String account = '',
    int page = 1,
    bool force = false,
  }) async {
    final range = KanoTime.clampRange(from, to);
    final query = StringBuffer('?from=${range[0]}&to=${range[1]}&page=$page&pageSize=$pageSize');
    if (account.isNotEmpty) query.write('&account=${Uri.encodeComponent(account)}');
    final key = 'posts:${range[0]}:${range[1]}:$account:$page';
    final result = await _client.getText(key, '/api/posts$query', ttl: _postsTtl, force: force);
    if (result.text.isEmpty) return KanoResult(data: null, source: result.source, cachedAt: 0);
    final data = _parse(result.text, KanoPostPage.fromJson);
    return KanoResult(
      data: data,
      source: data == null ? KanoSource.error : result.source,
      cachedAt: await KanoCache.readAt(key),
    );
  }

  /// 视频归档（YouTube 三个子 tab 共用一份数据，本地按 kind / isShort 分）。
  Future<KanoResult<KanoVideoPage>> videos({
    required String from,
    required String to,
    int page = 1,
    bool force = false,
  }) async {
    final range = KanoTime.clampRange(from, to);
    final key = 'videos:${range[0]}:${range[1]}:$page';
    final result = await _client.getText(
      key,
      '/api/videos?from=${range[0]}&to=${range[1]}&page=$page&pageSize=$pageSize',
      ttl: _postsTtl,
      force: force,
    );
    if (result.text.isEmpty) return KanoResult(data: null, source: result.source, cachedAt: 0);
    final data = _parse(result.text, KanoVideoPage.fromJson);
    return KanoResult(
      data: data,
      source: data == null ? KanoSource.error : result.source,
      cachedAt: await KanoCache.readAt(key),
    );
  }

  /// 单月日历。`/api/calendar` 只吃 31 天内的范围，跨月直接 `invalid_calendar_range`。
  Future<KanoResult<KanoCalendarPage>> calendar({
    required int year,
    required int month,
    bool force = false,
  }) async {
    final (from, to) = KanoTime.monthRange(year, month);
    final key = 'calendar:$from:$to';
    final now = DateTime.now();
    final isPast = year < now.year || (year == now.year && month < now.month);
    final result = await _client.getText(
      key,
      '/api/calendar?from=$from&to=$to&pageSize=100',
      ttl: isPast ? _pastCalendarTtl : _calendarTtl,
      force: force,
    );
    if (result.text.isEmpty) return KanoResult(data: null, source: result.source, cachedAt: 0);
    final data = _parse(result.text, KanoCalendarPage.fromJson);
    return KanoResult(
      data: data,
      source: data == null ? KanoSource.error : result.source,
      cachedAt: await KanoCache.readAt(key),
    );
  }

  /// 当前月 + 前后各一个月，供日历翻页时左右都能立刻出内容。
  Future<KanoCalendarPage> calendarWithNeighbors(int year, int month) async {
    final prev = DateTime(year, month - 1);
    final next = DateTime(year, month + 1);
    final results = await Future.wait([
      calendar(year: prev.year, month: prev.month),
      calendar(year: year, month: month),
      calendar(year: next.year, month: next.month),
    ]);
    var merged = const KanoCalendarPage(
      events: [],
      dayCounts: {},
      total: 0,
      revision: 0,
    );
    for (final r in results) {
      final data = r.data;
      if (data != null) merged = merged.merge(data);
    }
    return merged;
  }

  Future<KanoHealth?> health() async {
    final result = await _client.getText(
      'health',
      '/api/health',
      ttl: const Duration(seconds: 60),
    );
    if (result.text.isEmpty) return null;
    return _parse(result.text, KanoHealth.fromJson);
  }

  /// `/api/dashboard/revision` 的轻量轮询：返回 -1 表示拿不到。
  Future<int> revision() async {
    final result = await _client.getText(
      'dashboard:revision',
      '/api/dashboard/revision',
      ttl: const Duration(seconds: 45),
    );
    if (result.text.isEmpty) return -1;
    final json = _decode(result.text);
    if (json == null) return -1;
    final value = json['revision'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  /// 系统日历订阅地址（设置页「加入日历」用）。
  String get calendarIcsUrl => '${KanoServer.base}/api/calendar.ics';

  String get feedUrl => '${KanoServer.base}/api/feed.xml';

  /// 强制刷新：清掉 dashboard 与所有归档前缀的 TTL / ETag。
  void invalidateAll() {
    _client.forget('dashboard');
    _client.forget('dashboard:revision');
    _client.forget('health');
    _client.forgetPrefix('posts:');
    _client.forgetPrefix('videos:');
    _client.forgetPrefix('calendar:');
  }

  void invalidateFeed() {
    _client.forget('dashboard');
    _client.forgetPrefix('posts:');
    _client.forgetPrefix('videos:');
  }

  Map<String, dynamic>? _decode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
      return null;
    } catch (_) {
      return null;
    }
  }

  T? _parse<T>(String text, T Function(Map<String, dynamic>) build) {
    final json = _decode(text);
    if (json == null) return null;
    try {
      return build(json);
    } catch (_) {
      return null;
    }
  }
}
