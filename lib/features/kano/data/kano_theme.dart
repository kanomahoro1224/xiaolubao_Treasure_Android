import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'kano_cache.dart';

/// 一套打包主题，等价于鸿蒙 `ThemeConfig` + `ThemeManager.parseThemeDir`。
///
/// 鸿蒙把主题放在 `files/themes/<主题名>/`，靠「候选文件名逐个探测」解析；
/// 这里内置四套打进 assets（目录用英文 slug，显示名仍是中文），
/// 用户导入的主题落到应用文档目录，解析规则与鸿蒙完全一致。
class KanoTheme {
  const KanoTheme({
    required this.name,
    required this.dir,
    required this.fromAssets,
    this.cover,
    this.preview,
    this.background,
    this.headBg,
    this.tailBg,
    this.tailIcons = const {},
  });

  /// 显示名（空串 = 默认主题）
  final String name;

  /// 资源目录：assets 路径或文件系统绝对路径
  final String dir;

  /// true 用 AssetImage，false 用 FileImage
  final bool fromAssets;

  final String? cover;
  final String? preview;
  final String? background;
  final String? headBg;
  final String? tailBg;

  /// `main` / `main_selected` → 图片路径（鸿蒙 `tailIcons`）
  final Map<String, String> tailIcons;

  bool get isDefault => name.isEmpty;

  /// 主题卡片封面：鸿蒙 `theme.coverPath || theme.backgroundPath`
  String? get cardCover => cover ?? background;

  ImageProvider? providerOf(String? path) {
    if (path == null || path.isEmpty) return null;
    return fromAssets ? AssetImage(path) : FileImage(File(path));
  }

  /// 底栏图标：选中取 `_selected` 版，缺图返回 null（回落到矢量图标）
  String? tailIcon(String key, bool selected) =>
      tailIcons[selected ? '${key}_selected' : key];

  static const none = KanoTheme(name: '', dir: '', fromAssets: true);
}

/// 导入结果，对应鸿蒙 `ThemeImportResult`
class KanoThemeImportResult {
  const KanoThemeImportResult({
    required this.ok,
    required this.imported,
    required this.message,
  });

  final bool ok;
  final List<String> imported;
  final String message;
}

class KanoThemeManager extends ChangeNotifier {
  KanoThemeManager._();

  static final KanoThemeManager instance = KanoThemeManager._();

  /// 目录 slug → 显示名。与 `rawfile/themes/` 里的四套一一对应。
  static const slugNames = <String, String>{
    'ten_years': '十年星扉',
    'kano': '鹿乃',
    'kano_sakura': '鹿乃桜帆',
    'shibuya': '涩谷音韵',
  };

  /// 内置顺序按鸿蒙 `getBuiltInThemeNames()`：十年星扉、鹿乃、鹿乃桜帆、涩谷音韵
  static const _order = ['ten_years', 'kano', 'kano_sakura', 'shibuya'];

  List<KanoTheme> _themes = const [];
  List<KanoTheme> get themes => _themes;

  String _activeName = '';
  String get activeName => _activeName;

  KanoTheme? get active {
    if (_activeName.isEmpty) return null;
    for (final theme in _themes) {
      if (theme.name == _activeName) return theme;
    }
    return null;
  }

  /// 有激活主题且解析成功（鸿蒙 `hasAppliedTheme()`）
  bool get hasActive => active != null;

  /// 当前主题背景，用于首页底图（鸿蒙 `getAppliedThemeBackground()`）
  String? get activeBackground =>
      active?.background ?? active?.preview ?? active?.cover;

  Future<void> load() async {
    _activeName = await KanoPrefs.getString(KanoPrefs.activeThemeKey, '');

    final builtIns = await _loadBuiltIn();

    final imported = <KanoTheme>[];
    final builtInNames = builtIns.map((theme) => theme.name).toSet();
    try {
      final root = await _importRoot();
      if (await root.exists()) {
        await for (final entity in root.list()) {
          if (entity is! Directory) continue;
          final name = entity.path.split(Platform.pathSeparator).last;
          // 与内置重名时以内置为准（鸿蒙那边是 Map，后写的会覆盖内置）
          if (builtInNames.contains(name)) continue;
          final theme = _parse(
            name: name,
            dir: entity.path,
            fromAssets: false,
            exists: (path) => File(path).existsSync(),
          );
          if (theme != null) imported.add(theme);
        }
      }
    } catch (_) {
      // 导入目录不可读时不影响内置主题
    }
    imported.sort((a, b) => a.name.compareTo(b.name));

    _themes = [...builtIns, ...imported];
    notifyListeners();
  }

  Future<List<KanoTheme>> _loadBuiltIn() async {
    Set<String> keys;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      keys = manifest.listAssets().toSet();
    } catch (_) {
      keys = const {};
    }
    final result = <KanoTheme>[];
    for (final slug in _order) {
      final theme = _parse(
        name: slugNames[slug]!,
        dir: 'assets/themes/$slug',
        fromAssets: true,
        exists: keys.contains,
      );
      if (theme != null) result.add(theme);
    }
    return result;
  }

  /// 等价鸿蒙 `parseThemeDir`：候选名逐个探测，缺封面退预览、再退顶图。
  KanoTheme? _parse({
    required String name,
    required String dir,
    required bool fromAssets,
    required bool Function(String path) exists,
  }) {
    String? pick(List<String> names) {
      for (final n in names) {
        final path = '$dir/$n';
        if (exists(path)) return path;
      }
      return null;
    }

    final coverCandidates = pick([
      'image_cover-0_other.png',
      'image_cover-0_other.jpg',
    ]);
    var preview = pick([
      'image_preview-0_other.png',
      'image_preview-0_other.jpg',
    ]);
    preview ??= pick(['background_portrait_1-0_other.jpg']);
    var cover = coverCandidates ?? preview;
    cover ??= pick(['head_bg-0_other.jpg']);

    String? background;
    for (var i = 1; i <= 5; i++) {
      final path = pick(['background_portrait_$i-0_other.jpg']);
      if (path != null) {
        background = path;
        break;
      }
    }
    background ??= pick([
      'image_preview-0_other.png',
      'image_preview-0_other.jpg',
    ]);

    final tailIcons = <String, String>{};
    for (final icon in const ['main', 'channel', 'dynamic', 'myself', 'shop']) {
      final normal = pick(['tail_icon_$icon-0_other.png']);
      if (normal != null) tailIcons[icon] = normal;
      final selected = pick(['tail_icon_selected_$icon-0_other.png']);
      if (selected != null) tailIcons['${icon}_selected'] = selected;
    }

    // 一张图都没有的目录不算主题（鸿蒙那边也会解析成空壳）
    if (cover == null && background == null && tailIcons.isEmpty) return null;

    return KanoTheme(
      name: name,
      dir: dir,
      fromAssets: fromAssets,
      cover: cover,
      preview: preview,
      background: background,
      headBg: pick(['head_bg-0_other.jpg']),
      tailBg: pick(['tail_bg-0_other.png']),
      tailIcons: tailIcons,
    );
  }

  Future<void> setActive(String name) async {
    final next = name == _activeName ? _activeName : name;
    _activeName = next;
    notifyListeners();
    await KanoPrefs.setString(KanoPrefs.activeThemeKey, next);
  }

  Future<Directory> _importRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/themes');
  }

  /// 导入主题 zip，规则移植自鸿蒙 `ThemePackage.planThemePackage`。
  Future<KanoThemeImportResult> importZip(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final entries = <String>[
        for (final file in archive.files)
          if (file.isFile) file.name,
      ];
      final plans = planThemePackage(entries);
      if (plans.isEmpty) {
        return const KanoThemeImportResult(
          ok: false,
          imported: [],
          message: '没有在压缩包里找到主题资源',
        );
      }

      final root = await _importRoot();
      if (!await root.exists()) await root.create(recursive: true);

      final imported = <String>[];
      for (final plan in plans) {
        final dirName = plan.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final target = Directory('${root.path}/$dirName');
        if (await target.exists()) await target.delete(recursive: true);
        await target.create(recursive: true);
        for (final file in plan.files) {
          final entry = archive.findFile(file.from);
          if (entry == null) continue;
          final out = File('${target.path}/${file.to}');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(entry.content as List<int>, flush: true);
        }
        imported.add(plan.name);
      }

      await load();
      return KanoThemeImportResult(
        ok: imported.isNotEmpty,
        imported: imported,
        message: imported.isEmpty ? '解压后没有写出任何文件' : '已导入 ${imported.join('、')}',
      );
    } catch (e) {
      return KanoThemeImportResult(ok: false, imported: [], message: '导入失败：$e');
    }
  }
}

/// 主题包里某个文件的搬运计划：from = zip 内相对路径，to = 主题目录内相对路径
class ThemePackageFile {
  const ThemePackageFile({required this.from, required this.to});
  final String from;
  final String to;
}

class ThemePackageTheme {
  const ThemePackageTheme({required this.name, required this.files});
  final String name;
  final List<ThemePackageFile> files;
}

/// 主题资源文件名前缀：某个目录里直接有这类文件，它就是主题资源目录
final RegExp _resourceMarker = RegExp(
  r'^(image_cover|image_preview|tail_bg|head_bg|head_tab_bg|side_bg|head_myself|background_portrait_|background_landscape_|tail_icon)',
);

const String _collectionDirName = '主题';

String normalizeEntryPath(String entry) {
  var p = entry.replaceAll('\\', '/').trim();
  while (p.startsWith('./')) {
    p = p.substring(2);
  }
  while (p.startsWith('/')) {
    p = p.substring(1);
  }
  return p;
}

String themeNameOf(String path) {
  final norm = normalizeEntryPath(path);
  final slash = norm.lastIndexOf('/');
  return slash < 0 ? norm : norm.substring(slash + 1);
}

String commonPrefixOf(List<String> names) {
  if (names.isEmpty) return '';
  var prefix = names.first;
  for (var i = 1; i < names.length; i++) {
    final other = names[i];
    var len = 0;
    while (len < prefix.length &&
        len < other.length &&
        prefix.codeUnitAt(len) == other.codeUnitAt(len)) {
      len++;
    }
    prefix = prefix.substring(0, len);
    if (prefix.isEmpty) break;
  }
  return prefix;
}

/// 把 zip 条目列表整理成待导入的主题列表。
/// 先找「直接放着主题资源文件」的目录；若它的父目录叫「主题」，
/// 就把父目录下所有子目录归成一个主题（收藏集），主题名取这些子目录名的公共前缀；
/// 否则每个资源目录各自成一个主题。
List<ThemePackageTheme> planThemePackage(List<String> entries) {
  final files = <String>[];
  for (final raw in entries) {
    final p = normalizeEntryPath(raw);
    if (p.isEmpty || p.endsWith('/')) continue;
    files.add(p);
  }

  final resourceDirs = <String>[];
  for (final p in files) {
    final slash = p.lastIndexOf('/');
    if (slash <= 0) continue;
    if (!_resourceMarker.hasMatch(p.substring(slash + 1))) continue;
    final dir = p.substring(0, slash);
    if (!resourceDirs.contains(dir)) resourceDirs.add(dir);
  }

  final groups = <String, bool>{}; // key → isCollection
  for (final dir in resourceDirs) {
    final slash = dir.lastIndexOf('/');
    final parent = slash < 0 ? '' : dir.substring(0, slash);
    final isCollection =
        parent.isNotEmpty && themeNameOf(parent) == _collectionDirName;
    groups.putIfAbsent(isCollection ? parent : dir, () => isCollection);
  }

  final out = <ThemePackageTheme>[];
  for (final entry in groups.entries) {
    final key = entry.key;
    final isCollection = entry.value;
    final prefix = '$key/';
    final childNames = <String>[];
    for (final p in files) {
      if (!p.startsWith(prefix)) continue;
      final rest = p.substring(prefix.length);
      if (!isCollection) continue;
      final slash = rest.indexOf('/');
      if (slash < 0) continue; // 收藏集根目录下的散文件不算
      final child = rest.substring(0, slash);
      if (!childNames.contains(child)) childNames.add(child);
    }
    if (!isCollection) childNames.add(themeNameOf(key));
    var name = commonPrefixOf(childNames);
    if (name.isEmpty) {
      name = childNames.isNotEmpty ? childNames.first : themeNameOf(key);
    }

    final themeFiles = <ThemePackageFile>[];
    for (final p in files) {
      if (!p.startsWith(prefix)) continue;
      final rest = p.substring(prefix.length);
      if (!isCollection) {
        themeFiles.add(ThemePackageFile(from: p, to: rest));
        continue;
      }
      final slash = rest.indexOf('/');
      if (slash < 0) continue;
      themeFiles.add(
        ThemePackageFile(from: p, to: rest.substring(slash + 1)),
      );
    }
    out.add(ThemePackageTheme(name: name, files: themeFiles));
  }

  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
