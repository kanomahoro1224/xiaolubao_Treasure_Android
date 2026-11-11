import '../models/playlist.dart';
import '../models/song.dart';

class CloudMusicApi {
  const CloudMusicApi();

  Future<List<Song>> searchSongs(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    return mockSongs
        .where((song) => '${song.title}${song.artist}'.toLowerCase().contains(keyword.toLowerCase()))
        .toList(growable: false);
  }

  Future<List<Song>> getDailySongs() async => mockSongs;

  Future<List<KafunoPlaylist>> getRecommendedPlaylists() async => mockPlaylists;

  Future<String?> getSongUrl(String songId, {String quality = 'lossless'}) async {
    return null;
  }
}
