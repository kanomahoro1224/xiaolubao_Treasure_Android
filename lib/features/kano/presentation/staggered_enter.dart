import 'package:flutter/material.dart';

import '../../settings/settings_controller.dart';
import 'kano_motion.dart';

/// 鸿蒙 `AnimationsUtil.getStaggeredEnterEffect(order)` 的等价实现。
///
/// 那边每个列表项都挂了 `transition(...)`：元素从右侧 `staggerEnterDistance`
/// 滑入并淡入，延迟 `order * staggerEnterInterval`，弹簧参数 `staggerEnterResponse`。
/// 卡片列表用 `min(slot, 9)` 封顶，避免第 30 条要等一秒才出现。
///
/// 原来只写在个性化面板里，动态卡 / 帖子卡都没挂（鸿蒙是挂了的两边不一致），
/// 所以抽到这里给列表复用。
class StaggeredEnter extends StatefulWidget {
  const StaggeredEnter({
    required this.index,
    required this.child,
    this.enabled = true,
    this.fade = true,
    super.key,
  });

  final int index;
  final Widget child;

  /// 面板 / 卡片以外的场景（比如首帧就要静态渲染）可以关掉
  final bool enabled;

  /// 是否用 `Opacity` 淡入。
  ///
  /// 卡片毛玻璃已经改成 [KanoGlassLayer] 自绘模糊背景、不再读 backdrop，
  /// 所以 `Opacity` 的离屏层不再有副作用，这里保持 true 走鸿蒙完整的
  /// 「右滑 + 淡入」。仅在不需要淡入的特殊场景传 false。
  final bool fade;

  @override
  State<StaggeredEnter> createState() => _StaggeredEnterState();
}

class _StaggeredEnterState extends State<StaggeredEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _distance;
  late final bool _enabled;

  @override
  void initState() {
    super.initState();
    final s = SettingsController.instance;
    _distance = s.staggerDistance.toDouble();
    _enabled = widget.enabled && s.staggerEnabled;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: s.staggerResponse * 10),
    );
    if (!_enabled) {
      _controller.value = 1;
      return;
    }
    // 鸿蒙 delay 的槽位上限是 `visibleSlots * 2`；卡片这边按鸿蒙卡片自己的
    // `Math.min(slot, 9)` 收口，第 10 条之后与第 10 条同时入场。
    final slot = widget.index < 0 ? 0 : (widget.index > 9 ? 9 : widget.index);
    Future<void>.delayed(
      Duration(milliseconds: slot * s.staggerInterval),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: KanoMotion.staggerCurve(
        SettingsController.instance.staggerResponse,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final v = curve.value.clamp(0.0, 1.0);
        // 树形必须全程保持一致：不能在 v>=1 时提前返回 child。
        // 那会把 Transform 的 Element/RenderObject 摘掉，BackdropFilter 被
        // 重新挂到别的父节点 → 新建 BackdropFilterLayer → 首帧背景取样为空。
        // Transform.translate 是纯位移，RenderTransform.paint 走
        // MatrixUtils.getAsTranslation 分支，super.paint(offset+childOffset)，
        // 不创建 TransformLayer，所以 v=1 时留着它零开销。
        final slid = Transform.translate(
          offset: Offset((1 - v) * _distance, 0),
          child: child,
        );
        return widget.fade ? Opacity(opacity: v, child: slid) : slid;
      },
      child: widget.child,
    );
  }
}
