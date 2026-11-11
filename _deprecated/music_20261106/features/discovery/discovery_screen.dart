import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/playlist.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const isLoggedIn = false;
    const cloudApiToken = '';
    final userPlaylists = mockCloudPlaylists;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 190),
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 56),
              _SearchBar(theme: theme),
              const SizedBox(height: 24),
              if (!isLoggedIn && cloudApiToken.isEmpty)
                const _CloudLoginPrompt()
              else if (userPlaylists.isEmpty)
                const _EmptyPlaylistHint()
              else
                _CloudPlaylistList(playlists: userPlaylists),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.46),
          ),
          const SizedBox(width: 9),
          Text(
            '搜索歌曲、歌手、专辑',
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudLoginPrompt extends StatelessWidget {
  const _CloudLoginPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 76),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.person_crop_circle_badge_plus,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.62),
          ),
          const SizedBox(height: 16),
          Text(
            '登录后开启云端音乐之旅',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 160,
            height: 46,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: const Text('立即登录'),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '对应 DiscoveryTab.ets 的未登录分支；登录页后续由 HuaweiLogin/WebLoginPage 迁移。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaylistHint extends StatelessWidget {
  const _EmptyPlaylistHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.music_note_list,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到歌单',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudPlaylistList extends StatelessWidget {
  const _CloudPlaylistList({required this.playlists});

  final List<KafunoPlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < playlists.length; i++)
          _CloudPlaylistTile(
            playlist: playlists[i],
            isFavorite: i == 0,
          ),
      ],
    );
  }
}

class _CloudPlaylistTile extends StatelessWidget {
  const _CloudPlaylistTile({required this.playlist, required this.isFavorite});

  final KafunoPlaylist playlist;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF3A2B38), Color(0xFF101820)]
                        : const [Color(0xFFFFD4E3), Color(0xFFCDEAFF)],
                  ),
                ),
                child: Icon(
                  CupertinoIcons.music_note_list,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (isFavorite)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '收藏',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${playlist.songs.length} 首',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}
