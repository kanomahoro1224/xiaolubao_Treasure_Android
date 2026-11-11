import 'dart:async';

import 'package:dio/dio.dart';

import '../domain/kano_models.dart';
import '../domain/kano_server.dart';
import 'kano_cache.dart';

/// 统一的 GET：内存 TTL → 磁盘快照 → 网络。
///
/// 与鸿蒙 `KanoApi.getText` 同一套策略：
/// - 内存命中且未过期直接返回
/// - 带上 `If-None-Match`，命中就是 304（响应体为空），省一次整包下载
/// - 主站传输失败或 5xx 时切备用站，切换后本次启动内锁定
/// - 网络彻底失败但磁盘有快照时返回快照，并把来源标成 cache
class KanoClient {
  KanoClient._();

  static final KanoClient instance = KanoClient._();

  static const _connectTimeout = Duration(seconds: 8);
  static const _receiveTimeout = Duration(seconds: 20);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      sendTimeout: _connectTimeout,
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (_) => true,
      headers: const {
        // 服务端返回的是压缩前的 JSON，交给 dio 自己解压
        'Accept': 'application/json',
      },
    ),
  );

  final Map<String, _MemEntry> _mem = {};
  final Map<String, String> _etags = {};

  /// 最近一次请求用的基址，调试面板显示用。
  String get activeBase => KanoServer.base;

  /// 强制丢掉内存 TTL 与 ETag，让「刷新」能真的重新拉一次。
  void forget(String key) {
    _mem.remove(key);
    _etags.remove(key);
  }

  void forgetPrefix(String prefix) {
    final keys = _mem.keys.where((k) => k.startsWith(prefix)).toList(growable: false);
    for (final k in keys) {
      _mem.remove(k);
      _etags.remove(k);
    }
  }

  /// 设置页「清空缓存」用：内存与磁盘一起丢，偏好不动。
  void clearMemory() {
    _mem.clear();
    _etags.clear();
  }

  Future<KanoTextResult> getText(
    String key,
    String path, {
    required Duration ttl,
    bool force = false,
  }) async {
    if (force) forget(key);

    final now = DateTime.now().millisecondsSinceEpoch;
    final memHit = _mem[key];
    if (memHit != null && memHit.text.isNotEmpty && now - memHit.at < ttl.inMilliseconds) {
      return KanoTextResult(memHit.text, KanoSource.mem);
    }

    var stale = (memHit != null && memHit.text.isNotEmpty) ? memHit.text : '';
    if (stale.isEmpty) {
      stale = await KanoCache.read(key);
      if (stale.isNotEmpty) _mem[key] = _MemEntry(stale, 0);
    }

    var base = KanoServer.base;
    var url = '$base$path';
    final etag = _etags[key] ?? '';
    final headers = <String, String>{if (etag.isNotEmpty) 'If-None-Match': etag};

    Response<String>? response;
    try {
      response = await _dio.get<String>(url, options: Options(headers: headers));
      // 5xx 说明主站进程在但服务不可用，也按连不上处理；4xx 是请求本身的问题，不切
      if ((response.statusCode ?? 0) >= 500) {
        final fallback = KanoServer.switchToFallback(base);
        if (fallback != null) {
          base = fallback;
          url = '$base$path';
          response = await _dio.get<String>(url, options: Options(headers: headers));
        }
      }
    } catch (_) {
      final fallback = KanoServer.switchToFallback(base);
      if (fallback == null) {
        return KanoTextResult(stale, stale.isNotEmpty ? KanoSource.cache : KanoSource.error);
      }
      base = fallback;
      url = '$base$path';
      try {
        response = await _dio.get<String>(url, options: Options(headers: headers));
      } catch (_) {
        return KanoTextResult(stale, stale.isNotEmpty ? KanoSource.cache : KanoSource.error);
      }
    }

    final status = response.statusCode ?? 0;
    if (status == 304 && stale.isNotEmpty) {
      _mem[key] = _MemEntry(stale, DateTime.now().millisecondsSinceEpoch);
      return KanoTextResult(stale, KanoSource.mem);
    }
    if (status != 200) {
      return KanoTextResult(stale, stale.isNotEmpty ? KanoSource.cache : KanoSource.error);
    }

    final text = response.data ?? '';
    if (text.isEmpty) {
      return KanoTextResult(stale, stale.isNotEmpty ? KanoSource.cache : KanoSource.error);
    }

    _mem[key] = _MemEntry(text, DateTime.now().millisecondsSinceEpoch);
    final newEtag = response.headers.value('etag') ?? response.headers.value('ETag') ?? '';
    if (newEtag.isNotEmpty) _etags[key] = newEtag;
    await KanoCache.write(key, text);
    return KanoTextResult(text, KanoSource.net);
  }

  /// 直接拿纯文本（`/api/calendar.ics`、`/api/feed.xml` 用）。
  Future<String> getRaw(String path) async {
    final url = '${KanoServer.base}$path';
    try {
      final res = await _dio.get<String>(url);
      return res.data ?? '';
    } catch (_) {
      return '';
    }
  }

  void dispose() {
    _dio.close(force: true);
    _mem.clear();
    _etags.clear();
  }
}

class _MemEntry {
  const _MemEntry(this.text, this.at);
  final String text;
  final int at;
}
