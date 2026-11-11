import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/models/song.dart';
import 'floating_bar_metrics.dart';

class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({
    super.key,
    this.song,
    this.isPlaying = false,
    this.onOpenPlayer,
  });

  final Song? song;
  final bool isPlaying;
  final VoidCallback? onOpenPlayer;

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  bool _showPlaylist = false;
  bool _showMiniLyrics = false;
  bool _isPressed = false;
  int _playMode = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: SizedBox(
            width: FloatingBarMetrics.widthFor(context),
            height: FloatingBarMetrics.miniPlayerHeight,
            child: GlassGlow(
                clipper: ShapeBorderClipper(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                glowColor: Colors.white.withValues(alpha: FloatingBarMetrics.glowAlpha),
                glowRadius: FloatingBarMetrics.glowRadius,
                hitTestBehavior: HitTestBehavior.translucent,
                child: Listener(
                  onPointerDown: (_) => setState(() => _isPressed = true),
                  onPointerUp: (_) => setState(() => _isPressed = false),
                  onPointerCancel: (_) => setState(() => _isPressed = false),
                  child: AnimatedScale(
                    scale: _isPressed ? 1.018 : 1.0,
                    duration: FloatingBarMetrics.pressDuration,
                    curve: Curves.easeOutCubic,
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
                      shape: const LiquidRoundedSuperellipse(borderRadius: 26),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(26),
                        onTap: widget.onOpenPlayer,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              _CoverButton(
                                showMiniLyrics: _showMiniLyrics,
                                onToggleLyrics: () => setState(() => _showMiniLyrics = !_showMiniLyrics),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _showMiniLyrics
                                      ? const _MiniLyricsLine(key: ValueKey('lyrics'))
                                      : _MiniSongInfo(
                                          key: const ValueKey('song-info'),
                                          song: widget.song ?? mockSongs.first,
                                        ),
                                ),
                              ),
                              _MiniIconButton(
                                tooltip: _playModeLabel,
                                onPressed: () => setState(() => _playMode = (_playMode + 1) % 4),
                                icon: Icon(_playModeIcon, size: 22),
                              ),
                              _MiniIconButton(
                                onPressed: () {},
                                icon: Icon(widget.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 22),
                              ),
                              _MiniIconButton(
                                onPressed: () => setState(() => _showPlaylist = !_showPlaylist),
                                icon: const Icon(CupertinoIcons.list_bullet, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_showPlaylist)
          Positioned(
            left: 18,
            right: 18,
            bottom: 76,
            child: _PlaylistSheet(
              playModeLabel: _playModeLabel,
              playModeIcon: _playModeIcon,
              onTogglePlayMode: () => setState(() => _playMode = (_playMode + 1) % 4),
              onClose: () => setState(() => _showPlaylist = false),
            ),
          ),
      ],
    );
  }

  IconData get _playModeIcon => switch (_playMode) {
        0 => CupertinoIcons.chevron_right,
        1 => CupertinoIcons.repeat_1,
        2 => CupertinoIcons.repeat,
        _ => CupertinoIcons.shuffle,
      };

  String get _playModeLabel => switch (_playMode) {
        0 => '顺序播放',
        1 => '单曲循环',
        2 => '列表循环',
        _ => '随机播放',
      };
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.onPressed, required this.icon, this.tooltip});

  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: icon,
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.showMiniLyrics, required this.onToggleLyrics});

  final bool showMiniLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleLyrics,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB6D1), Color(0xFF9FD7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(CupertinoIcons.music_note_2, color: Colors.white),
          ),
          if (showMiniLyrics)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.28),
              ),
              child: const Icon(CupertinoIcons.quote_bubble_fill, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }
}

class _MiniSongInfo extends StatelessWidget {
  const _MiniSongInfo({required this.song, super.key});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.heart,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.58), fontSize: 11, height: 1.0),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: 0.38,
            minHeight: 2,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }
}

class _MiniLyricsLine extends StatelessWidget {
  const _MiniLyricsLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '听见生活的声音',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _PlaylistSheet extends StatelessWidget {
  const _PlaylistSheet({
    required this.playModeLabel,
    required this.playModeIcon,
    required this.onTogglePlayMode,
    required this.onClose,
  });

  final String playModeLabel;
  final IconData playModeIcon;
  final VoidCallback onTogglePlayMode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      settings: LiquidGlassSettings(
        blur: 5,
        thickness: 24,
        glassColor: Colors.white.withValues(alpha: 0.20),
      ),
      shape: const LiquidRoundedSuperellipse(borderRadius: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('播放列表', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        '${mockSongs.length} 首歌曲',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.58)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onTogglePlayMode,
                  icon: Icon(playModeIcon, size: 19),
                  label: Text(playModeLabel),
                ),
                IconButton(onPressed: onClose, icon: const Icon(CupertinoIcons.xmark_circle_fill)),
              ],
            ),
            Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(CupertinoIcons.trash, size: 15),
                label: const Text('清空列表'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: mockSongs.length,
                itemBuilder: (context, index) {
                  final song = mockSongs[index];
                  final isCurrent = index == 0;
                  return _PlaylistSheetRow(index: index, song: song, isCurrent: isCurrent);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSheetRow extends StatelessWidget {
  const _PlaylistSheetRow({required this.index, required this.song, required this.isCurrent});

  final int index;
  final Song song;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.onSurface.withValues(alpha: isCurrent ? 0.05 : 0.02),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: isCurrent
                ? Icon(CupertinoIcons.play_fill, size: 16, color: theme.colorScheme.primary)
                : Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.42)),
                  ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [Color(0xFFFFD5E4), Color(0xFFCDEAFF)]),
            ),
            child: Icon(CupertinoIcons.play_fill, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.58)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(CupertinoIcons.xmark, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.48)),
          ),
        ],
      ),
    );
  }
}
