import 'package:shared_preferences/shared_preferences.dart';

/// 磁盘快照缓存。
///
/// 服务端本身就是「定时抓取 + 本地快照」的模型，客户端照抄这个思路：
/// 网络拿不到时回退上一次的 JSON，页面永远不空着。
/// key 与鸿蒙 `PreferencesUtil` 一致（`kanoSnap:<key>`），方便对照。
class KanoCache {
  KanoCache._();

  static const _prefix = 'kanoSnap:';
  static const _atSuffix = ':at';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences?> _instance() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    return _prefs;
  }

  static String _textKey(String key) => '$_prefix$key';
  static String _atKey(String key) => '$_prefix$key$_atSuffix';

  static Future<String> read(String key) async {
    final prefs = await _instance();
    if (prefs == null) return '';
    try {
      return prefs.getString(_textKey(key)) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 上次写入快照的时间（毫秒），没有则 0。
  static Future<int> readAt(String key) async {
    final prefs = await _instance();
    if (prefs == null) return 0;
    try {
      return prefs.getInt(_atKey(key)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> write(String key, String text) async {
    final prefs = await _instance();
    if (prefs == null) return;
    try {
      await prefs.setString(_textKey(key), text);
      await prefs.setInt(_atKey(key), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // 写盘失败不影响在线取数，只是没得兜底
    }
  }

  static Future<void> remove(String key) async {
    final prefs = await _instance();
    if (prefs == null) return;
    try {
      await prefs.remove(_textKey(key));
      await prefs.remove(_atKey(key));
    } catch (_) {
      // ignore
    }
  }

  static Future<void> clear() async {
    final prefs = await _instance();
    if (prefs == null) return;
    try {
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList(growable: false);
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // ignore
    }
  }

  /// 缓存占用（字符数）与条目数，设置页用来显示「已缓存 N 项」。
  static Future<(int count, int chars)> stats() async {
    final prefs = await _instance();
    if (prefs == null) return (0, 0);
    var count = 0;
    var chars = 0;
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(_prefix) || k.endsWith(_atSuffix)) continue;
      count++;
      chars += (prefs.getString(k) ?? '').length;
    }
    return (count, chars);
  }
}

/// 本地偏好（非缓存），与快照分开管理，`清空缓存` 不会误删用户设置。
class KanoPrefs {
  KanoPrefs._();

  static const _serverBase = 'kanoPrefs:serverBase';
  static const _themeMode = 'kanoPrefs:themeMode';
  static const _feedPlatform = 'kanoPrefs:feedPlatform';
  static const _calendarReminder = 'kanoPrefs:calendarReminder';
  static const _langMode = 'kanoPrefs:langMode';
  // 下面三项对应鸿蒙首页编辑态里的 `@StorageLink('bgBlurRadius' / 'bgMaskOpacity' / 壁纸)`，
  // Android 侧没有编辑态，改由设置 → 个性化直接调。
  static const _bgBlur = 'kanoPrefs:bgBlur';
  static const _bgMask = 'kanoPrefs:bgMask';
  static const _bgPreset = 'kanoPrefs:bgPreset';
  static const _haptics = 'kanoPrefs:haptics';

  // ===== 个性化（首页编辑态）=====
  // 键名与鸿蒙 `@StorageLink` / `PreferencesUtil` 一一对应，方便逐项回溯。
  static const _barHideText = 'kanoPrefs:barHideText';
  static const _flowLightMode = 'kanoPrefs:flowLightMode';
  static const _flowLightSpeed = 'kanoPrefs:flowLightSpeed';
  static const _materialThickness = 'kanoPrefs:materialThickness';
  static const _materialLevel = 'kanoPrefs:materialLevel';
  static const _pressColorMode = 'kanoPrefs:pressColorMode';
  static const _staggerEnabled = 'kanoPrefs:staggerEnabled';
  static const _staggerDistance = 'kanoPrefs:staggerDistance';
  static const _staggerInterval = 'kanoPrefs:staggerInterval';
  static const _staggerResponse = 'kanoPrefs:staggerResponse';
  static const _pageTransition = 'kanoPrefs:pageTransition';
  static const _predictiveBack = 'kanoPrefs:predictiveBack';
  static const _themeColor = 'kanoPrefs:themeColor';
  static const _customBackgrounds = 'kanoPrefs:customBackgrounds';
  /// 当前激活的打包主题名（空串 = 默认）。对应鸿蒙 `profile_activeTheme`。
  static const _activeTheme = 'kanoPrefs:activeTheme';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences?> _instance() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    return _prefs;
  }

  static Future<String> getString(String key, [String fallback = '']) async {
    final prefs = await _instance();
    return prefs?.getString(key) ?? fallback;
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await _instance();
    await prefs?.setString(key, value);
  }

  static Future<bool> getBool(String key, [bool fallback = false]) async {
    final prefs = await _instance();
    return prefs?.getBool(key) ?? fallback;
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await _instance();
    await prefs?.setBool(key, value);
  }

  static Future<int> getInt(String key, [int fallback = 0]) async {
    final prefs = await _instance();
    return prefs?.getInt(key) ?? fallback;
  }

  static Future<void> setInt(String key, int value) async {
    final prefs = await _instance();
    await prefs?.setInt(key, value);
  }

  static String get serverBaseKey => _serverBase;
  static String get themeModeKey => _themeMode;
  static String get feedPlatformKey => _feedPlatform;
  static String get calendarReminderKey => _calendarReminder;
  static String get langModeKey => _langMode;
  static String get bgBlurKey => _bgBlur;
  static String get bgMaskKey => _bgMask;
  static String get bgPresetKey => _bgPreset;
  static String get hapticsKey => _haptics;
  static String get barHideTextKey => _barHideText;
  static String get flowLightModeKey => _flowLightMode;
  static String get flowLightSpeedKey => _flowLightSpeed;
  static String get materialThicknessKey => _materialThickness;
  static String get materialLevelKey => _materialLevel;
  static String get pressColorModeKey => _pressColorMode;
  static String get staggerEnabledKey => _staggerEnabled;
  static String get staggerDistanceKey => _staggerDistance;
  static String get staggerIntervalKey => _staggerInterval;
  static String get staggerResponseKey => _staggerResponse;
  static String get pageTransitionKey => _pageTransition;
  static String get predictiveBackKey => _predictiveBack;
  static String get themeColorKey => _themeColor;
  static String get customBackgroundsKey => _customBackgrounds;
  static String get activeThemeKey => _activeTheme;
}
