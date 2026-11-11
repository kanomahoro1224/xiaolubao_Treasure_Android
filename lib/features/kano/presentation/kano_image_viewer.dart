import 'package:flutter/material.dart';

/// 全屏大图：黑底 + Contain，多图左右滑，双指放大（缩放时禁掉翻页）。
class KanoImageViewer extends StatefulWidget {
  const KanoImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> show(BuildContext context, List<String> urls, int index) {
    if (urls.isEmpty) return Future<void>.value();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => KanoImageViewer(
          urls: urls,
          initialIndex: index.clamp(0, urls.length - 1),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<KanoImageViewer> createState() => _KanoImageViewerState();
}

class _KanoImageViewerState extends State<KanoImageViewer> {
  late final PageController _controller;
  late final TransformationController _transform;
  late int _index;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    _transform = TransformationController()..addListener(_onTransform);
  }

  /// 鸿蒙是 `disableSwipe(this.viewerScale > 1.02)`：只有真的放大了才禁翻页。
  /// 之前这里一碰就置 true 且永不回落，缩回 1x 之后仍然翻不动页。
  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            onPageChanged: (i) {
              // 换页回到 1x，否则上一页的缩放会带到下一张
              _transform.value = Matrix4.identity();
              setState(() => _index = i);
            },
            itemCount: widget.urls.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.urls[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                          ),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 关闭按钮：鸿蒙是 36×36 圆、rgba(255,255,255,0.18) 底、17 号叉
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Color(0x2EFFFFFF), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
              ),
            ),
          ),
          // 页码在**底部**（鸿蒙 padding bottom 40），胶囊底 + 13 号白字
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
