import 'package:flutter_test/flutter_test.dart';

import 'package:kafuno_music/features/kano/domain/kano_models.dart';
import 'package:kafuno_music/features/kano/domain/kano_server.dart';
import 'package:kafuno_music/features/kano/domain/kano_strings.dart';
import 'package:kafuno_music/features/kano/domain/kano_text.dart';
import 'package:kafuno_music/features/kano/domain/kano_time.dart';
import 'package:kafuno_music/features/settings/settings_strings.dart';

/// 只测纯逻辑（解析 / 时间 / 基址 / 文案表）。
///
/// 页面级测试要起网络与玻璃渲染，跑起来又慢又不稳，这里不铺那一层。
void main() {
  group('四语文案表', () {
    test('每行都是 4 个非空项', () {
      final bad = <String>[];
      kanoStrings.forEach((key, row) {
        if (row.length != 4) bad.add('$key:${row.length}');
        if (row.any((s) => s.trim().isEmpty)) bad.add('$key:empty');
      });
      expect(bad, isEmpty, reason: '有问题的是 ${bad.take(10).join(', ')}');
    });

    test('条目数与鸿蒙资源量级一致（不许悄悄少一半）', () {
      expect(kanoStrings.length, greaterThan(2500));
    });

    test('未知 key 原样返回，不抛', () {
      expect(KanoText.ui('__nope__'), '__nope__');
    });

    test('切语言后同一条 key 拿到对应语种', () {
      KanoText.overrideLangIndex(0);
      final zh = KanoText.ui('tab_settings');
      KanoText.overrideLangIndex(3);
      final en = KanoText.ui('tab_settings');
      KanoText.overrideLangIndex(-1);
      expect(zh, isNotEmpty);
      expect(en, isNotEmpty);
      expect(en, isNot(zh));
    });

    test('设置页新增文案四语齐全', () {
      for (final key in [
        'section_data',
        'server',
        'cache',
        'calendar_sub',
        'about_licenses',
      ]) {
        expect(SettingsStrings.t(key), isNot(key));
      }
    });
  });

  group('KanoServer', () {
    test('normalize 补协议、去掉尾斜杠', () {
      expect(KanoServer.normalize('kano.yexca.net'), 'https://kano.yexca.net');
      expect(KanoServer.normalize('https://a.com///'), 'https://a.com');
      expect(KanoServer.normalize('  '), KanoServer.defaultBase);
    });

    test('absolute 补相对路径', () {
      final base = KanoServer.base;
      expect(KanoServer.absolute('/media/a.jpg'), '$base/media/a.jpg');
      expect(KanoServer.absolute('media/a.jpg'), '$base/media/a.jpg');
    });

    test('absolute 把主站绝对地址改写成当前基址', () {
      expect(
        KanoServer.absolute('https://xiaolubao.com/media/x.png'),
        '${KanoServer.base}/media/x.png',
      );
    });

    test('accountOf 抠 handle 并小写', () {
      expect(KanoServer.accountOf('https://x.com/Kano_2525'), 'kano_2525');
      expect(KanoServer.accountOf('https://x.com/'), '');
      expect(KanoServer.accountOf(''), '');
    });
  });

  group('KanoTime', () {
    test('monthRange 覆盖整月', () {
      expect(KanoTime.monthRange(2026, 2), ('2026-02-01', '2026-02-28'));
      expect(KanoTime.monthRange(2024, 2), ('2024-02-01', '2024-02-29'));
      expect(KanoTime.monthRange(2026, 12), ('2026-12-01', '2026-12-31'));
    });

    test('clampRange 超过 31 天就贴右边截断', () {
      final r = KanoTime.clampRange('2026-01-01', '2026-03-15');
      expect(r[1], '2026-03-15');
      expect(r[0], '2026-02-13'); // 3-15 往前 30 天
    });

    test('clampRange 范围内原样返回', () {
      expect(KanoTime.clampRange('2026-03-01', '2026-03-31'), ['2026-03-01', '2026-03-31']);
    });
  });

  group('解析', () {
    test('日历页 events 与 items 两种字段名都能吃', () {
      final a = KanoCalendarPage.fromJson({
        'events': [
          {'id': 'e1', 'title': '歌枠', 'startsAt': '2026-03-05T11:00:00Z', 'startsOn': '2026-03-05'},
        ],
        'dayCounts': {'2026-03-05': 1},
        'total': 1,
        'revision': 7,
      });
      final b = KanoCalendarPage.fromJson({
        'items': [
          {'id': 'e1', 'title': '歌枠', 'startsAt': '2026-03-05T11:00:00Z', 'startsOn': '2026-03-05'},
        ],
        'dayCounts': {'2026-03-05': 1},
        'total': 1,
        'revision': 7,
      });
      expect(a.events.length, 1);
      expect(b.events.length, 1);
      expect(a.countOf('2026-03-05'), 1);
      expect(a.eventsOn('2026-03-05').single.title, '歌枠');
    });

    test('日历页 merge 按 id 去重', () {
      const one = KanoCalendarPage(events: [], dayCounts: {}, total: 0, revision: 1);
      final left = KanoCalendarPage.fromJson({
        'events': [
          {'id': 'x', 'title': 'A', 'startsOn': '2026-03-01'},
        ],
        'dayCounts': {'2026-03-01': 1},
        'total': 1,
      });
      final right = KanoCalendarPage.fromJson({
        'events': [
          {'id': 'x', 'title': 'A', 'startsOn': '2026-03-01'},
          {'id': 'y', 'title': 'B', 'startsOn': '2026-04-01'},
        ],
        'dayCounts': {'2026-04-01': 1},
        'total': 1,
      });
      final merged = one.merge(left).merge(right);
      expect(merged.events.length, 2);
      expect(merged.total, 2);
      expect(merged.countOf('2026-03-01'), 1);
      expect(merged.countOf('2026-04-01'), 1);
    });

    test('帖子分页：缺 page 时兜底 1，accountCounts 转 int', () {
      final page = KanoPostPage.fromJson({
        'items': [
          {'id': 'p1', 'text': 'hi', 'url': 'https://x.com/a/status/1'},
        ],
        'accountCounts': {'kano_2525': '3'},
        'total': 1,
      });
      expect(page.page, 1);
      expect(page.pageSize, 30);
      expect(page.accountCounts['kano_2525'], 3);
      expect(page.items.single.text, 'hi');
    });

    test('视频：alternates 里挑出 bilibili 地址', () {
      final page = KanoVideoPage.fromJson({
        'items': [
          {
            'id': 'v1',
            'title': 'short',
            'kind': 'video',
            'source': 'youtube',
            'url': 'https://youtu.be/abc',
            'isShort': true,
            'alternates': [
              {'source': 'bilibili', 'url': 'https://www.bilibili.com/video/BV1xx'},
            ],
          },
        ],
        'categoryCounts': {'video': 1, 'live': 2, 'short': 3},
      });
      final video = page.items.single;
      expect(video.isShort, isTrue);
      expect(video.hasBilibili, isTrue);
      expect(video.bilibiliUrl, 'https://www.bilibili.com/video/BV1xx');
      expect(page.categoryCounts['live'], 2);
      expect(page.categoryCounts['short'], 3);
    });

    test('坏 JSON 结构不抛，返回空列表', () {
      final page = KanoPostPage.fromJson({'items': 'not-a-list'});
      expect(page.items, isEmpty);
    });
  });
}
