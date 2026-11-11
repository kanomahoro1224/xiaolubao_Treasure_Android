import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kano/data/bilibili_api.dart';
import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../settings/settings_controller.dart';

/// 桌面小组件的数据快照。
///
/// 原生 `RemoteViews` 不能执行 Dart，也不该把「什么算即将开始」「类型配色」这套
/// 口径在 Kotlin 里再写一遍（两边一定会分叉）。所以这里把鸿蒙卡片管理器
/// （`ScheduleCardManager` / `BilibiliFansCardManager`）算好的成品文案、颜色、
/// 格子铺成 JSON 写进 SharedPreferences，Kotlin 只负责画。
///
/// 字段名逐字对齐鸿蒙那两个管理器推给卡片的 `ScheduleCardData` / `BilibiliFansCardData`，
/// 这样「为什么安卓这边少这少那」的答案就只剩 RemoteViews 的渲染能力，而不是口径不同。
/// 音乐卡不搬 —— 本工程没有播放器。
class WidgetSnapshot {
  WidgetSnapshot._();

  static const _channel = MethodChannel('kano/widget');

  /// 写进 SharedPreferences 的键；Kotlin 侧读 `flutter.` 前缀后的同名键
  static const scheduleKey = 'kanoWidget:schedule';
  static const fansKey = 'kanoWidget:fans';
  static const fansHistoryKey = 'kanoWidget:fansHistory';

  /// 给 `:widgetProvider` 进程读的快照文件名（放在 filesDir 下）
  static const snapshotFileName = 'kano_widget.json';

  /// 鸿蒙 ScheduleCardManager：往后看 14 天
  static const _lookaheadDays = 14;

  /// 鸿蒙 SCHEDULE_LIVE_GRACE_MS：已开场 3 小时内的场次仍算「即将开始」
  static const _liveGraceMs = 3 * 3600000;

  /// 鸿蒙 SCHEDULE_LIST_MAX_ITEMS：2x4 列表最多 3 条
  static const _listMaxItems = 3;

  static const _fansHistoryLimit = 30;

  /// 拉一次数据并写快照，然后让原生重绘。失败就保留上一次的快照。
  static Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _writeSchedule(prefs),
      _writeFans(prefs),
    ]);
    await _flushFile(prefs);
    try {
      await _channel.invokeMethod<void>('refresh');
    } catch (_) {
      // 桌面没有小组件、或跑在测试环境时没有这个 channel，忽略
    }
  }

  /// 小部件跑在 `:widgetProvider` 独立进程（小米规范要求的固定进程名）。
  /// SharedPreferences 每个进程各有一份缓存，跨进程读会拿到旧值，
  /// 所以再落一份 JSON 文件给 Kotlin 侧直接读盘。
  ///
  /// 路径用 `getApplicationSupportDirectory()`，在 Android 上就是 `filesDir`，
  /// 与原生 `context.filesDir` 是同一个目录。
  static Future<void> _flushFile(SharedPreferences prefs) async {
    try {
      final payload = <String, dynamic>{};
      for (final entry in const {'schedule': scheduleKey, 'fans': fansKey}.entries) {
        final raw = prefs.getString(entry.value);
        if (raw == null || raw.isEmpty) continue;
        payload[entry.key] = jsonDecode(raw);
      }
      if (payload.isEmpty) return;
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$snapshotFileName');
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // 写盘失败不影响 App 自身；桌面小组件会退回去读 SharedPreferences
    }
  }

  // ==================== 日程 ====================

  static Future<void> _writeSchedule(SharedPreferences prefs) async {
    final now = DateTime.now();
    final events = await _loadEvents(now);

    // 鸿蒙：page === null → status='error'，卡片整卡只显示 errorText
    if (events == null) {
      await prefs.setString(scheduleKey, jsonEncode(_scheduleStatus('error')));
      return;
    }

    final payload = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'status': 'ok',
      'loading': KanoText.ui('schedule_card_loading'),
      'error': KanoText.ui('schedule_card_error'),
      'empty': KanoText.ui('schedule_card_empty'),
      'header': KanoText.ui('schedule_card_upcoming'),
      'monthLabel': KanoText.monthTitle(now.month),
      'year': '${now.year}',
      // 今天圆圈跟 App 主题色走（鸿蒙 profile_themeColor，默认 #FFC0CB）
      'todayColor': SettingsController.instance.themeColor,
      'weekdays': [for (var i = 0; i < 7; i++) KanoText.weekShort(i)],
      'items': _buildItems(events, now),
      'cells': _buildGrid(events, now),
    };
    await prefs.setString(scheduleKey, jsonEncode(payload));
  }

  /// 本月 + （临近月末时）下月，覆盖「即将开始」的 14 天窗口与整月月历
  static Future<List<KanoEvent>?> _loadEvents(DateTime now) async {
    final current = await KanoRepository.instance.calendar(
      year: now.year,
      month: now.month,
    );
    final firstPage = current.data?.events;
    if (firstPage == null) return null;
    // 页面给的 events 是 growable:false，这里拷一份可加的
    final events = <KanoEvent>[...firstPage];

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    if (daysInMonth - now.day < _lookaheadDays) {
      final next = DateTime(now.year, now.month + 1);
      final page = await KanoRepository.instance.calendar(
        year: next.year,
        month: next.month,
      );
      final more = page.data?.events;
      if (more != null) events.addAll(more);
    }
    return events;
  }

  /// 鸿蒙 buildItems()：「即将开始」行，跳过已取消，含开场 3 小时内的场次。
  static List<Map<String, dynamic>> _buildItems(
    List<KanoEvent> events,
    DateTime now,
  ) {
    final nowMs = now.millisecondsSinceEpoch;
    final horizon = nowMs + _lookaheadDays * KanoTime.dayMs;
    final picked = <KanoEvent>[];
    for (final event in events) {
      if (event.cancelled) continue;
      if (event.timeMs <= 0) continue;
      if (event.timeMs <= nowMs - _liveGraceMs || event.timeMs >= horizon) continue;
      picked.add(event);
    }
    picked.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    final items = <Map<String, dynamic>>[];
    for (final event in picked.take(_listMaxItems)) {
      items.add({
        'title': event.title,
        'meta': '${_upcomingDateText(event)} · ${event.timeText()}',
        'tag': event.kindLabel(),
        'color': _hex(KanoKind.colorValue(event.kind())),
      });
    }
    return items;
  }

  /// 鸿蒙 UpcomingItem.label() 同构：`M/D 周X`（startsOn 齐全时）
  static String _upcomingDateText(KanoEvent event) {
    final parts = event.startsOn.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;
      if (month > 0 && day > 0) {
        final weekday = (DateTime(year, month, day).weekday - 1) % 7;
        return '$month/$day ${KanoText.weekFull(weekday)}';
      }
    }
    final date = DateTime.fromMillisecondsSinceEpoch(event.timeMs);
    return '${date.month}/${date.day}';
  }

  /// 鸿蒙 buildGrid()：周一起始、固定 42 格，一天内按开始时间排，
  /// 首场类型 + 第二场类型，两场以上汇总成 +N。
  static List<Map<String, dynamic>> _buildGrid(
    List<KanoEvent> events,
    DateTime now,
  ) {
    final first = DateTime(now.year, now.month, 1);
    final offset = (first.weekday - DateTime.monday) % 7;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final byDay = <int, List<KanoEvent>>{};
    for (final event in events) {
      if (event.startsOn.isEmpty) continue;
      final day = _dayOfMonth(event, now);
      if (day == 0) continue;
      byDay.putIfAbsent(day, () => []).add(event);
    }

    final cells = <Map<String, dynamic>>[];
    for (var i = 0; i < 42; i++) {
      final dayNumber = i - offset + 1;
      final cell = <String, dynamic>{'day': 0};
      if (dayNumber >= 1 && dayNumber <= daysInMonth) {
        cell['day'] = dayNumber;
        cell['today'] = dayNumber == now.day;
        final list = byDay[dayNumber];
        final chips = <Map<String, String>>[];
        if (list != null && list.isNotEmpty) {
          list.sort((a, b) => a.timeMs.compareTo(b.timeMs));
          chips.add({
            't': list[0].kindLabel(),
            'c': _hex(KanoKind.colorValue(list[0].kind())),
          });
          if (list.length == 2) {
            chips.add({
              't': list[1].kindLabel(),
              'c': _hex(KanoKind.colorValue(list[1].kind())),
            });
          } else if (list.length > 2) {
            chips.add({
              't': '+${list.length - 1}',
              'c': _hex(KanoKind.colorValue('')),
            });
          }
        }
        cell['chips'] = chips;
      }
      cells.add(cell);
    }
    return cells;
  }

  /// 事件落在本月几号（JST 口径）；不是本月返回 0
  static int _dayOfMonth(KanoEvent event, DateTime month) {
    final key = event.timeMs > 0
        ? KanoTime.dayKeyOfUtcMs(event.timeMs + KanoTime.jstOffsetMs)
        : event.startsOn;
    final parsed = DateTime.tryParse(key);
    if (parsed == null) return 0;
    if (parsed.year != month.year || parsed.month != month.month) return 0;
    return parsed.day;
  }

  static Map<String, dynamic> _scheduleStatus(String status) => {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'status': status,
        'loading': KanoText.ui('schedule_card_loading'),
        'error': KanoText.ui('schedule_card_error'),
        'empty': KanoText.ui('schedule_card_empty'),
        'header': KanoText.ui('schedule_card_upcoming'),
      };

  // ==================== B站粉丝 ====================

  static Future<void> _writeFans(SharedPreferences prefs) async {
    final info = await BiliFeedApi.getSpaceInfo();

    // 鸿蒙：拉不到数据但手上还有上一次的快照 → 继续按 ok 显示旧值
    if (info == null) {
      final existing = _readJson(prefs, fansKey);
      if (existing != null && existing['status'] == 'ok') return;
      await prefs.setString(fansKey, jsonEncode(_fansStatus('error')));
      return;
    }

    final history = _readHistory(prefs);
    final last = history.isNotEmpty ? history.last : null;
    if (last == null || last['v'] != info.fans) {
      history.add({'t': DateTime.now().millisecondsSinceEpoch, 'v': info.fans});
      while (history.length > _fansHistoryLimit) {
        history.removeAt(0);
      }
      await prefs.setString(fansHistoryKey, jsonEncode(history));
    }

    final diff = _dailyDiff(history);
    final likesLabel = KanoText.ui('fans_card_likes_label');
    final updatedLabel = KanoText.ui('fans_card_updated_label');
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'updatedAt': now.millisecondsSinceEpoch,
      'status': 'ok',
      'loading': KanoText.ui('fans_card_loading'),
      'error': KanoText.ui('fans_card_load_failed'),
      'caption': KanoText.ui('fans_card_caption_followers'),
      'uname': info.name,
      'sign': info.sign,
      'face': info.face,
      'isVip': info.isVip,
      'followersText': _commas(info.fans),
      'followersShortText': _short(info.fans),
      'diffText': _diffText(diff),
      'diffUp': diff > 0,
      'likesText': '$likesLabel: ${_commas(info.likes)}',
      'likesShortText': '$likesLabel: ${_short(info.likes)}',
      'updateTimeText':
          '$updatedLabel: ${_two(now.hour)}:${_two(now.minute)}',
      'history': [for (final record in history) record['v'] as int],
    };
    await prefs.setString(fansKey, jsonEncode(payload));
  }

  static Map<String, dynamic> _fansStatus(String status) => {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'status': status,
        'loading': KanoText.ui('fans_card_loading'),
        'error': KanoText.ui('fans_card_load_failed'),
        'caption': KanoText.ui('fans_card_caption_followers'),
      };

  static Map<String, dynamic>? _readJson(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _readHistory(SharedPreferences prefs) {
    final raw = prefs.getString(fansHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            {
              't': (item['t'] as num?)?.toInt() ?? 0,
              'v': (item['v'] as num?)?.toInt() ?? 0,
            },
      ];
    } catch (_) {
      return [];
    }
  }

  /// 鸿蒙 computeDailyDiff()：最新值相对 24 小时前粉丝数的差；
  /// 历史只在粉丝数变化时追加，所以「24 小时前的值」就是最后一条不晚于 24 小时前的记录。
  static int _dailyDiff(List<Map<String, dynamic>> history) {
    final count = history.length;
    if (count < 2) return 0;
    final latest = history[count - 1];
    final dayAgo = (latest['t'] as int) - 24 * 3600 * 1000;
    Map<String, dynamic>? baseline;
    for (var i = count - 2; i >= 0; i--) {
      if ((history[i]['t'] as int) <= dayAgo) {
        baseline = history[i];
        break;
      }
    }
    baseline ??= history[0];
    return (latest['v'] as int) - (baseline['v'] as int);
  }

  /// 涨跌文案：▲ 涨、▼ 跌，无变化返回空串（鸿蒙 formatDiff）
  static String _diffText(int diff) {
    if (diff == 0) return '';
    return diff > 0 ? '▲${_commas(diff)}' : '▼${_commas(diff.abs())}';
  }

  // ==================== 格式化 ====================

  static String _two(int value) => value < 10 ? '0$value' : '$value';

  static String _hex(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// 鸿蒙 formatWithCommas
  static String _commas(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }

  /// 鸿蒙 formatShort：过万才缩成「x.x万」，否则仍是带逗号的整数
  static String _short(int value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
    return _commas(value);
  }
}
