import 'package:flutter_test/flutter_test.dart';
import 'package:kafuno_music/features/kano/data/kano_theme.dart';

/// 内置四套主题必须能在 assets 里被解析出来——
/// 这一步等价于鸿蒙 `ThemeManager.copyBuiltInThemes` + `scanThemes`，
/// 解析不出来（目录没打进包、文件名规则写错）时主题面板会只剩「默认」和「导入」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('四套内置主题都能解析出封面、背景和底栏图标', () async {
    await KanoThemeManager.instance.load();
    final themes = KanoThemeManager.instance.themes;

    expect(themes.map((t) => t.name).toList(), [
      '十年星扉',
      '鹿乃',
      '鹿乃桜帆',
      '涩谷音韵',
    ]);

    for (final theme in themes) {
      expect(theme.cardCover, isNotNull, reason: '${theme.name} 缺封面');
      expect(theme.background, isNotNull, reason: '${theme.name} 缺背景');
      expect(theme.tailBg, isNotNull, reason: '${theme.name} 缺底栏底板');
      expect(
        theme.tailIcon('main', false),
        isNotNull,
        reason: '${theme.name} 缺底栏图标',
      );
      expect(
        theme.tailIcon('main', true),
        isNotNull,
        reason: '${theme.name} 缺底栏选中图标',
      );
    }
  });

  test('主题包路径规划与鸿蒙 planThemePackage 一致', () {
    // 单主题包：主题-2954/主题/鹿乃/<资源>
    final single = planThemePackage([
      '主题-2954/主题/鹿乃/image_cover-0_other.jpg',
      '主题-2954/主题/鹿乃/tail_bg-0_other.png',
    ]);
    expect(single, hasLength(1));
    expect(single.first.name, '鹿乃');
    expect(
      single.first.files.map((f) => f.to).toList(),
      ['image_cover-0_other.jpg', 'tail_bg-0_other.png'],
    );

    // 收藏集：资源散在多个子目录，按公共前缀合成一个主题
    final collection = planThemePackage([
      '收藏集-104153/主题/涩谷音韵个性主题/image_cover-0_other.png',
      '收藏集-104153/主题/涩谷音韵加载动画/loading/loading-0_loading.webp',
      '收藏集-104153/主题/涩谷音韵进度条/playicon/playicon-1_playicon_normal.png',
    ]);
    expect(collection, hasLength(1));
    expect(collection.first.name, '涩谷音韵');
    expect(
      collection.first.files.map((f) => f.to).toList(),
      [
        'image_cover-0_other.png',
        'loading/loading-0_loading.webp',
        'playicon/playicon-1_playicon_normal.png',
      ],
    );
  });
}
