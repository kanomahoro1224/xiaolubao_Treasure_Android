enum AudioSourceType {
  rawFile,
  sandboxFile,
  cloudMusic,
  localUri,
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    this.durationMs = 0,
    this.sourceType = AudioSourceType.cloudMusic,
    this.uri,
    this.quality,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int durationMs;
  final AudioSourceType sourceType;
  final String? uri;
  final String? quality;
}

const mockSongs = [
  Song(
    id: 'cloud_1',
    title: '不是所有的旅途都有终点',
    artist: 'Kafuno Radio',
    album: '每日推荐',
    quality: 'lossless',
  ),
  Song(
    id: 'cloud_2',
    title: 'Encounter',
    artist: '花谱',
    album: 'Kafuno Picks',
    quality: 'hires',
  ),
  Song(
    id: 'cloud_3',
    title: 'Remember',
    artist: 'Kaf / Kaika',
    album: 'Kafuno Picks',
    quality: 'lossless',
  ),
];
