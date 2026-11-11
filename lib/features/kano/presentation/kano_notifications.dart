import 'package:flutter/services.dart';

/// 系统通知权限。
///
/// 鸿蒙「接收推送」走 Push Kit。Android 这边没有同一套推送后端，
/// 打开总开关时只做系统通知权限申请，避免摆一个点了没反应的空开关。
/// 分类偏好存在 [SettingsController]，真正的远端推送没有在这里发明。
class KanoNotifications {
  KanoNotifications._();

  static const _channel = MethodChannel('kano/notifications');

  /// 已授权或系统版本不需要运行时权限时返回 true。
  static Future<bool> ensure() async {
    try {
      final ok = await _channel.invokeMethod<bool>('ensure');
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 系统通知是否还开着。通道不可用时不把已保存的开关打成关。
  static Future<bool> enabled() async {
    try {
      final ok = await _channel.invokeMethod<bool>('enabled');
      return ok == true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }
}
