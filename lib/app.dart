import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/settings_controller.dart';
import 'features/shell/app_shell.dart';

/// 应用根。
///
/// 设置页改主题/语言后由 [SettingsController] 通知这里重建：
/// MaterialApp 换 `themeMode` 与 `locale`，四个页面不需要各自监听，
/// 因为它们本来就挂着 `KanoPalette.of(context)`，重建一次就全换了。
class KafunoApp extends StatelessWidget {
  const KafunoApp({super.key});

  /// 语言模式 → MaterialApp locale。0 跟随系统时返回 null，交给系统判定。
  static Locale? _localeOf(int mode) => switch (mode) {
        1 => const Locale('zh', 'CN'),
        2 => const Locale('zh', 'Hant'),
        3 => const Locale('ja'),
        4 => const Locale('en'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final settings = SettingsController.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        title: '小鹿包们的宝物',
        debugShowCheckedModeBanner: false,
        theme: KafunoTheme.light(),
        darkTheme: KafunoTheme.dark(),
        themeMode: settings.themeMode,
        locale: _localeOf(settings.langMode),
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'Hant'),
          Locale('ja'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // `GlassScaffold` 替代了 `Scaffold`，而整个 liquid_glass_widgets 里
        // 没有任何 `Material`，`MaterialApp` 自己也不提供 —— 结果所有 `Text`
        // 都落在 `DefaultTextStyle.fallback` 上，那是「黄色 + 双下划线」的兜底样式。
        // 这里补一层透明 Material，把排版基线还给主题。
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AppShell(),
      ),
    );
  }
}
