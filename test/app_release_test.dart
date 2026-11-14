import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kafuno_music/features/update/app_update.dart';

/// 版本公告的解析与比较。
///
/// 这里的 JSON 是从 `https://dl.xiaolubao.com/latest.json` 原样抄下来的
/// （只裁掉了 harmony / ios 的无关字段），不自己编结构 —— 上一轮 B 站表情
/// 就是照文档猜字段名猜错的，这类协议必须有真实样本兜着。
const _siteJson = '''
{
  "app": "小鹿包们的宝物",
  "package": "kano.xiaolubao.com",
  "updatedAt": "2026-11-14T04:55:29.914Z",
  "platforms": {
    "harmony": {
      "platform": "harmony",
      "versionName": "1.0.3",
      "versionCode": 1000003,
      "minSupportedCode": 0,
      "downloadUrl": "https://appgallery.huawei.com/apptest/19Mc89lebZa"
    },
    "android": {
      "platform": "android",
      "versionName": "1.0.3",
      "versionCode": 1000003,
      "minSupportedCode": 1,
      "channel": "arm64",
      "sizeBytes": 0,
      "sha1": null,
      "notes": "B站动态支持GIF\\r\\n从Beta版转为正式版",
      "publishedAt": "2026-11-13T14:36:00.000Z",
      "downloadUrl": "https://pan.xiaolubao.com/@s/1224"
    },
    "ios": {
      "platform": "ios",
      "versionName": "1.0.3",
      "versionCode": 1000003,
      "minSupportedCode": 1,
      "downloadUrl": "https://github.com/kanomahoro1224/xiaolubao_Treasure/releases"
    }
  }
}
''';

void main() {
  group('分发站结构（platforms.android）', () {
    final release = AppRelease.fromJson(jsonDecode(_siteJson));

    test('取的是 android 那一份，不是顶层也不是 harmony', () {
      expect(release, isNotNull);
      expect(release!.versionCode, 1000003);
      expect(release.versionName, '1.0.3');
      expect(release.downloadUrl, 'https://pan.xiaolubao.com/@s/1224');
      expect(release.minSupportedCode, 1);
    });

    test('notes 保留换行，不在解析层做清洗', () {
      expect(release!.notes, contains('GIF'));
      expect(release.notes, contains('\n'));
    });

    test('minSupportedCode 是 1，不构成强制更新', () {
      // forced = minSupportedCode >= versionCode；1 >= 1000003 为假
      expect(release!.forced, isFalse);
    });
  });

  group('只认分发站结构', () {
    test('没有 platforms 键就当没有更新，不再兼容扁平结构', () {
      expect(
        AppRelease.fromJson({
          'versionCode': 1000005,
          'versionName': '1.0.5',
          'downloadUrl': 'https://example.com/a.apk',
        }),
        isNull,
      );
    });
  });

  group('坏数据一律返回 null（宁可漏提示，不可报错）', () {
    test('缺 downloadUrl', () {
      expect(
        AppRelease.fromJson({'versionCode': 1000003, 'versionName': '1.0.3'}),
        isNull,
      );
    });

    test('downloadUrl 是空串', () {
      expect(
        AppRelease.fromJson({'versionCode': 1000003, 'downloadUrl': '   '}),
        isNull,
      );
    });

    test('只有 harmony / ios，没有 android', () {
      final raw = jsonDecode(_siteJson) as Map<String, dynamic>;
      (raw['platforms'] as Map).remove('android');
      expect(AppRelease.fromJson(raw), isNull);
    });

    test('不是 Map', () {
      expect(AppRelease.fromJson(jsonDecode('[]')), isNull);
      expect(AppRelease.fromJson('nope'), isNull);
      expect(AppRelease.fromJson(null), isNull);
    });
  });

  group('与新版本比较', () {
    final release = AppRelease.fromJson(jsonDecode(_siteJson))!;

    test('装在手机上的 1.0.2 会看到提示', () {
      expect(release.versionCode > 1000002, isTrue);
    });

    test('已经是 1.0.3 就不再提示（pending 里 <= 就清缓存返回 null）', () {
      expect(release.versionCode <= 1000003, isTrue);
    });
  });

  group('跳转链接统一走分发站', () {
    final release = AppRelease.fromJson(jsonDecode(_siteJson))!;

    test('json 里给的是网盘地址 → 收敛到站点首页', () {
      expect(release.downloadUrl, startsWith('https://pan.xiaolubao.com'));
      expect(release.downloadUri.toString(), 'https://dl.xiaolubao.com');
    });

    test('GitHub Releases 也一样收敛，不按平台分流', () {
      final ios = AppRelease.fromJson(jsonDecode(_siteJson), platform: 'ios')!;
      expect(ios.downloadUrl, contains('github.com'));
      expect(ios.downloadUri.toString(), 'https://dl.xiaolubao.com');
    });

    test('已经是分发站下的具体文件就照用，方便以后分平台放包', () {
      final r = AppRelease.fromJson({
        'platforms': {
          'android': {
            'versionCode': 1000004,
            'downloadUrl': 'https://dl.xiaolubao.com/android/xiaolubao-1.0.4.apk',
          },
        },
      });
      expect(r!.downloadUri.toString(),
          'https://dl.xiaolubao.com/android/xiaolubao-1.0.4.apk');
    });

    test('冒充域名不放行（dl.xiaolubao.com.evil.com）', () {
      final r = AppRelease.fromJson({
        'platforms': {
          'android': {
            'versionCode': 1000004,
            'downloadUrl': 'https://dl.xiaolubao.com.evil.com/a.apk',
          },
        },
      });
      expect(r!.downloadUri.toString(), 'https://dl.xiaolubao.com');
    });
  });

  test('缓存往返后字段不丢，否则「下次再说」下次重启就弹不出来', () {
    final first = AppRelease.fromJson(jsonDecode(_siteJson))!;
    final again = AppRelease.fromJson(jsonDecode(jsonEncode(first.toJson())));

    expect(again, isNotNull);
    expect(again!.versionCode, first.versionCode);
    expect(again.versionName, first.versionName);
    expect(again.downloadUrl, first.downloadUrl);
    expect(again.minSupportedCode, first.minSupportedCode);
    expect(again.notes, first.notes);
  });
}
