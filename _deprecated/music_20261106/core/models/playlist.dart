import 'song.dart';

class KafunoPlaylist {
  const KafunoPlaylist({
    required this.id,
    required this.name,
    this.coverUrl = '',
    this.description = '',
    this.songs = const [],
    this.playCount = 0,
  });

  final String id;
  final String name;
  final String coverUrl;
  final String description;
  final List<Song> songs;
  final int playCount;
}

const mockPlaylists = [
  KafunoPlaylist(
    id: 'daily',
    name: '每日推荐',
    description: '根据 ArkTS Home.ets 迁移的首页推荐入口',
    songs: mockSongs,
  ),
  KafunoPlaylist(
    id: 'cloud',
    name: '云音乐精选',
    description: '后续由 CloudMusicApi.ets 迁移实现',
    songs: mockSongs,
  ),
];

const mockCloudPlaylists = [
  KafunoPlaylist(
    id: 'liked_cloud',
    name: '我喜欢的音乐',
    description: 'DiscoveryTab.ets userPlaylists 的收藏歌单占位',
    songs: mockSongs,
  ),
  KafunoPlaylist(
    id: 'cloud_private',
    name: 'Kafuno 云端精选',
    description: 'CloudMusicApi.UserPlaylistItem 迁移占位',
    songs: mockSongs,
  ),
];

const mockLocalPlaylists = [
  KafunoPlaylist(
    id: 'local_favorite',
    name: '本地收藏',
    description: 'PreferencesUtil.LocalPlaylist 迁移占位',
    songs: mockSongs,
  ),
  KafunoPlaylist(
    id: 'local_imported',
    name: '导入的音乐',
    description: 'MusicScanner 导入歌曲占位',
    songs: mockSongs,
  ),
];
