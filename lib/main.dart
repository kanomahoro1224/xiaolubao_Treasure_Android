import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'features/settings/settings_controller.dart';
import 'features/widget/widget_snapshot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  // 先读偏好再建树：语言/主题/服务器地址要在首帧就位，否则会闪一下默认值。
  await SettingsController.instance.load();

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      child: const KafunoApp(),
    ),
  );

  // 首帧之后再刷桌面小组件：这一步要联网，不能挡启动
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetSnapshot.refresh();
  });
}
