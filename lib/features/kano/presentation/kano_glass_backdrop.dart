import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../settings/settings_controller.dart';
import '../data/kano_theme.dart';

/// 整屏背景的「模糊快照」。
///
/// 之前卡片各自挂 `BackdropFilter`，那是**向合成器读当前 framebuffer 已画内容**：
/// 只要卡片上方的 layer 树有变化（`OpacityLayer` / 父节点重挂 / 滚动视口重排），
/// 读取就会失效，毛玻璃闪一下甚至彻底消失。鸿蒙 `backgroundBlurStyle` 是材质层，
/// 不会有这个问题。
///
/// 这里换成自绘：把整屏背景抓成一张 `ui.Image`，预先高斯模糊一次，卡片只按
/// 自己在屏幕上的位置从这张图里裁一块出来画。**不读 backdrop**，所以滚动、
/// 动画、图层重排都不可能影响它 —— 毛玻璃从结构上保证一直在。
class KanoGlassBackdrop extends ChangeNotifier {
  KanoGlassBackdrop._();

  static final KanoGlassBackdrop instance = KanoGlassBackdrop._();

  /// 卡片默认 sigma；全项目 `KanoSurface` 都没传 `blur`，所以只需一张。
  static const double sigma = 18;

  ui.Image? _blurred;
  ui.Image? get blurred => _blurred;

  /// 预模糊失败时为 true：卡片改用 `Paint.imageFilter` 现场模糊，
  /// 慢一点但毛玻璃照样在，不会因为 API 不可用就退化成纯色块。
  bool liveBlur = false;

  /// 每换一张模糊图就 +1；RenderObject 用它判断是否需要重绘。
  int revision = 0;

  /// 用 [raw] 生成模糊图。旧图延迟一帧释放，避免正在绘制的 frame 还引用它。
  void publish(ui.Image raw) {
    ui.Image next;
    bool live;
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      // mirror 让模糊核在图像边缘取镜像像素，不会因采样到透明而出现暗边
      final ui.Paint paint = ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.mirror,
        );
      canvas.drawImage(raw, Offset.zero, paint);
      final ui.Picture picture = recorder.endRecording();
      next = picture.toImageSync(raw.width, raw.height);
      picture.dispose();
      live = false;
    } catch (_) {
      // 某些 GPU 后端不支持离屏栅格化：退回原图 + 绘制时现场模糊
      next = raw;
      live = true;
    }

    final ui.Image? old = _blurred;
    liveBlur = live;
    _blurred = next;
    revision++;
    notifyListeners();
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    if (!live) {
      WidgetsBinding.instance.addPostFrameCallback((_) => raw.dispose());
    }
  }

  /// 每帧都通知一次：卡片滚动后位置变了，需要按新位置重新裁图。
  /// 只有一次 `drawImageRect`，没有模糊计算，开销可忽略。
  void tick() => notifyListeners();
}

/// 包在背景层外面，负责抓图。
///
/// 静态壁纸只在背景变化时抓一次；流光 / 视频壁纸每帧重抓。无论哪种，
/// 每帧都会 `tick()` 让卡片按最新位置重绘。
class KanoGlassCapture extends StatefulWidget {
  const KanoGlassCapture({
    required this.child,
    required this.animated,
    super.key,
  });

  final Widget child;
  final bool animated;

  @override
  State<KanoGlassCapture> createState() => _KanoGlassCaptureState();
}

class _KanoGlassCaptureState extends State<KanoGlassCapture> {
  final GlobalKey _key = GlobalKey();
  bool _dirty = true;
  bool _alive = true;
  int _lastCaptureMs = 0;

  @override
  void initState() {
    super.initState();
    SettingsController.instance.addListener(_invalidate);
    KanoThemeManager.instance.addListener(_invalidate);
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _invalidate() {
    if (mounted) _dirty = true;
  }

  void _onFrame(Duration _) {
    if (!_alive) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    // 视频/流光壁纸是动的，要重抓；但每帧做一次全屏高斯模糊太重，压到 ~20fps。
    // 静态壁纸只在偏好变化时抓一次（_dirty）。
    if (_dirty || (widget.animated && now - _lastCaptureMs >= 50)) {
      _capture();
      _lastCaptureMs = now;
    }
    KanoGlassBackdrop.instance.tick();
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _capture() {
    final Object? object = _key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return;
    ui.Image? raw;
    try {
      // pixelRatio 1.0 → 图的 1 像素 = 1 逻辑像素，正好对上 RenderBox 的全局坐标
      raw = object.toImageSync(pixelRatio: 1.0);
      KanoGlassBackdrop.instance.publish(raw);
      raw = null; // publish 接管释放
      _dirty = false;
    } catch (error) {
      // layer 还没就绪，下一帧再试
      raw?.dispose();
      debugPrint('glass capture retry: $error');
    }
  }

  @override
  void didUpdateWidget(KanoGlassCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated || oldWidget.child != widget.child) {
      _dirty = true;
    }
  }

  @override
  void dispose() {
    _alive = false;
    SettingsController.instance.removeListener(_invalidate);
    KanoThemeManager.instance.removeListener(_invalidate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _key, child: widget.child);
  }
}

/// 在 child 底下画一层「从整屏模糊背景里按自身位置裁出来」的图。
/// 自定义 RenderObject 才能在 paint 阶段拿到 `localToGlobal`。
class KanoGlassLayer extends SingleChildRenderObjectWidget {
  const KanoGlassLayer({required super.child, super.key});

  @override
  RenderKanoGlass createRenderObject(BuildContext context) => RenderKanoGlass();

  @override
  void updateRenderObject(BuildContext context, RenderKanoGlass renderObject) {}
}

class RenderKanoGlass extends RenderProxyBox {
  RenderKanoGlass();

  int _lastRevision = -1;
  Offset? _lastGlobal;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    KanoGlassBackdrop.instance.addListener(_onChange);
  }

  @override
  void detach() {
    KanoGlassBackdrop.instance.removeListener(_onChange);
    super.detach();
  }

  /// 只在「模糊图换了」或「自己滚动到了新位置」时重绘。
  /// 静态壁纸 + 静止列表 = 零额外重绘，不会让整机一直满帧。
  void _onChange() {
    if (!attached) return;
    final KanoGlassBackdrop backdrop = KanoGlassBackdrop.instance;
    if (backdrop.revision != _lastRevision) {
      _lastRevision = backdrop.revision;
      markNeedsPaint();
      return;
    }
    final Offset now;
    try {
      now = localToGlobal(Offset.zero);
    } catch (_) {
      return;
    }
    if (_lastGlobal != now) {
      _lastGlobal = now;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final KanoGlassBackdrop backdrop = KanoGlassBackdrop.instance;
    final ui.Image? image = backdrop.blurred;
    if (image != null && size.width > 0 && size.height > 0) {
      Offset global;
      try {
        global = localToGlobal(Offset.zero);
      } catch (_) {
        global = offset;
      }
      _lastGlobal = global;
      _lastRevision = backdrop.revision;
      final Rect src = Rect.fromLTWH(global.dx, global.dy, size.width, size.height);
      final Rect dst = offset & size;
      final _Clipped? clipped = _clipToImage(src, dst, image);
      if (clipped != null) {
        final ui.Paint paint = ui.Paint();
        if (backdrop.liveBlur) {
          paint.imageFilter = ui.ImageFilter.blur(
            sigmaX: KanoGlassBackdrop.sigma,
            sigmaY: KanoGlassBackdrop.sigma,
            tileMode: ui.TileMode.mirror,
          );
        }
        context.canvas.drawImageRect(image, clipped.src, clipped.dst, paint);
      }
    }
    super.paint(context, offset);
  }

  /// 卡片滚出屏幕边缘时 src 会越界，裁到图内并同步裁 dst，避免拉伸错位。
  static _Clipped? _clipToImage(Rect src, Rect dst, ui.Image image) {
    final double w = image.width.toDouble();
    final double h = image.height.toDouble();
    final double l = src.left.clamp(0.0, w);
    final double t = src.top.clamp(0.0, h);
    final double r = src.right.clamp(0.0, w);
    final double b = src.bottom.clamp(0.0, h);
    if (r <= l || b <= t) return null;
    final double sx = dst.width / src.width;
    final double sy = dst.height / src.height;
    return _Clipped(
      Rect.fromLTRB(l, t, r, b),
      Rect.fromLTRB(
        dst.left + (l - src.left) * sx,
        dst.top + (t - src.top) * sy,
        dst.left + (r - src.left) * sx,
        dst.top + (b - src.top) * sy,
      ),
    );
  }
}

class _Clipped {
  const _Clipped(this.src, this.dst);

  final Rect src;
  final Rect dst;
}
