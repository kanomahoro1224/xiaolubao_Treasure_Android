import 'dart:async';

import 'package:flutter/material.dart';

import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_calendar_export.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_palette.dart';
import '../kano/presentation/kano_state.dart';
import '../settings/settings_controller.dart';

/// 一格日历
class _Cell {
  const _Cell({
    required this.key,
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.weekend,
    required this.events,
  });

  final String key;
  final int day;
  final bool inMonth;
  final bool isToday;
  final bool weekend;
  final List<KanoEvent> events;
}

/// 日程表：月历 + 当天事件弹层 + 即将开始。
///
/// 翻月用 `PageView`（无限页，每页一个月），比手写拖拽稳：
/// 惯性、回弹、边界都由框架处理，翻到哪个月就加载哪个月。
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with AutomaticKeepAliveClientMixin {
  /// 底栏切页用 PageView 承载，离开视口时保住当前月份与已加载的日程
  @override
  bool get wantKeepAlive => true;

  static const _baseYear = 2000;

  late PageController _controller;
  late int _index;
  late DateTime _today;
  String _selectedKey = '';
  bool _loading = false;
  KanoSource _source = KanoSource.net;
  bool _firstLoadDone = false;

  /// 'YYYY-MM' → 该月的数据；邻月预取后共享
  final Map<String, KanoCalendarPage> _months = {};

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _index = _indexOf(_today.year, _today.month);
    _controller = PageController(initialPage: _index);
    _selectedKey = KanoTime.dayKey(_today.year, _today.month, _today.day);
    _loadAround(_today.year, _today.month);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(int year, int month) => (year - _baseYear) * 12 + (month - 1);

  (int, int) _monthOf(int index) {
    final year = _baseYear + index ~/ 12;
    final month = index % 12 + 1;
    return (year, month);
  }

  static String _monthKey(int year, int month) => '$year-${month < 10 ? '0$month' : month}';

  Future<void> _loadAround(int year, int month) async {
    if (_loading) return;
    setState(() => _loading = true);
    final current = await KanoRepository.instance.calendar(year: year, month: month);
    final merged = await KanoRepository.instance.calendarWithNeighbors(year, month);
    if (!mounted) return;
    // 把合并结果按月份拆回各自的 key，避免重复请求
    for (var delta = -1; delta <= 1; delta++) {
      final cursor = DateTime(year, month + delta);
      final key = _monthKey(cursor.year, cursor.month);
      final (from, _) = KanoTime.monthRange(cursor.year, cursor.month);
      final events = merged.events
          .where((e) => e.startsOn.startsWith(key) || e.startsOn.startsWith(from))
          .toList(growable: false);
      final counts = <String, int>{};
      merged.dayCounts.forEach((k, v) {
        if (k.startsWith(key)) counts[k] = v;
      });
      _months[key] = KanoCalendarPage(
        events: events,
        dayCounts: counts,
        total: events.length,
        revision: merged.revision,
      );
    }
    setState(() {
      _loading = false;
      _firstLoadDone = true;
      _source = current.source;
    });
  }

  Future<void> _refreshCurrent() async {
    final (year, month) = _monthOf(_index);
    await KanoRepository.instance.calendar(year: year, month: month, force: true);
    await _loadAround(year, month);
  }

  /// 42 格，周一起算
  List<_Cell> _buildCells(int year, int month) {
    final first = DateTime(year, month, 1);
    final offset = (first.weekday - DateTime.monday) % 7;
    final start = DateTime(year, month, 1 - offset);
    final page = _months[_monthKey(year, month)];
    final cells = <_Cell>[];
    for (var i = 0; i < 42; i++) {
      final cursor = DateTime(start.year, start.month, start.day + i);
      final inMonth = cursor.year == year && cursor.month == month;
      final key = KanoTime.dayKey(cursor.year, cursor.month, cursor.day);
      final isToday = cursor.year == _today.year &&
          cursor.month == _today.month &&
          cursor.day == _today.day;
      cells.add(_Cell(
        key: key,
        day: cursor.day,
        inMonth: inMonth,
        isToday: isToday,
        weekend: cursor.weekday >= DateTime.saturday,
        events: inMonth ? (page?.eventsOn(key) ?? const []) : const [],
      ));
    }
    return cells;
  }

  void _goToday() {
    setState(() {
      _selectedKey = KanoTime.dayKey(_today.year, _today.month, _today.day);
    });
    _controller.animateToPage(
      _indexOf(_today.year, _today.month),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
    _refreshCurrent();
  }

  Future<void> _openDay(_Cell cell) async {
    KanoHaptics.select();
    setState(() => _selectedKey = cell.key);
    if (cell.events.isEmpty) return;
    final palette = KanoPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _DaySheet(
        dayKey: cell.key,
        events: cell.events,
        palette: palette,
      ),
    );
  }

  /// 45 天内、最多 6 场
  List<KanoEvent> _upcoming() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const within = 45 * KanoTime.dayMs;
    final seen = <String>{};
    final list = <KanoEvent>[];
    for (final page in _months.values) {
      for (final event in page.events) {
        if (event.cancelled) continue;
        if (event.timeMs <= now - 3 * 3600000 || event.timeMs >= now + within) continue;
        final id = event.id.isEmpty ? '${event.title}|${event.startsOn}' : event.id;
        if (!seen.add(id)) continue;
        list.add(event);
      }
    }
    list.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return list.take(6).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = KanoPalette.of(context);
    final todayIndex = _indexOf(_today.year, _today.month);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final calendar = _calendarColumn(palette);
        final upcoming = _upcomingSection(palette);

        return Stack(
          children: [
            RefreshIndicator(
              color: palette.berry,
              onRefresh: _refreshCurrent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 120),
                children: [
                  _header(palette),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: calendar),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: upcoming),
                      ],
                    )
                  else ...[
                    calendar,
                    const SizedBox(height: 12),
                    upcoming,
                  ],
                ],
              ),
            ),
            // 「今」贴在底栏上方；已经在今天时不出现
            if (_index != todayIndex)
              Positioned(
                right: 16,
                bottom: 100,
                child: _TodayButton(palette: palette, onTap: _goToday),
              ),
          ],
        );
      },
    );
  }

  Widget _header(KanoPalette palette) {
    final (year, month) = _monthOf(_index);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            KanoText.monthTitle(month),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
              height: 1.1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 3),
            child: Text(
              '$year',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 4),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: palette.textSecondary),
              ),
            ),
          const Spacer(),
          if (_source.isStale)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                KanoText.ui('kano_offline_snapshot'),
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// 今天的实心圆用主题色（默认 #FFC0CB），不是莓色。
  Color _themeColor() =>
      KanoPalette.parseHex(SettingsController.instance.themeColor) ?? const Color(0xFFFFC0CB);

  Widget _calendarColumn(KanoPalette palette) {
    // SchedulePage.MonthPanel：圆角 24 + 半透明底 + 薄模糊，日期才不会直接压在壁纸上。
    return KanoSurface(
      radius: 24,
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Column(
      children: [
        _weekRow(palette),
        SizedBox(
          height: 6 * 66 + 5 * 6,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _index = index);
              final (year, month) = _monthOf(index);
              if (!_months.containsKey(_monthKey(year, month))) {
                _loadAround(year, month);
              }
            },
            itemBuilder: (context, index) {
              final (year, month) = _monthOf(index);
              return _monthGrid(year, month, palette);
            },
          ),
        ),
      ],
      ),
    );
  }

  Widget _weekRow(KanoPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                KanoText.weekShort(i),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i >= 5 ? FontWeight.w500 : FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthGrid(int year, int month, KanoPalette palette) {
    final cells = _buildCells(year, month);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: cellWidth / 66,
        mainAxisSpacing: 6,
      ),
      itemCount: cells.length,
      itemBuilder: (context, i) => _dayCell(cells[i], palette),
    );
      },
    );
  }

  Widget _dayCell(_Cell cell, KanoPalette palette) {
    final selected = cell.key == _selectedKey;
    final highlighted = selected || cell.isToday;
    final theme = _themeColor();
    final Color numberColor;
    if (!cell.inMonth) {
      numberColor = palette.textTertiary;
    } else if (cell.isToday) {
      numberColor = Colors.white;
    } else if (selected) {
      numberColor = theme;
    } else if (cell.weekend) {
      numberColor = palette.textSecondary;
    } else {
      numberColor = palette.textPrimary;
    }

    final first = cell.events.isNotEmpty ? cell.events.first : null;

    return GestureDetector(
      onTap: () => _openDay(cell),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cell.isToday ? theme : Colors.transparent,
              border: selected && !cell.isToday
                  ? Border.all(color: theme, width: 1.5)
                  : null,
            ),
            child: Text(
              '${cell.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: highlighted ? FontWeight.bold : FontWeight.w400,
                color: numberColor,
              ),
            ),
          ),
          if (cell.inMonth && cell.events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: [
                  _chip(
                    KanoKind.label(first!.kind()),
                    Color(KanoKind.colorValue(first.kind())),
                  ),
                  if (cell.events.length == 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _chip(
                        KanoKind.label(cell.events[1].kind()),
                        Color(KanoKind.colorValue(cell.events[1].kind())),
                      ),
                    )
                  else if (cell.events.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _chip('+${cell.events.length - 1}', const Color(0xFF495057)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      height: 13,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white, height: 1),
      ),
    );
  }

  Widget _upcomingSection(KanoPalette palette) {
    final items = _upcoming();
    return KanoSurface(
      radius: 24,
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              KanoText.ui('schedule_upcoming'),
              style: TextStyle(fontSize: 14, color: palette.textSecondary),
            ),
          ),
          if (!_firstLoadDone && items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  KanoBlock(height: 14, strong: true),
                  SizedBox(height: 10),
                  KanoBlock(height: 12),
                  SizedBox(height: 8),
                  KanoBlock(width: 160, height: 12),
                ],
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                KanoText.ui('schedule_empty_month'),
                style: TextStyle(fontSize: 13, color: palette.textSecondary, height: 1.5),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _UpcomingRow(
                event: items[i],
                palette: palette,
                onTap: () => _jumpTo(items[i]),
              ),
              if (i < items.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: Divider(height: 1, thickness: 1, color: palette.hairline),
                ),
            ],
        ],
      ),
    );
  }

  void _jumpTo(KanoEvent event) {
    final ms = event.timeMs;
    final target = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    if (target == null) return;
    setState(() => _selectedKey = KanoTime.dayKeyOfMs(ms));
    _controller.animateToPage(
      _indexOf(target.year, target.month),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    if (!_months.containsKey(_monthKey(target.year, target.month))) {
      _loadAround(target.year, target.month);
    }
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.palette, required this.onTap});

  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.berry,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: palette.berry.withValues(alpha: 0.32),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          KanoText.ui('schedule_today'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.event, required this.palette, required this.onTap});

  final KanoEvent event;
  final KanoPalette palette;
  final VoidCallback onTap;

  /// `11/11 周三 · 19:00 JST`。timeText 自己已经带 JST。
  String get _meta {
    final key = event.startsOn;
    if (key.length < 10) return event.timeText();
    final month = int.tryParse(key.substring(5, 7)) ?? 0;
    final day = int.tryParse(key.substring(8, 10)) ?? 0;
    final parsed = DateTime.tryParse(key);
    final weekday = parsed == null ? '' : KanoText.weekFull(parsed.weekday - 1);
    return '$month/$day $weekday · ${event.timeText()}';
  }

  @override
  Widget build(BuildContext context) {
    final kindColor = Color(KanoKind.colorValue(event.kind()));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: kindColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(fontSize: 15, color: palette.textPrimary, height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _meta,
                    style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
              decoration: BoxDecoration(
                color: kindColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.kindLabel(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 某一天的事件弹层
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.dayKey, required this.events, required this.palette});

  final String dayKey;
  final List<KanoEvent> events;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.tryParse(dayKey)?.weekday ?? DateTime.monday;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    KanoTime.dateKeyText(dayKey),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      KanoText.weekFull(weekday - 1),
                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      KanoText.ui('schedule_event_count').replaceFirst('%d', '${events.length}'),
                      style: TextStyle(fontSize: 12, color: palette.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _EventTile(event: events[i], palette: palette),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.palette});

  final KanoEvent event;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    final cancelled = event.cancelled;
    return KanoSurface(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                event.timeMs > 0 ? KanoTime.jstText(event.timeMs) : KanoText.ui('time_tbd'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(KanoKind.colorValue(event.kind())),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.kindLabel(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                event.statusText(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: event.liveStatus == 'live' ? FontWeight.bold : FontWeight.w400,
                  color: event.liveStatus == 'live' ? palette.liveRed : palette.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.35,
              color: cancelled ? palette.textTertiary : palette.textPrimary,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (event.detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.detail,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (event.cancelNote().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.cancelNote(),
              style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.liveRed),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (event.timeMs > 0 && !cancelled)
                GestureDetector(
                  onTap: () => KanoCalendarExport.addEvent(context, event),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 15, color: palette.berry),
                      const SizedBox(width: 4),
                      Text(
                        KanoText.ui('recent_add_to_calendar'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.berry,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (event.url.isNotEmpty)
                GestureDetector(
                  onTap: () => KanoLauncher.open(context, event.url),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text(
                        KanoText.ui('official site'),
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.north_east_rounded, size: 13, color: palette.textSecondary),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
