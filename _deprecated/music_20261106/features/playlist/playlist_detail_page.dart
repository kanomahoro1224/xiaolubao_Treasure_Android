import 'package:flutter/cupertino.dart';
import '../../shared/widgets/migration_placeholder_page.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key});

  @override
  Widget build(BuildContext context) => const MigrationPlaceholderPage(
        title: '歌单详情',
        source: 'PlaylistDetailPage.ets',
        icon: CupertinoIcons.music_albums,
      );
}
