import 'package:flutter/cupertino.dart';
import '../../shared/widgets/migration_placeholder_page.dart';

class LocalScanPage extends StatelessWidget {
  const LocalScanPage({super.key});

  @override
  Widget build(BuildContext context) => const MigrationPlaceholderPage(
        title: '本地音乐',
        source: 'LocalScanPage.ets / MusicScanner.ets',
        icon: CupertinoIcons.folder_fill,
      );
}
