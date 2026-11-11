import 'package:flutter/cupertino.dart';
import '../../shared/widgets/migration_placeholder_page.dart';

class ListenStatsPage extends StatelessWidget {
  const ListenStatsPage({super.key});

  @override
  Widget build(BuildContext context) => const MigrationPlaceholderPage(
        title: '听歌统计',
        source: 'ListenStatsPage.ets',
        icon: CupertinoIcons.chart_bar_fill,
      );
}
