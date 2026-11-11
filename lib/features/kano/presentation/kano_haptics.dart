import 'package:flutter/services.dart';

import '../../settings/settings_controller.dart';

/// 触感反馈的统一入口。
///
/// 设置页有一项「触感反馈」开关，散在各页面的 `HapticFeedback.selectionClick()`
/// 不该各自判断偏好，统一从这里出。系统层关闭触觉时这些调用本身是空操作，不用额外处理。
class KanoHaptics {
  KanoHaptics._();

  static bool get _on => SettingsController.instance.haptics;

  /// 选中、切换、翻页这类轻反馈。
  static void select() {
    if (!_on) return;
    HapticFeedback.selectionClick();
  }

  /// 按钮按下、卡片打开。
  static void tap() {
    if (!_on) return;
    HapticFeedback.lightImpact();
  }

  /// 出错、删除、清空这类需要一点分量的。
  static void warn() {
    if (!_on) return;
    HapticFeedback.mediumImpact();
  }
}
