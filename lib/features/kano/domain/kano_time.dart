import 'kano_text.dart';

/// 时间与日期工具。口径与鸿蒙 `KanoApi` 完全一致：
/// - 服务端一律 ISO8601（Z 结尾）
/// - 日程的官方时区是 JST（固定 +9，日本不用夏令时）
/// - 日历与接口参数用本地时区的 `YYYY-MM-DD`
class KanoTime {
  KanoTime._();

  static const dayMs = 86400000;
  static const jstOffsetMs = 9 * 3600000;

  /// 服务端对 posts / calendar 的日期跨度限到 31 天，超了直接 400。
  static const maxRangeDays = 31;

  static int parseIso(String? value) {
    if (value == null || value.isEmpty) return 0;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
  }

  static String _pad(int n) => n < 10 ? '0$n' : '$n';

  /// 'YYYY-MM-DD'（本地时区）
  static String dayKey(int year, int month, int day) => '$year-${_pad(month)}-${_pad(day)}';

  static String dayKeyOfMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return dayKey(d.year, d.month, d.day);
  }

  static String dayKeyOffset(int days) => dayKeyOfMs(DateTime.now().millisecondsSinceEpoch + days * dayMs);

  /// 'YYYY-MM-DD'（UTC，避开本地时区把日期挪一天的坑）
  static String dayKeyOfUtcMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  /// 服务端限 31 天跨度，超了就贴边截一下，免得客户端自己算出个 400。
  static List<String> clampRange(String from, String to) {
    final fromMs = parseIso('${from}T00:00:00Z');
    final toMs = parseIso('${to}T00:00:00Z');
    if (fromMs > 0 && toMs > fromMs && (toMs - fromMs) / dayMs + 1 > maxRangeDays) {
      return [dayKeyOfUtcMs(toMs - (maxRangeDays - 1) * dayMs), to];
    }
    return [from, to];
  }

  /// 某年某月的第一天与最后一天（单月范围，`/api/calendar` 硬要求）。
  static (String, String) monthRange(int year, int month) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    return (dayKey(first.year, first.month, first.day), dayKey(last.year, last.month, last.day));
  }

  /// 相对时间，跟 App 语言走。
  static String relativeTime(int ms) {
    if (ms <= 0) return '';
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    const minute = 60000;
    const hour = 60 * minute;
    const day = 24 * hour;
    final lang = KanoText.langIndex;
    final ja = lang == 2;
    final en = lang == 3;
    final hant = lang == 1;

    if (diff < 0) return ja ? 'まもなく' : (en ? 'soon' : (hant ? '即將' : '即将'));
    if (diff < minute) return ja ? 'たった今' : (en ? 'just now' : (hant ? '剛剛' : '刚刚'));
    if (diff < hour) {
      final n = diff ~/ minute;
      return ja ? '$n分前' : (en ? '${n}m ago' : (hant ? '$n分鐘前' : '$n分钟前'));
    }
    if (diff < day) {
      final n = diff ~/ hour;
      return ja ? '$n時間前' : (en ? '${n}h ago' : (hant ? '$n小時前' : '$n小时前'));
    }
    if (diff < 7 * day) {
      final n = diff ~/ day;
      return ja ? '$n日前' : (en ? '${n}d ago' : '$n天前');
    }
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final sameYear = d.year == DateTime.now().year;
    if (en) {
      final md = '${monthTitlesEn[d.month - 1]} ${d.day}';
      return sameYear ? md : '$md, ${d.year}';
    }
    final md = '${d.month}月${d.day}日';
    return sameYear ? md : '${d.year}年$md';
  }

  /// JST 的 `HH:mm`
  static String jstText(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms + jstOffsetMs, isUtc: true);
    return '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  /// 本地时区的 `HH:mm`
  static String localText(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  /// '2026-10-24' → '10月24日' / 'Oct 24'
  static String dateKeyText(String dayKeyStr) {
    if (dayKeyStr.length < 10) return dayKeyStr;
    final month = int.tryParse(dayKeyStr.substring(5, 7)) ?? 1;
    final day = int.tryParse(dayKeyStr.substring(8, 10)) ?? 1;
    if (KanoText.langIndex == 3) {
      return '${monthTitlesEn[(month - 1).clamp(0, 11)]} $day';
    }
    return '$month月$day日';
  }

  /// 两个时间是否同一天（本地时区）
  static bool sameDay(int a, int b) => dayKeyOfMs(a) == dayKeyOfMs(b);
}
