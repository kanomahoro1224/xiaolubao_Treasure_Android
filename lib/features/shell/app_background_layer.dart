import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../kano/data/kano_theme.dart';
import '../settings/settings_controller.dart';

/// 背景 uri 是不是视频（鸿蒙用 `backgroundType` 区分，这里按扩展名判断，
/// 因为选视频和选图片都走同一个相册入口）。
bool isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.avi');
}

/// 首页/全局背景，对应鸿蒙 `Home.ets` 的 `HomeEmbeddedBackground`：
///
/// ```ts
/// if (backgroundType === 1 && homeVideoBg) Video({ src: homeVideoBg })
/// else if (homeBackground) Image(uri).objectFit(Cover)
/// else Rect().fill(浅 #F1F3F5 / 深 #000000)
/// this.BgMaskOverlay()   // 白/黑整层，opacity = bgMaskOpacity
/// ```
///
/// 背景来源有四种：默认纯色 / 内置樱花壁纸 / 用户选的图片 / 用户选的视频；
/// 都接到「个性化 → 壁纸」里，改完立刻可见。
class AppBackgroundLayer extends StatefulWidget {
  const AppBackgroundLayer({super.key, this.allowVideo = true});

  /// 编辑态缩小后垫在下面的那层不需要再播一遍视频
  final bool allowVideo;

  /// 鸿蒙 `PRESET_WALLPAPER_KADO`
  static const String presetWallpaper = 'assets/images/kado_sakura21.png';

  @override
  State<AppBackgroundLayer> createState() => _AppBackgroundLayerState();
}

class _AppBackgroundLayerState extends State<AppBackgroundLayer> {
  VideoPlayerController? _video;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    SettingsController.instance.addListener(_syncVideo);
    // 换主题要停掉视频壁纸（鸿蒙 `syncAppliedThemeBackground` 会清 homeVideoBg）
    KanoThemeManager.instance.addListener(_syncVideo);
    _syncVideo();
  }

  @override
  void dispose() {
    SettingsController.instance.removeListener(_syncVideo);
    KanoThemeManager.instance.removeListener(_syncVideo);
    _video?.dispose();
    super.dispose();
  }

  void _syncVideo() {
    final path = SettingsController.instance.bgPreset;
    // 主题生效时底图由主题包接管，用户壁纸（含视频）不再参与渲染
    final wantVideo = widget.allowVideo &&
        !KanoThemeManager.instance.hasActive &&
        isVideoPath(path);

    if (!wantVideo) {
      if (_video != null) {
        _video!.dispose();
        _video = null;
        _videoPath = null;
        if (mounted) setState(() {});
      }
      return;
    }
    if (_videoPath == path) return;

    _video?.dispose();
    _videoPath = path;
    final controller = VideoPlayerController.file(File(path));
    _video = controller;
    controller.initialize().then((_) async {
      if (!mounted || _video != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    }).catchError((Object error) {
      debugPrint('video background init failed: $error');
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // 主题切换也要换底图（鸿蒙 `syncAppliedThemeBackground`），
      // 所以两个 notifier 一起听
      listenable: Listenable.merge([
        SettingsController.instance,
        KanoThemeManager.instance,
      ]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final settings = SettingsController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = settings.bgPreset;
    // 主题生效时底图走主题包（鸿蒙 `getAppliedThemeBackground()`：
    // backgroundPath || previewPath || coverPath），否则用用户自己的壁纸
    final themeBackground = KanoThemeManager.instance.activeBackground;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (themeBackground != null)
          _themeBase(themeBackground, isDark)
        else
          _base(preset, isDark),
        // 遮罩：浅色白纱、深色黑纱，压在背景上
        ColoredBox(
          color: (isDark ? Colors.black : Colors.white)
              .withValues(alpha: settings.bgMaskOpacity),
        ),
        // 流光：鸿蒙默认关（flowLightMode = 0），打开后才挂
        if (settings.flowLightMode != 0) _FlowLight(speedMs: settings.flowLightSpeed),
      ],
    );
  }

  /// 主题包底图：不加模糊——主题自带成图，糊一层就废了。
  Widget _themeBase(String path, bool isDark) {
    final provider = KanoThemeManager.instance.active?.providerOf(path);
    final fallback = ColoredBox(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F3F5),
    );
    if (provider == null) return fallback;
    return Image(
      image: provider,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _base(String preset, bool isDark) {
    // 鸿蒙滑块 0..100；这里折半换算成 sigma，100 全量作用会直接糊成卡顿
    final blur = SettingsController.instance.bgBlur * 0.4;

    if (preset == SettingsController.bgPresetPlain) {
      return ColoredBox(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F3F5),
      );
    }

    final Widget content;
    if (preset == SettingsController.bgPresetSakura) {
      content = Image.asset(
        AppBackgroundLayer.presetWallpaper,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
    } else if (isVideoPath(preset)) {
      final video = _video;
      if (video != null && video.value.isInitialized) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          ),
        );
      }
      return ColoredBox(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F3F5),
      );
    } else {
      content = Image.file(
        File(preset),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F3F5),
        ),
      );
    }

    if (blur <= 0) return content;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: content,
    );
  }
}

/// 流光：一条斜向的柔和光带循环扫过，速度由 `flowLightSpeed`（毫秒/轮）控制。
/// 鸿蒙这个开关默认关，界面上的「下划线观感」就是它造成的，所以只在用户主动
/// 打开时才画，且透明度压得很低。
class _FlowLight extends StatefulWidget {
  const _FlowLight({required this.speedMs});

  final int speedMs;

  @override
  State<_FlowLight> createState() => _FlowLightState();
}

class _FlowLightState extends State<_FlowLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.speedMs.clamp(1000, 20000)),
    )..repeat();
  }

  @override
  void didUpdateWidget(_FlowLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedMs != widget.speedMs) {
      _controller.duration =
          Duration(milliseconds: widget.speedMs.clamp(1000, 20000));
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final x = (width * 1.6) * _controller.value - width * 0.3;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: -height * 0.2,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        width: width * 0.28,
                        height: height * 1.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
