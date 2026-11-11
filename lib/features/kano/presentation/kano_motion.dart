import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// 鸿蒙 `@ohos.curves` 的 Flutter 等价物。
///
/// 鸿蒙侧几乎每条自定义动画都写成 `curves.springMotion(response, dampingFraction)`：
/// - `response`：弹簧响应时长（秒），越大越慢
/// - `dampingFraction`：阻尼比，1.0 = 临界阻尼（不回弹），小于 1 会轻微过冲
///
/// Flutter 没有同名 API，这里按二阶欠阻尼系统的阶跃响应直接算位移曲线，
/// 参数语义与鸿蒙一一对应，改参数不用再猜「这条曲线等价多少 easeOut」。
abstract final class KanoMotion {
  /// 鸿蒙 `Home.ets` 的 `bottomTabSwitchDuration`
  static const Duration tabSwitch = Duration(milliseconds: 420);

  /// 编辑态缩放：鸿蒙 `.animation({ duration: 400, curve: springMotion(0.6, 0.8) })`
  static const Duration editMode = Duration(milliseconds: 400);

  /// 进入编辑态：`curves.springMotion(0.6, 0.8)`
  static const Curve editEnter = SpringMotionCurve(
    response: 0.6,
    dampingFraction: 0.8,
    durationMs: 400,
  );

  /// 退出编辑态：`curves.springMotion(0.6, 0.9)`，反向播放要镜像才是「归位」手感
  static const Curve editExit = MirroredCurve(
    SpringMotionCurve(response: 0.6, dampingFraction: 0.9, durationMs: 400),
  );

  /// 覆盖层面板升起：鸿蒙 `TransitionEffect.move(BOTTOM).combine(OPACITY)`
  static const Duration sheet = Duration(milliseconds: 260);
  static const Curve sheetCurve = SpringMotionCurve(
    response: 0.45,
    dampingFraction: 0.9,
    durationMs: 260,
  );

  /// 页面 / 覆盖层入场：`AnimationsUtil.PAGE_SPRING_CURVE = springMotion(0.5, 1.0)`
  static const Duration pageEnter = Duration(milliseconds: 280);
  static const Curve pageSpring = SpringMotionCurve(
    response: 0.5,
    dampingFraction: 1.0,
    durationMs: 280,
  );

  /// 列表项错落入场：`AnimationsUtil.getStaggeredEnterEffect`
  static Duration staggerDelay(int index, int intervalMs) =>
      Duration(milliseconds: index * intervalMs);

  static Curve staggerCurve(int responseCs) => SpringMotionCurve(
        response: responseCs / 100,
        dampingFraction: 0.82,
        durationMs: responseCs * 10.0,
      );
}

/// `curves.springMotion(response, dampingFraction)` 的数学等价实现。
class SpringMotionCurve extends Curve {
  const SpringMotionCurve({
    required this.response,
    this.dampingFraction = 0.8,
    required this.durationMs,
  });

  /// 响应时长（秒）。
  final double response;

  /// 阻尼比。
  final double dampingFraction;

  /// 曲线所挂动画的总时长（毫秒）：归一化时间要乘回真实秒数才符合弹簧物理。
  final double durationMs;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;

    final seconds = t * durationMs / 1000.0;
    final omega0 = 2 * math.pi / response;
    final zeta = dampingFraction;

    // 临界阻尼 / 过阻尼：不振荡
    if (zeta >= 1) {
      final decay = math.exp(-omega0 * seconds);
      return (1 - decay * (1 + omega0 * seconds)).clamp(0.0, 1.0);
    }

    final omegaD = omega0 * math.sqrt(1 - zeta * zeta);
    final decay = math.exp(-zeta * omega0 * seconds);
    final value = 1 -
        decay *
            (math.cos(omegaD * seconds) +
                (zeta * omega0 / omegaD) * math.sin(omegaD * seconds));
    // 欠阻尼天然有少量过冲，留一点余量给弹簧感，但不能失控
    return value.clamp(0.0, 1.02);
  }
}

/// 曲线的时间镜像。
///
/// `AnimationController.reverse()` 让动画值从 1 走到 0，直接把原曲线套上去会变成
/// 「先慢后快」。镜像成 `1 - curve(1 - t)` 之后，反向播放才是弹簧归位的手感。
class MirroredCurve extends Curve {
  const MirroredCurve(this.inner);

  final Curve inner;

  @override
  double transformInternal(double t) => 1 - inner.transform(1 - t);
}
