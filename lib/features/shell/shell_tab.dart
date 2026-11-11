import 'package:flutter/cupertino.dart';

import '../feed/feed_page.dart';
import '../home/home_page.dart';
import '../kano/domain/kano_text.dart';
import '../schedule/schedule_page.dart';
import '../settings/settings_page.dart';

/// 底栏四项，顺序与鸿蒙版 `Home.ets` 的 `getVisibleBottomTabs` 一致：
/// 主页 / 动态 / 日程表 / 设置。
enum ShellTab {
  home,
  feed,
  schedule,
  settings;

  /// 底栏文字走四语文案表，key 与鸿蒙 `tab_*` 资源名一致。
  String get label => switch (this) {
        ShellTab.home => KanoText.ui('tab_home'),
        ShellTab.feed => KanoText.ui('tab_feed'),
        ShellTab.schedule => KanoText.ui('tab_schedule'),
        ShellTab.settings => KanoText.ui('tab_settings'),
      };

  /// 鸿蒙侧对应的页面文件，便于回溯对照。
  String get arktsSource => switch (this) {
        ShellTab.home => 'RecentPage.ets',
        ShellTab.feed => 'FeedPage.ets',
        ShellTab.schedule => 'SchedulePage.ets',
        ShellTab.settings => 'SettingsPage.ets',
      };

  IconData get icon => switch (this) {
        ShellTab.home => CupertinoIcons.house,
        ShellTab.feed => CupertinoIcons.rectangle_stack,
        ShellTab.schedule => CupertinoIcons.calendar,
        ShellTab.settings => CupertinoIcons.gear,
      };

  IconData get activeIcon => switch (this) {
        ShellTab.home => CupertinoIcons.house_fill,
        ShellTab.feed => CupertinoIcons.rectangle_stack_fill,
        ShellTab.schedule => CupertinoIcons.calendar,
        ShellTab.settings => CupertinoIcons.gear_solid,
      };

  /// 主题包底栏图标的键，对应鸿蒙 `getBottomTabThemeIconKey`：
  /// 首页 main、动态 dynamic、频道 channel、商店 shop、我的 myself。
  /// 这个 App 没有频道与商店页，日程沿用 channel、设置沿用 myself。
  String get themeIconKey => switch (this) {
        ShellTab.home => 'main',
        ShellTab.feed => 'dynamic',
        ShellTab.schedule => 'channel',
        ShellTab.settings => 'myself',
      };

  Widget get screen => switch (this) {
        ShellTab.home => const HomePage(),
        ShellTab.feed => const FeedPage(),
        ShellTab.schedule => const SchedulePage(),
        ShellTab.settings => const SettingsPage(),
      };
}
