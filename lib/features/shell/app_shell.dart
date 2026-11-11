import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../home/home_edit_mode.dart';
import '../home/home_edit_overlay.dart';
import '../kano/data/kano_theme.dart';
import '../kano/presentation/kano_glass_backdrop.dart';
import '../kano/presentation/kano_motion.dart';
import '../settings/settings_controller.dart';
import '../widget/widget_snapshot.dart';
import 'app_background_layer.dart';
import 'kafuno_bottom_bar.dart';
import 'shell_tab.dart';
import 'themed_bottom_bar.dart';

/// 四页外壳：主页 / 动态 / 日程表 / 设置。
///
/// 与鸿蒙版 `Home.ets` 的 Tabs 结构一一对应：
/// - 底栏是悬浮玻璃胶囊，`body` 在它下面延伸（`extendBody`）
/// - 停用底边渐隐遮罩（鸿蒙侧显式传 `maskColor: Color.Transparent`）
/// - 编辑态时整页缩到 0.8 + 圆角 32，叠 [HomeEditOverlay]
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// 鸿蒙 `editModeScale = 0.8`；圆角 32（`borderRadius(this.isEditMode ? 32 : 0)`）
  static const double _editScale = 0.8;
  static const double _editRadius = 32;

  late final AnimationController _editController;
  late final Animation<double> _editProgress;
  late final PageController _pageController;

  bool _editing = false;

  /// 退出动画播完才拆掉的层：否则工具栏「浮出」的逆过程根本播不出来。
  bool _overlayMounted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editController = AnimationController(
      vsync: this,
      duration: KanoMotion.editMode,
    );
    _editProgress = CurvedAnimation(
      parent: _editController,
      curve: KanoMotion.editEnter,
      reverseCurve: KanoMotion.editExit,
    );
    _pageController = PageController();
    _editing = HomeEditMode.instance.active;
    _overlayMounted = _editing;
    if (_editing) _editController.value = 1;
    HomeEditMode.instance.addListener(_onEditModeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeEditMode.instance.removeListener(_onEditModeChanged);
    _pageController.dispose();
    _editController.dispose();
    super.dispose();
  }

  /// 回到前台时静默刷一次桌面小组件的数据
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) WidgetSnapshot.refresh();
  }

  /// 只做缩放与覆盖层，**不切标签页**。
  ///
  /// 鸿蒙侧 `isEditMode` 的 scale / borderRadius 挂在整个 Tabs 外层（`home_root_stack`），
  /// 设置页里的「个性化」只置 `isEditMode = true`，人在哪个页签就缩哪个页签。
  void _onEditModeChanged() {
    final active = HomeEditMode.instance.active;
    if (active == _editing) return;
    _editing = active;
    if (active) {
      if (!_overlayMounted) setState(() => _overlayMounted = true);
      _editController.forward();
      return;
    }
    _editController.reverse().whenCompleteOrCancel(() {
      // 退到一半又被拉进编辑态时不能拆层，否则刚挂上的工具条会消失
      if (!mounted || _editing || !_overlayMounted) return;
      setState(() => _overlayMounted = false);
    });
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    // 鸿蒙 Tabs 的 animationDuration = 420：整页横向滑过去，不是直接换一屏。
    // 「特效与排版 → 页面转场」选「效率」时归零，与鸿蒙 pageTransitionEnabled 一致。
    final duration = SettingsController.instance.pageTransition
        ? KanoMotion.tabSwitch
        : Duration.zero;
    if (duration == Duration.zero) {
      _pageController.jumpToPage(index);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // 换主题要换整条底栏（底图 + 图标 + 尺寸），所以主题管理器也一起听
      listenable: Listenable.merge([
        SettingsController.instance,
        KanoThemeManager.instance,
      ]),
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _editProgress,
          builder: (context, _) {
            final t = _editProgress.value.clamp(0.0, 1.0);

            // 鸿蒙 `isThemedTailBarShown()`：主题底图只在手机宽度下铺。
            // tail_bg 是 5:1 的整幅画，Cover 铺满宽屏只会剩中间一条，
            // 所以平板（宽 ≥ 600vp）退回玻璃浮岛，页签仍是同一组按钮。
            final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
            final themedPhone = KanoThemeManager.instance.hasActive &&
                MediaQuery.sizeOf(context).width < 600;

            final shell = GlassScaffold(
              edgeToEdge: true,
              extendBody: true,
              statusBarStyle: GlassStatusBarStyle.auto,
              // 毛玻璃不再向合成器读 backdrop，改成抓这张背景的模糊快照。
              // 流光/视频壁纸是动的，需要每帧重抓；静态壁纸只在偏好变化时抓一次。
              background: KanoGlassCapture(
                animated: SettingsController.instance.flowLightMode != 0 ||
                    isVideoPath(SettingsController.instance.bgPreset),
                child: const AppBackgroundLayer(),
              ),
              // 主题底栏要额外让出图标上提的 50，否则内容会压到贴纸上
              bottomBarHeight:
                  themedPhone ? ThemedBottomBar.heightFor(safeBottom) : 88,
              bottomEdgeFade: false,
              bottomEdgeFadeExtent: 36,
              // 编辑态收起底栏：鸿蒙的编辑覆盖层下面同样不给底部导航留位置。
              // 用透明度收放而不是直接 null，退出缩放时底栏是渐显而不是突然冒出。
              bottomBar: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: IgnorePointer(
                  ignoring: _overlayMounted,
                  child: themedPhone
                      ? ThemedBottomBar(
                          selectedIndex: _selectedIndex,
                          onTabSelected: _select,
                        )
                      : KafunoBottomBar(
                          selectedIndex: _selectedIndex,
                          onTabSelected: _select,
                        ),
                ),
              ),
              body: SafeArea(
                bottom: false,
                // PageView 承载四页：手势关掉（日程表自己要横滑切月份），
                // 只由底栏驱动 420ms 的整页横滑；四页都挂了 KeepAlive 保状态
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final tab in ShellTab.values) tab.screen,
                  ],
                ),
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // 缩小后四周露出来的底：只在有过缩放时画（少一层全屏模糊）。
                // 这里不再播一遍视频壁纸，两路解码没必要。
                if (t > 0) const AppBackgroundLayer(allowVideo: false),
                // 先按圆角裁剪再整体缩放：视觉半径 32 * 0.8，与鸿蒙
                // `.scale(...).borderRadius(32).clip(true)` 的属性叠加一致
                Transform.scale(
                  scale: 1 - (1 - _editScale) * t,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_editRadius * t),
                    child: shell,
                  ),
                ),
                // 编辑覆盖层在缩放容器**外面**：鸿蒙里 `if (this.isEditMode)` 与
                // `home_root_stack` 是兄弟节点（Stack 在 8855 闭合，覆盖层从 8897 开始），
                // 所以返回按钮和三个工具按全屏坐标摆，不跟着页面缩。
                if (_overlayMounted) HomeEditOverlay(progress: t),
              ],
            );
          },
        );
      },
    );
  }
}
