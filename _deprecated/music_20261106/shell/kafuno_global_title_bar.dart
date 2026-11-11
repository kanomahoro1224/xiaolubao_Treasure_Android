import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'floating_bar_metrics.dart';

class KafunoGlobalTitleBar extends StatelessWidget {
  const KafunoGlobalTitleBar({super.key, this.onSearchTap, this.onMenuTap});

  final VoidCallback? onSearchTap;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final horizontalPadding = MediaQuery.sizeOf(context).width * 0.03;

    return Positioned(
      top: safeTop,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _SearchMiniBar(onTap: onSearchTap),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _MenuMiniButton(onTap: onMenuTap),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMiniBar extends StatefulWidget {
  const _SearchMiniBar({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_SearchMiniBar> createState() => _SearchMiniBarState();
}

class _SearchMiniBarState extends State<_SearchMiniBar> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final contentColor = isLight ? Colors.black : Colors.white;

    return GlassGlow(
      clipper: ShapeBorderClipper(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      glowColor: Colors.white.withValues(alpha: FloatingBarMetrics.glowAlpha),
      glowRadius: FloatingBarMetrics.glowRadius,
      hitTestBehavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          settings: LiquidGlassSettings(
            blur: 4,
            thickness: _isPressed ? 22 : 18,
            lightIntensity: _isPressed ? 0.9 : 0.6,
            ambientStrength: _isPressed ? 1.0 : 0.72,
            glassColor: Colors.white.withValues(alpha: 0.18),
          ),
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(CupertinoIcons.search, size: 18, color: contentColor.withValues(alpha: 0.60)),
                  const SizedBox(width: 8),
                  Text(
                    '搜索歌曲...',
                    style: TextStyle(
                      color: contentColor.withValues(alpha: 0.50),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuMiniButton extends StatefulWidget {
  const _MenuMiniButton({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_MenuMiniButton> createState() => _MenuMiniButtonState();
}

class _MenuMiniButtonState extends State<_MenuMiniButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    return GlassGlow(
      clipper: ShapeBorderClipper(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      glowColor: Colors.white.withValues(alpha: FloatingBarMetrics.glowAlpha),
      glowRadius: FloatingBarMetrics.glowRadius,
      hitTestBehavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          settings: LiquidGlassSettings(
            blur: 4,
            thickness: _isPressed ? 22 : 18,
            lightIntensity: _isPressed ? 0.9 : 0.6,
            ambientStrength: _isPressed ? 1.0 : 0.72,
            glassColor: Colors.white.withValues(alpha: 0.18),
          ),
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Transform.translate(
              offset: const Offset(-2, 0),
              child: Icon(CupertinoIcons.line_horizontal_3, size: 24, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
