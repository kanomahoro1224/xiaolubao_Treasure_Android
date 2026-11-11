import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/playlist.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 56, 12, 190),
          sliver: SliverList.list(
            children: const [
              SizedBox(height: 64),
              _AccountTitle(),
              SizedBox(height: 54),
              _UserProfileCard(),
              SizedBox(height: 88),
              _ListenStatsCard(),
              SizedBox(height: 52),
              _QuickActions(),
              SizedBox(height: 36),
              _LocalPlaylistSection(),
              SizedBox(height: 160),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTitle extends StatelessWidget {
  const _AccountTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '我的账户',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary),
            alignment: Alignment.center,
            child: const Text(
              'K',
              style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Kafuno',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '音乐是我生命中的光',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.24)),
        ],
      ),
    );
  }
}

class _ListenStatsCard extends StatelessWidget {
  const _ListenStatsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('听歌概览', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '记录你的每一个旋律时刻',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.46)),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.music_note_2, size: 26, color: theme.colorScheme.primary.withValues(alpha: 0.82)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: _StatMetric(value: '0', label: '听歌分钟')),
              Container(width: 1, height: 42, color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
              const Expanded(child: _StatMetric(value: '1', label: '累计曲目')),
            ],
          ),
          const SizedBox(height: 26),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 5,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.09),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 36, height: 1.0, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 9),
        Text(label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.56))),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = const [
      _QuickAction(CupertinoIcons.music_note_2, '本地歌曲'),
      _QuickAction(CupertinoIcons.search, '本地扫描'),
      _QuickAction(CupertinoIcons.arrow_down_to_line, '下载管理'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: actions[i]),
            if (i != actions.length - 1) const SizedBox(width: 34),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 36, color: theme.colorScheme.onSurface.withValues(alpha: 0.76)),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LocalPlaylistSection extends StatelessWidget {
  const _LocalPlaylistSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              const Expanded(child: Text('本地歌单', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              Text('+', style: TextStyle(fontSize: 30, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.70))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final playlist in mockLocalPlaylists.take(1)) _LocalPlaylistTile(playlist: playlist),
      ],
    );
  }
}

class _LocalPlaylistTile extends StatelessWidget {
  const _LocalPlaylistTile({required this.playlist});

  final KafunoPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songCount = playlist.songs.length;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFFFF69CE), Color(0xFF25F4EE), Color(0xFFFFF34A)]),
            ),
            child: const Icon(CupertinoIcons.music_note_2, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text('$songCount 首歌曲', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.48))),
              ],
            ),
          ),
          Icon(CupertinoIcons.list_bullet, size: 28, color: theme.colorScheme.onSurface.withValues(alpha: 0.82)),
        ],
      ),
    );
  }
}
