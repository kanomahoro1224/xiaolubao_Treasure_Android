/// 服务端基址与主备站切换。
///
/// 与鸿蒙 `KanoServer` 同一套口径：
/// - 默认主站 `https://xiaolubao.com`
/// - 主站传输失败或 5xx 时切到备站 `https://kano.yexca.net`
/// - 切换后本次启动内锁定备站，不再来回跳
/// - `/media`、`/assets` 这类相对路径必须补上当前基址
class KanoServer {
  KanoServer._();

  static const defaultBase = 'https://xiaolubao.com';
  static const fallbackBase = 'https://kano.yexca.net';

  static bool _fallbackActive = false;
  static String? _customBase;

  /// 当前生效的基址（末尾无斜杠）。
  static String get base => _customBase ?? (_fallbackActive ? fallbackBase : defaultBase);

  /// 是否已经在备用站上（用于界面上给一句提示）。
  static bool get onFallback => _customBase == null && _fallbackActive;

  /// 用户自定义的实例；空串表示没设过（走主备站）。
  static String get customBase => _customBase ?? '';

  /// 用户自定义实例（设置页可改），传空串恢复默认。
  static void setCustomBase(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      _customBase = null;
      return;
    }
    final normalized = normalize(value);
    _customBase = normalized == defaultBase ? null : normalized;
  }

  /// 主站失败时调用；返回新基址，已切换过或自定义实例则返回 null。
  static String? switchToFallback(String from) {
    if (_fallbackActive) return null;
    if (normalize(from) != defaultBase) return null;
    _fallbackActive = true;
    return fallbackBase;
  }

  static String normalize(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return defaultBase;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static const _knownHosts = <String>[
    'https://xiaolubao.com',
    'http://xiaolubao.com',
    'https://kano.yexca.net',
    'http://kano.yexca.net',
  ];

  /// 把服务端给的相对路径补成绝对地址；主备切换后旧快照里的主站地址也会被改写到当前基址。
  static String absolute(String path) {
    if (path.isEmpty) return '';
    for (final host in _knownHosts) {
      if (!path.startsWith(host)) continue;
      final rest = path.substring(host.length);
      if (rest.isNotEmpty && !rest.startsWith('/') && !rest.startsWith('?')) continue;
      return '$base$rest';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }

  /// 从 X 主页地址里抠出小写 handle（`/api/posts?account=` 要这个形态）。
  static String accountOf(String xUrl) {
    final match = RegExp(r'x\.com/([^/?#]+)', caseSensitive: false).firstMatch(xUrl);
    return match == null ? '' : match.group(1)!.toLowerCase();
  }
}
