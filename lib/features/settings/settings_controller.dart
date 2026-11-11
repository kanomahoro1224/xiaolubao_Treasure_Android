import 'package:flutter/material.dart';

import '../kano/data/kano_cache.dart';
import '../kano/data/kano_client.dart';
import '../kano/data/kano_theme.dart';
import '../kano/domain/kano_server.dart';
import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_notifications.dart';
import '../kano/presentation/kano_palette.dart';

/// 设置项的真相源。
///
/// 与鸿蒙 `SettingsPage` 里的 `@StorageLink` 一批量同一个角色：设置页只改这里，
/// `app.dart` 监听它重建 MaterialApp，底栏与四个页面不需要各自再读一遍偏好。
class SettingsController extends ChangeNotifier {
  SettingsController._();

  static final SettingsController instance = SettingsController._();

  /// 语言模式下标即模式值：0 跟随系统 / 1 简中 / 2 繁中 / 3 日语 / 4 英文。
  /// **别改顺序** —— 设置页的分段控件直接用下标当值。
  static const langFollowSystem = 0;
  static const langCount = 5;

  ThemeMode _themeMode = ThemeMode.system;
  int _langMode = langFollowSystem;
  bool _haptics = true;

  /// 通知。总开关默认关，三项分类默认开，推文语言 0 = 跟随应用语言。
  /// 下标 1..4 对应简中 / 繁中 / 日语 / 英文。
  bool _pushEnabled = false;

  /// 系统通知是否仍可用。总开关的显示值是「本地偏好 && 系统仍允许」，
  /// 和鸿蒙 `prefs.getPushEnabled && PushUtil.notificationEnabled()` 一样。
  bool _notificationAllowed = true;
  bool _pushLive = true;
  bool _pushVideo = true;
  bool _pushPost = true;
  int _pushLanguage = 0;

  /// 背景参数，默认值与鸿蒙 `@StorageLink` 一致：blur 20、遮罩 0.8、预设壁纸。
  int _bgBlur = 20;
  int _bgMask = 80;
  String _bgPreset = bgPresetSakura;

  // ===== 个性化（对应 Home.ets 里的 @StorageLink 一批）=====
  bool _barHideText = false;
  int _flowLightMode = 0; // 0 关 / 1 开（鸿蒙默认关）
  int _flowLightSpeed = 8000; // 毫秒，鸿蒙滑块 1..20 秒
  int _materialThickness = 2; // 0 极薄 / 1 薄 / 2 标准 / 3 厚 / 4 极厚
  int _materialLevel = 0; // 0 自适应 / 1 精致 / 2 柔和 / 3 顺滑
  int _pressColorMode = 0; // 0 主题 / 1 白色
  bool _staggerEnabled = true;
  int _staggerDistance = 120; // vp，滑块 40..240
  int _staggerInterval = 30; // ms，滑块 10..80
  int _staggerResponse = 55; // 百分之一秒，滑块 25..120
  bool _pageTransition = true; // true 柔和 / false 效率
  bool _predictiveBack = true;
  String _themeColor = '#FFC0CB';
  List<String> _customBackgrounds = const [];

  ThemeMode get themeMode => _themeMode;
  int get langMode => _langMode;
  bool get haptics => _haptics;
  bool get pushEnabled => _pushEnabled && _notificationAllowed;
  bool get pushLive => _pushLive;
  bool get pushVideo => _pushVideo;
  bool get pushPost => _pushPost;
  int get pushLanguage => _pushLanguage;

  int get bgBlur => _bgBlur;

  /// 遮罩不透明度，0..100 的百分比（鸿蒙用的是 0..1 的 double，落盘用整数更稳）
  int get bgMask => _bgMask;
  double get bgMaskOpacity => _bgMask / 100;

  String get bgPreset => _bgPreset;

  bool get barHideText => _barHideText;
  int get flowLightMode => _flowLightMode;
  int get flowLightSpeed => _flowLightSpeed;
  int get materialThickness => _materialThickness;
  int get materialLevel => _materialLevel;
  int get pressColorMode => _pressColorMode;
  bool get staggerEnabled => _staggerEnabled;
  int get staggerDistance => _staggerDistance;
  int get staggerInterval => _staggerInterval;
  int get staggerResponse => _staggerResponse;
  bool get pageTransition => _pageTransition;
  bool get predictiveBack => _predictiveBack;
  String get themeColor => _themeColor;
  List<String> get customBackgrounds => List.unmodifiable(_customBackgrounds);

  /// 可选的背景：预设壁纸 / 纯主题底
  static const bgPresetSakura = 'sakura';
  static const bgPresetPlain = 'plain';

  /// 当前生效的基址（主备站切换后也会跟着变），设置页拿来显示「实际连的是哪台」。
  String get activeBase => KanoServer.base;

  /// 用户在设置页填的自定义实例；空串表示走主备站。
  String get customBase => KanoServer.customBase;

  /// 开机前调一次：先把语言与主题落到进程里，再建 widget 树，避免首帧闪一下默认语言。
  Future<void> load() async {
    _themeMode = _decodeTheme(await KanoPrefs.getString(KanoPrefs.themeModeKey, 'system'));
    _langMode = (await KanoPrefs.getInt(KanoPrefs.langModeKey, langFollowSystem))
        .clamp(0, langCount - 1)
        .toInt();
    _haptics = await KanoPrefs.getBool(KanoPrefs.hapticsKey, true);
    _pushEnabled = await KanoPrefs.getBool(KanoPrefs.pushEnabledKey, false);
    _notificationAllowed = await KanoNotifications.enabled();
    _pushLive = await KanoPrefs.getBool(KanoPrefs.pushLiveKey, true);
    _pushVideo = await KanoPrefs.getBool(KanoPrefs.pushVideoKey, true);
    _pushPost = await KanoPrefs.getBool(KanoPrefs.pushPostKey, true);
    _pushLanguage =
        (await KanoPrefs.getInt(KanoPrefs.pushLanguageKey, 0)).clamp(0, 4).toInt();
    _bgBlur = (await KanoPrefs.getInt(KanoPrefs.bgBlurKey, 20)).clamp(0, 100).toInt();
    _bgMask = (await KanoPrefs.getInt(KanoPrefs.bgMaskKey, 80)).clamp(0, 100).toInt();
    _bgPreset = await KanoPrefs.getString(KanoPrefs.bgPresetKey, bgPresetSakura);

    _barHideText = await KanoPrefs.getBool(KanoPrefs.barHideTextKey, false);
    _flowLightMode = (await KanoPrefs.getInt(KanoPrefs.flowLightModeKey, 0))
        .clamp(0, 1)
        .toInt();
    _flowLightSpeed = (await KanoPrefs.getInt(KanoPrefs.flowLightSpeedKey, 8000))
        .clamp(1000, 20000)
        .toInt();
    _materialThickness =
        (await KanoPrefs.getInt(KanoPrefs.materialThicknessKey, 2))
            .clamp(0, 4)
            .toInt();
    _materialLevel = (await KanoPrefs.getInt(KanoPrefs.materialLevelKey, 0))
        .clamp(0, 3)
        .toInt();
    _pressColorMode = (await KanoPrefs.getInt(KanoPrefs.pressColorModeKey, 0))
        .clamp(0, 1)
        .toInt();
    _staggerEnabled =
        await KanoPrefs.getBool(KanoPrefs.staggerEnabledKey, true);
    _staggerDistance =
        (await KanoPrefs.getInt(KanoPrefs.staggerDistanceKey, 120))
            .clamp(40, 240)
            .toInt();
    _staggerInterval =
        (await KanoPrefs.getInt(KanoPrefs.staggerIntervalKey, 30))
            .clamp(10, 80)
            .toInt();
    _staggerResponse =
        (await KanoPrefs.getInt(KanoPrefs.staggerResponseKey, 55))
            .clamp(25, 120)
            .toInt();
    _pageTransition =
        await KanoPrefs.getBool(KanoPrefs.pageTransitionKey, true);
    _predictiveBack =
        await KanoPrefs.getBool(KanoPrefs.predictiveBackKey, true);
    _themeColor = await KanoPrefs.getString(
      KanoPrefs.themeColorKey,
      defaultThemeColor,
    );
    final rawCustom = await KanoPrefs.getString(
      KanoPrefs.customBackgroundsKey,
      '',
    );
    _customBackgrounds = rawCustom.isEmpty
        ? const []
        : rawCustom.split('\n').where((e) => e.trim().isNotEmpty).toList();
    KanoPalette.applyThemeColor(_themeColor);

    // 打包主题：读 activeTheme 并解析主题目录（鸿蒙 `ThemeManager.init`）
    await KanoThemeManager.instance.load();

    KanoServer.setCustomBase(await KanoPrefs.getString(KanoPrefs.serverBaseKey, ''));
    _applyLanguage();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await KanoPrefs.setString(KanoPrefs.themeModeKey, _encodeTheme(mode));
  }

  Future<void> setLangMode(int mode) async {
    final value = mode.clamp(0, langCount - 1).toInt();
    if (value == _langMode) return;
    _langMode = value;
    _applyLanguage();
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.langModeKey, value);
  }

  Future<void> setHaptics(bool value) async {
    if (value == _haptics) return;
    _haptics = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.hapticsKey, value);
  }

  /// 打开时先向系统要通知权限。拒绝则保持关闭，并返回 false。
  Future<bool> setPushEnabled(bool value) async {
    if (value == pushEnabled) return true;
    if (value) {
      final allowed = await KanoNotifications.ensure();
      _notificationAllowed = allowed;
      if (!allowed) {
        notifyListeners();
        return false;
      }
    } else {
      _notificationAllowed = await KanoNotifications.enabled();
    }
    _pushEnabled = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.pushEnabledKey, value);
    return true;
  }

  Future<void> setPushLive(bool value) async {
    if (value == _pushLive) return;
    _pushLive = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.pushLiveKey, value);
  }

  Future<void> setPushVideo(bool value) async {
    if (value == _pushVideo) return;
    _pushVideo = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.pushVideoKey, value);
  }

  Future<void> setPushPost(bool value) async {
    if (value == _pushPost) return;
    _pushPost = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.pushPostKey, value);
  }

  Future<void> setPushLanguage(int value) async {
    final v = value.clamp(0, 4).toInt();
    if (v == _pushLanguage) return;
    _pushLanguage = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.pushLanguageKey, v);
  }

  /// 背景模糊半径（0..100，鸿蒙滑块同范围）。
  /// 实际作用到 `ImageFiltered` 时按 0.4 折算——sigma 100 在 Android 上会直接糊成卡顿。
  Future<void> setBgBlur(int value) async {
    final v = value.clamp(0, 100).toInt();
    if (v == _bgBlur) return;
    _bgBlur = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.bgBlurKey, v);
  }

  /// 遮罩不透明度（0..100 百分比），对应鸿蒙 `bgMaskOpacity`
  Future<void> setBgMask(int value) async {
    final v = value.clamp(0, 100).toInt();
    if (v == _bgMask) return;
    _bgMask = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.bgMaskKey, v);
  }

  Future<void> setBgPreset(String value) async {
    if (value == _bgPreset) return;
    _bgPreset = value;
    notifyListeners();
    await KanoPrefs.setString(KanoPrefs.bgPresetKey, value);
  }

  /// 恢复鸿蒙那套默认值
  Future<void> resetBackground() async {
    _bgBlur = 20;
    _bgMask = 80;
    _bgPreset = bgPresetSakura;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.bgBlurKey, 20);
    await KanoPrefs.setInt(KanoPrefs.bgMaskKey, 80);
    await KanoPrefs.setString(KanoPrefs.bgPresetKey, bgPresetSakura);
  }

  // ==================== 个性化 ====================

  static const defaultThemeColor = '#FFC0CB';
  static const themeColorPresets = [
    '#4F7CFF',
    '#FFC0CB',
    '#10B981',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
  ];

  Future<void> setBarHideText(bool value) async {
    if (value == _barHideText) return;
    _barHideText = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.barHideTextKey, value);
  }

  Future<void> setFlowLightMode(int value) async {
    final v = value.clamp(0, 1).toInt();
    if (v == _flowLightMode) return;
    _flowLightMode = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.flowLightModeKey, v);
  }

  Future<void> setFlowLightSpeed(int ms) async {
    final v = ms.clamp(1000, 20000).toInt();
    if (v == _flowLightSpeed) return;
    _flowLightSpeed = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.flowLightSpeedKey, v);
  }

  Future<void> setMaterialThickness(int value) async {
    final v = value.clamp(0, 4).toInt();
    if (v == _materialThickness) return;
    _materialThickness = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.materialThicknessKey, v);
  }

  Future<void> setMaterialLevel(int value) async {
    final v = value.clamp(0, 3).toInt();
    if (v == _materialLevel) return;
    _materialLevel = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.materialLevelKey, v);
  }

  Future<void> setPressColorMode(int value) async {
    final v = value.clamp(0, 1).toInt();
    if (v == _pressColorMode) return;
    _pressColorMode = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.pressColorModeKey, v);
  }

  Future<void> setStaggerEnabled(bool value) async {
    if (value == _staggerEnabled) return;
    _staggerEnabled = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.staggerEnabledKey, value);
  }

  Future<void> setStaggerDistance(int value) async {
    final v = value.clamp(40, 240).toInt();
    if (v == _staggerDistance) return;
    _staggerDistance = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.staggerDistanceKey, v);
  }

  Future<void> setStaggerInterval(int value) async {
    final v = value.clamp(10, 80).toInt();
    if (v == _staggerInterval) return;
    _staggerInterval = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.staggerIntervalKey, v);
  }

  Future<void> setStaggerResponse(int value) async {
    final v = value.clamp(25, 120).toInt();
    if (v == _staggerResponse) return;
    _staggerResponse = v;
    notifyListeners();
    await KanoPrefs.setInt(KanoPrefs.staggerResponseKey, v);
  }

  /// 恢复入场错落的四项默认值（鸿蒙 `resetStaggerEnterSettings`）
  Future<void> resetStaggerEnter() async {
    _staggerEnabled = true;
    _staggerDistance = 120;
    _staggerInterval = 30;
    _staggerResponse = 55;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.staggerEnabledKey, true);
    await KanoPrefs.setInt(KanoPrefs.staggerDistanceKey, 120);
    await KanoPrefs.setInt(KanoPrefs.staggerIntervalKey, 30);
    await KanoPrefs.setInt(KanoPrefs.staggerResponseKey, 55);
  }

  Future<void> setPageTransition(bool value) async {
    if (value == _pageTransition) return;
    _pageTransition = value;
    // 与鸿蒙一致：选「效率」时强制关掉可预测式返回
    if (!value && _predictiveBack) {
      _predictiveBack = false;
      await KanoPrefs.setBool(KanoPrefs.predictiveBackKey, false);
    }
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.pageTransitionKey, value);
  }

  Future<void> setPredictiveBack(bool value) async {
    if (value == _predictiveBack) return;
    _predictiveBack = value;
    notifyListeners();
    await KanoPrefs.setBool(KanoPrefs.predictiveBackKey, value);
  }

  Future<void> setThemeColor(String hex) async {
    final normalized = hex.toUpperCase();
    if (normalized == _themeColor) return;
    _themeColor = normalized;
    KanoPalette.applyThemeColor(normalized);
    notifyListeners();
    await KanoPrefs.setString(KanoPrefs.themeColorKey, normalized);
  }

  Future<void> addCustomBackground(String path) async {
    if (_customBackgrounds.contains(path)) return;
    _customBackgrounds = [..._customBackgrounds, path];
    notifyListeners();
    await KanoPrefs.setString(
      KanoPrefs.customBackgroundsKey,
      _customBackgrounds.join('\n'),
    );
  }

  Future<void> removeCustomBackground(String path) async {
    if (!_customBackgrounds.contains(path)) return;
    _customBackgrounds =
        _customBackgrounds.where((e) => e != path).toList(growable: false);
    if (_bgPreset == path) _bgPreset = bgPresetPlain;
    notifyListeners();
    await KanoPrefs.setString(
      KanoPrefs.customBackgroundsKey,
      _customBackgrounds.join('\n'),
    );
    await KanoPrefs.setString(KanoPrefs.bgPresetKey, _bgPreset);
  }

  /// 传空串恢复「自动」（主站优先、失败切备站）。
  Future<void> setCustomBase(String raw) async {
    final normalized = raw.trim().isEmpty ? '' : KanoServer.normalize(raw);
    KanoServer.setCustomBase(normalized);
    notifyListeners();
    await KanoPrefs.setString(KanoPrefs.serverBaseKey, normalized);
  }

  /// 切服务器 / 清缓存后调用：把内存与磁盘快照一起作废，四个页面各自下拉刷新时重拉。
  Future<void> clearCache() async {
    KanoClient.instance.clearMemory();
    await KanoCache.clear();
  }

  void _applyLanguage() {
    // KanoText 只认 0..3（简/繁/日/英），-1 是「跟随系统」；模式 0 映射到 -1，其余减一。
    KanoText.overrideLangIndex(_langMode == langFollowSystem ? -1 : _langMode - 1);
  }

  static ThemeMode _decodeTheme(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encodeTheme(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
