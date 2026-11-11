import 'package:flutter/foundation.dart';

/// 首页编辑态。
///
/// 对应鸿蒙 `Home.ets` 的 `@StorageLink('isEditMode')`：
/// 进编辑态后首页整体缩到 0.8、圆角 32，左上角出现返回按钮，
/// 底部换成「壁纸 / 效果 / 主题」三个工具。
///
/// 鸿蒙有两个入口：首页双指捏合（`event.scale < 0.85`）和设置页的「个性化」。
/// 这里两个都接上了。
class HomeEditMode extends ChangeNotifier {
  HomeEditMode._();

  static final HomeEditMode instance = HomeEditMode._();

  bool _active = false;

  bool get active => _active;

  void enter() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void exit() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }

  void toggle() => _active ? exit() : enter();
}
