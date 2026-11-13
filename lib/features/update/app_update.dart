import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../kano/data/kano_cache.dart';
import '../kano/domain/kano_server.dart';
import '../../core/app_info.dart';

/// 服务端下发的一条最新版本记录（`GET /api/app/release?platform=android`）。
///
/// 下载地址**只能**来自这里：客户端不写死任何 apk / 网盘链接，换分发方式时
/// 只改服务端配置，装出去的旧版本不用跟着发版。
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.minSupportedCode,
    required this.downloadUrl,
    required this.notes,
  });

  /// 与 APK 的 versionCode 对齐的整数；版本比较只用它。
  final int versionCode;
  final String versionName;

  /// 低于这个版本属于「必须更新」。目前只用来加重语气，不做无法退出的封锁：
  /// 侧载没有应用商店兜底，把弹窗做成关不掉等于自断退路。
  final int minSupportedCode;
  final String downloadUrl;
  final String notes;

  bool get hasDownload => downloadUrl.isNotEmpty;
  bool get forced => versionCode > 0 && minSupportedCode >= versionCode;

  static AppRelease? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = (raw['versionCode'] as num?)?.toInt();
    if (code == null || code <= 0) return null;
    final url = (raw['downloadUrl'] as String?)?.trim() ?? '';
    if (url.isEmpty) return null;
    return AppRelease(
      versionCode: code,
      versionName: (raw['versionName'] as String?)?.trim() ?? '',
      minSupportedCode: (raw['minSupportedCode'] as num?)?.toInt() ?? 0,
      downloadUrl: url,
      notes: (raw['notes'] as String?)?.trim() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'versionCode': versionCode,
        'versionName': versionName,
        'minSupportedCode': minSupportedCode,
        'downloadUrl': downloadUrl,
        'notes': notes,
      };
}

enum AppUpdateAction { ignore, later, download }

/// 冷启动的版本检查。
///
/// 三个 key 分工明确，别合并：
/// - `checkedAt` 只压请求频率（24h 一次），不决定要不要弹
/// - `latest` 缓存上次结果，让「下次再说」在下一个冷启动还能弹，不用重新联网
/// - `ignored` 是「忽略此版本」：记住那个 versionCode，更高的版本照常提示
class AppUpdate {
  AppUpdate._();

  static const _channel = MethodChannel('kano/app');

  static const _checkedAtKey = 'kanoPrefs:updateCheckedAt';
  static const _latestKey = 'kanoPrefs:updateLatest';
  static const _ignoredKey = 'kanoPrefs:updateIgnoredCode';

  static const checkInterval = Duration(hours: 24);
  static const _timeout = Duration(seconds: 5);

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: _timeout,
    receiveTimeout: _timeout,
    responseType: ResponseType.plain,
    // 版本号绝对不能吃缓存：改了配置却读回上周的 JSON，等于没发版。
    headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
  ));

  /// 装在这台机器上的 APK 的真实 versionCode；拿不到返回 0（= 不检查）。
  static Future<int> installedVersionCode() async {
    if (!Platform.isAndroid) return 0;
    try {
      final version = await _channel.invokeMapMethod<String, Object?>('version');
      return (version?['versionCode'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 有该提示的版本就返回它，否则 null。任何异常都当成「没有更新」：
  /// 一个每次开 App 都弹错误框的版本，用户会直接退回旧版。
  ///
  /// [force] 跳过 24h 节流（设置页手动检查用）。
  /// 只有正式包参与更新链。旁路包（包名结尾加 1）走 `--dart-define` 换包名，
  /// 它装不上正式包的 APK，提示了也只会多出一个图标，所以直接跳过检查。
  static const _canonicalPackageId = 'kano.xiaolubao.com';

  static Future<AppRelease?> pending({bool force = false}) async {
    if (AppInfo.packageId != _canonicalPackageId) return null;
    final installed = await installedVersionCode();
    if (installed <= 0) return null;

    var latest = _decode(await KanoPrefs.getString(_latestKey));
    final checkedAt = await KanoPrefs.getInt(_checkedAtKey);
    final stale = DateTime.now().millisecondsSinceEpoch - checkedAt > checkInterval.inMilliseconds;
    if (force || latest == null || stale) {
      final fetched = await _fetch();
      if (fetched != null) {
        latest = fetched;
        await KanoPrefs.setString(_latestKey, jsonEncode(fetched.toJson()));
        await KanoPrefs.setInt(_checkedAtKey, DateTime.now().millisecondsSinceEpoch);
      }
    }
    if (latest == null) return null;

    // 已经升过：缓存里的旧结论要清掉，否则降级安装后又会被翻出来。
    if (latest.versionCode <= installed) {
      await KanoPrefs.setString(_latestKey, '');
      return null;
    }
    final ignored = await KanoPrefs.getInt(_ignoredKey);
    if (latest.versionCode == ignored) return null;
    return latest;
  }

  /// 「忽略此版本」：只跳过这一个 versionCode。
  static Future<void> ignore(int versionCode) => KanoPrefs.setInt(_ignoredKey, versionCode);

  /// 把「忽略」清掉（设置页手动检查时用，避免用户自己都看不到新版本）。
  static Future<void> clearIgnored() => KanoPrefs.setInt(_ignoredKey, 0);

  static AppRelease? _decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return AppRelease.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<AppRelease?> _fetch() async {
    // 固定打官方主站：设置页允许填自建实例，那台服务器不会部署这个接口。
    final url = '${KanoServer.defaultBase}/api/app/release?platform=android';
    try {
      final response = await _dio.get<String>(url);
      if (response.statusCode != 200) return null;
      final text = response.data;
      if (text == null || text.isEmpty) return null;
      return AppRelease.fromJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }
}
