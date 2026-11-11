import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';

import '../domain/kano_models.dart';
import '../domain/kano_text.dart';
import '../domain/kano_time.dart';

/// 「加入日程」：把一条 KanoEvent 写进系统日历。
///
/// 鸿蒙侧走 `calendarManager` 直接写入；Flutter 这边用 `add_2_calendar`，
/// 它会拉起系统日历的「新建事件」界面让用户确认 —— 语义一致（都是写进系统日历），
/// 区别只是最后一步由用户点确认，不需要额外申请日历读写权限。
class KanoCalendarExport {
  KanoCalendarExport._();

  /// 开播前多久提醒（与鸿蒙侧 `recent_calendar_added` 的文案一致：10 分钟）
  static const _reminderMinutes = 10;

  static Future<void> addEvent(BuildContext context, KanoEvent event) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) messenger.hideCurrentSnackBar();

    final startMs = event.timeMs;
    if (startMs <= 0) {
      _toast(context, KanoText.ui('recent_calendar_failed'));
      return;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    // 有结束时间就用它；没有则按直播惯例给 2 小时
    final end = event.endsAtMs > startMs
        ? DateTime.fromMillisecondsSinceEpoch(event.endsAtMs)
        : start.add(const Duration(hours: 2));

    final descriptionParts = <String>[
      if (event.detail.isNotEmpty) event.detail,
      KanoText.uiFmt('local_time', KanoTime.localText(startMs)),
      if (event.url.isNotEmpty) event.url,
    ];

    final calendarEvent = Event(
      title: event.title,
      description: descriptionParts.join('\n'),
      location: event.source,
      startDate: start,
      endDate: end,
      allDay: false,
      androidParams: const AndroidParams(
        emailInvites: [],
      ),
      iosParams: const IOSParams(
        reminder: Duration(minutes: _reminderMinutes),
      ),
    );

    try {
      final ok = await Add2Calendar.addEvent2Cal(calendarEvent);
      if (!context.mounted) return;
      _toast(context, KanoText.ui(ok ? 'recent_calendar_added' : 'recent_calendar_cancelled'));
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, KanoText.ui('recent_calendar_failed'));
    }
  }

  static void _toast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }
}
