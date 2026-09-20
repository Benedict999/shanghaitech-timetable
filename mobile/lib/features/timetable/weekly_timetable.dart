import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../appearance/app_appearance.dart';
import '../../domain/course_meeting.dart';
import '../../domain/semester_calendar.dart';

class WeeklyTimetable extends StatefulWidget {
  const WeeklyTimetable({
    required this.schedule,
    required this.initialWeek,
    required this.onWeekChanged,
    this.translucentCards = false,
    this.hasBackground = false,
    this.surfaceOpacity = .22,
    this.onConfigure,
    super.key,
  });

  final SyncResult schedule;
  final int initialWeek;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback? onConfigure;
  final bool translucentCards;
  final bool hasBackground;
  final double surfaceOpacity;

  @override
  State<WeeklyTimetable> createState() => _WeeklyTimetableState();
}

class _WeeklyTimetableState extends State<WeeklyTimetable> {
  late int _week;
  late PageController _controller;

  int get _totalWeeks => widget.schedule.calendar.totalWeeks;

  @override
  void initState() {
    super.initState();
    _week = widget.initialWeek.clamp(1, _totalWeeks);
    _controller = PageController(initialPage: _week - 1);
  }

  @override
  void didUpdateWidget(covariant WeeklyTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule.termCode != widget.schedule.termCode ||
        oldWidget.schedule.syncedAt != widget.schedule.syncedAt) {
      _week = _week.clamp(1, _totalWeeks);
      _controller.dispose();
      _controller = PageController(initialPage: _week - 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToWeek(int week) {
    _controller.animateToPage(
      week.clamp(1, _totalWeeks) - 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceAlpha = widget.hasBackground
        ? widget.surfaceOpacity.clamp(0.0, .8)
        : .94;
    final surface = Theme.of(context).colorScheme.surface
        .withValues(alpha: surfaceAlpha);
    return PageView.builder(
      controller: _controller,
      itemCount: _totalWeeks,
      onPageChanged: (index) {
        final week = index + 1;
        setState(() => _week = week);
        widget.onWeekChanged(week);
      },
      itemBuilder: (context, index) {
        final week = index + 1;
        final protectText = widget.hasBackground && surfaceAlpha < .20;
        return SingleChildScrollView(
          key: PageStorageKey('week-scroll-$week'),
          child: ColoredBox(
            color: surface,
            child: Column(
              children: [
                if (!widget.schedule.calendar.confirmed)
                  TextButton.icon(
                    onPressed: widget.onConfigure,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('确认学期日期和总周数后显示日期'),
                  ),
                _WeekHeader(
                  termLabel: widget.schedule.termLabel,
                  calendar: widget.schedule.calendar,
                  syncedAt: widget.schedule.syncedAt,
                  onToday: () => _goToWeek(
                    widget.schedule.calendar.weekAt(
                          SemesterCalendar.schoolToday,
                        ) ??
                        1,
                  ),
                  week: week,
                  totalWeeks: _totalWeeks,
                  onPrevious: week > 1 ? () => _goToWeek(week - 1) : null,
                  onNext: week < _totalWeeks ? () => _goToWeek(week + 1) : null,
                  protectText: protectText,
                ),
                _WeekGrid(
                  key: ValueKey('week-$week'),
                  schedule: widget.schedule,
                  week: week,
                  meetings: mergeMeetingsForWeek(
                    widget.schedule.meetings,
                    week,
                  ),
                  translucentCards: widget.translucentCards,
                  protectText: protectText,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.termLabel,
    required this.week,
    required this.totalWeeks,
    required this.onPrevious,
    required this.onNext,
    required this.calendar,
    required this.syncedAt,
    required this.onToday,
    required this.protectText,
  });

  final String termLabel;
  final int week;
  final int totalWeeks;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final SemesterCalendar calendar;
  final DateTime syncedAt;
  final VoidCallback onToday;
  final bool protectText;

  @override
  Widget build(BuildContext context) {
    final shadows = _protectiveShadows(context, protectText);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上一周',
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left_rounded, shadows: shadows),
              ),
              Expanded(
                child: Text(
                  '第 $week 周',
                  key: const ValueKey('current-week-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, shadows: shadows),
                ),
              ),
              IconButton(
                tooltip: '下一周',
                onPressed: onNext,
                icon: Icon(Icons.chevron_right_rounded, shadows: shadows),
              ),
            ],
          ),
          Text(
            calendar.confirmed
                ? _dateRange(calendar, week)
                : '$termLabel · 总周数待确认',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              shadows: shadows,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '上次同步 ${syncedAt.month}/${syncedAt.day} ${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(shadows: shadows),
              ),
              if (calendar.confirmed)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: protectText
                        ? Theme.of(context).colorScheme.surface
                              .withValues(alpha: .62)
                        : null,
                  ),
                  onPressed: onToday,
                  child: Text(_termStatus(calendar)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.meetings,
    required this.schedule,
    required this.week,
    required this.translucentCards,
    required this.protectText,
    super.key,
  });

  final List<CourseMeeting> meetings;
  final SyncResult schedule;
  final int week;
  final bool translucentCards;
  final bool protectText;

  static const _periods = 13;
  static const _headerHeight = 54.0;
  static const _rowHeight = 54.0;
  static const _periodWidth = 46.0;

  @override
  Widget build(BuildContext context) {
    final gridHeight = _headerHeight + _periods * _rowHeight;
    final shadows = _protectiveShadows(context, protectText);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final dayWidth = (width - _periodWidth) / 7;
          return SizedBox(
            width: width,
            height: gridHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: _periodWidth,
                  height: _headerHeight,
                  child: Center(
                    child: Text(
                      _monthLabel(schedule.calendar, week),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, shadows: shadows),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size(width, gridHeight),
                  painter: _GridPainter(
                    color: _gridColor(context, protectText),
                    periodWidth: _periodWidth,
                    headerHeight: _headerHeight,
                    rowHeight: _rowHeight,
                    dayWidth: dayWidth,
                    periods: _periods,
                  ),
                ),
                for (var day = 0; day < 7; day++)
                  Positioned(
                    left: _periodWidth + day * dayWidth,
                    top: 0,
                    width: dayWidth,
                    height: _headerHeight,
                    child: _DayHeader(
                      day: day,
                      protectText: protectText,
                      date: schedule.calendar.confirmed
                          ? schedule.calendar.dateFor(week, day + 1)
                          : null,
                    ),
                  ),
                for (var period = 1; period <= _periods; period++)
                  Positioned(
                    left: 0,
                    top: _headerHeight + (period - 1) * _rowHeight,
                    width: _periodWidth,
                    height: _rowHeight,
                    child: Center(
                      child: Text(
                        schedule.timeFor(period) == null
                            ? '$period\n待同步'
                            : '${schedule.timeFor(period)!.start}\n${schedule.timeFor(period)!.end}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          shadows: shadows,
                        ),
                      ),
                    ),
                  ),
                for (final meeting in meetings)
                  if (meeting.weekday >= 1 &&
                      meeting.weekday <= 7 &&
                      meeting.startPeriod >= 1 &&
                      meeting.startPeriod <= _periods)
                    Positioned(
                      left:
                          _periodWidth + (meeting.weekday - 1) * dayWidth + 1.5,
                      top:
                          _headerHeight +
                          (meeting.startPeriod - 1) * _rowHeight +
                          1.5,
                      width: dayWidth - 3,
                      height:
                          (math.min(meeting.endPeriod, _periods) -
                                  meeting.startPeriod +
                                  1) *
                              _rowHeight -
                          3,
                      child: _CourseBlock(
                        meeting: meeting,
                        schedule: schedule,
                        week: week,
                        translucent: translucentCards,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.meeting,
    required this.schedule,
    required this.week,
    required this.translucent,
  });

  final CourseMeeting meeting;
  final SyncResult schedule;
  final int week;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF4F7FA)
        : const Color(0xFF172326);
    final cardLocation = splitLocationForCard(meeting.location);
    return Material(
      color: _courseColor(
        context,
        meeting,
      ).withValues(alpha: translucent ? .82 : 1),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, meeting, schedule, week),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showLocation =
                  meeting.location.isNotEmpty && constraints.maxHeight > 70;
              final locationStyle = TextStyle(
                color: textColor.withValues(alpha: .85),
                fontSize: 9.5,
                height: 1.1,
              );
              return Semantics(
                label: meeting.location.isEmpty
                    ? meeting.courseName
                    : '${meeting.courseName}，教室 ${meeting.location}',
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          meeting.courseName,
                          textAlign: TextAlign.center,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10.5,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (showLocation) ...[
                      const SizedBox(height: 2),
                      if (cardLocation.room.isNotEmpty &&
                          cardLocation.prefix.isNotEmpty)
                        Text(
                          cardLocation.prefix,
                          textAlign: TextAlign.center,
                          maxLines: constraints.maxHeight >= 145 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: locationStyle,
                        ),
                      if (cardLocation.room.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 12,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              cardLocation.room,
                              maxLines: 1,
                              style: locationStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          cardLocation.prefix,
                          textAlign: TextAlign.center,
                          maxLines: constraints.maxHeight >= 145 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: locationStyle,
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.color,
    required this.periodWidth,
    required this.headerHeight,
    required this.rowHeight,
    required this.dayWidth,
    required this.periods,
  });

  final Color color;
  final double periodWidth;
  final double headerHeight;
  final double rowHeight;
  final double dayWidth;
  final int periods;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .7;
    for (var column = 0; column <= 7; column++) {
      final x = periodWidth + column * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawLine(
      Offset(0, headerHeight),
      Offset(size.width, headerHeight),
      paint,
    );
    for (var row = 1; row <= periods; row++) {
      final y = headerHeight + row * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dayWidth != dayWidth;
}

List<CourseMeeting> mergeMeetingsForWeek(
  Iterable<CourseMeeting> meetings,
  int week,
) {
  final filtered =
      meetings.where((meeting) => meeting.weeks.contains(week)).toList()
        ..sort((a, b) {
          final day = a.weekday.compareTo(b.weekday);
          if (day != 0) return day;
          return a.startPeriod.compareTo(b.startPeriod);
        });
  final merged = <CourseMeeting>[];
  for (final current in filtered) {
    final index = merged.lastIndexWhere(
      (existing) =>
          existing.weekday == current.weekday &&
          existing.courseCode == current.courseCode &&
          existing.courseName == current.courseName &&
          existing.classCode == current.classCode &&
          existing.teacher == current.teacher &&
          existing.location == current.location &&
          existing.periodSchemeId == current.periodSchemeId &&
          current.startPeriod <= existing.endPeriod + 1,
    );
    if (index < 0) {
      merged.add(current);
      continue;
    }
    final existing = merged[index];
    merged[index] = CourseMeeting(
      courseCode: existing.courseCode,
      courseName: existing.courseName,
      classCode: existing.classCode,
      weekText: existing.weeks.join(',') == current.weeks.join(',')
          ? existing.weekText
          : '第 $week 周（此色块按本周合并）',
      weeks: existing.weeks.join(',') == current.weeks.join(',')
          ? existing.weeks
          : [week],
      weekday: existing.weekday,
      startPeriod: math.min(existing.startPeriod, current.startPeriod),
      endPeriod: math.max(existing.endPeriod, current.endPeriod),
      teacher: existing.teacher,
      location: existing.location,
      periodSchemeId: existing.periodSchemeId,
    );
  }
  return merged;
}

Color _courseColor(BuildContext context, CourseMeeting meeting) {
  final palette =
      Theme.of(context).extension<TimetableVisuals>()?.coursePalette ??
      const <Color>[
        Color(0xFFB8E3E8),
        Color(0xFFFFD5C7),
        Color(0xFFFFE9A8),
        Color(0xFFC9D7FF),
        Color(0xFFDCC9F5),
        Color(0xFFBFE3CA),
        Color(0xFFF3C4DA),
        Color(0xFFC7DFEF),
      ];
  final identity = meeting.courseCode.isNotEmpty
      ? meeting.courseCode
      : meeting.courseName;
  var stableHash = 0;
  for (final codeUnit in identity.codeUnits) {
    stableHash = (stableHash * 31 + codeUnit) & 0x7fffffff;
  }
  return palette[stableHash % palette.length];
}

({String prefix, String room}) splitLocationForCard(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return (prefix: '', room: '');

  // The school normally returns values such as "物质学院 1-201". Keep the
  // final room identifier in its own widget so a long building/department name
  // can never consume the line that contains the useful room number.
  final separated = RegExp(
    r'^(.*?)[\s　]+([A-Za-z0-9]+(?:[._\-–—][A-Za-z0-9]+)+)$',
  ).firstMatch(normalized);
  if (separated != null) {
    return (
      prefix: separated.group(1)!.trim(),
      room: separated.group(2)!.trim(),
    );
  }

  // Also tolerate a missing separator, for example "物质学院1-201".
  final joined = RegExp(r'^(.+?)([A-Za-z]?\d+(?:[._\-–—][A-Za-z0-9]+)+)$')
      .firstMatch(normalized);
  if (joined != null) {
    return (prefix: joined.group(1)!.trim(), room: joined.group(2)!.trim());
  }
  final joinedDigits = RegExp(r'^(.+?\D)(\d+)$').firstMatch(normalized);
  if (joinedDigits != null) {
    return (
      prefix: joinedDigits.group(1)!.trim(),
      room: joinedDigits.group(2)!.trim(),
    );
  }
  return (prefix: normalized, room: '');
}

void _showDetails(
  BuildContext context,
  CourseMeeting meeting,
  SyncResult schedule,
  int week,
) {
  final start = schedule.timeFor(
    meeting.startPeriod,
    scheme: meeting.periodSchemeId,
  );
  final end = schedule.timeFor(
    meeting.endPeriod,
    scheme: meeting.periodSchemeId,
  );
  final date = schedule.calendar.confirmed
      ? schedule.calendar.dateFor(week, meeting.weekday)
      : null;
  final periods = meeting.startPeriod == meeting.endPeriod
      ? '第 ${meeting.startPeriod} 节'
      : '第 ${meeting.startPeriod}–${meeting.endPeriod} 节';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meeting.courseName,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.schedule_rounded, text: periods),
            _DetailRow(
              icon: Icons.access_time,
              text: start != null && end != null
                  ? '${start.start}—${end.end}'
                  : '具体时间待同步',
            ),
            if (date != null)
              _DetailRow(
                icon: Icons.today,
                text: '${date.year}年${date.month}月${date.day}日',
              ),
            _DetailRow(icon: Icons.date_range_rounded, text: meeting.weekText),
            if (meeting.location.isNotEmpty)
              _DetailRow(icon: Icons.place_outlined, text: meeting.location),
            if (meeting.teacher.isNotEmpty)
              _DetailRow(icon: Icons.person_outline, text: meeting.teacher),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _dateRange(SemesterCalendar calendar, int week) {
  final a = calendar.dateFor(week, 1)!;
  final b = calendar.dateFor(week, 7)!;
  final years = a.year != b.year;
  return '${years ? '${a.year}年' : ''}${a.month}月${a.day}日—${years ? '${b.year}年' : ''}${b.month}月${b.day}日 · 共 ${calendar.totalWeeks} 周';
}

String _monthLabel(SemesterCalendar calendar, int week) {
  if (!calendar.confirmed) return '时间';
  final a = calendar.dateFor(week, 1)!;
  final b = calendar.dateFor(week, 7)!;
  return a.month == b.month ? '${a.month}月' : '${a.month}/${b.month}\n月';
}

String _termStatus(SemesterCalendar calendar) {
  final current = calendar.weekAt(SemesterCalendar.schoolToday)!;
  if (current < 1) return '尚未开学 · 回到第1周';
  if (current > calendar.totalWeeks) return '本学期已结束 · 查看最后一周';
  return '回到本周 · 第 $current 周';
}

List<Shadow>? _protectiveShadows(BuildContext context, bool enabled) {
  if (!enabled) return null;
  final color = Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .9)
      : Colors.white.withValues(alpha: .95);
  return [Shadow(color: color, blurRadius: 1.5, offset: const Offset(0, 1))];
}

Color _gridColor(BuildContext context, bool protectText) {
  if (protectText) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .42)
        : Colors.black.withValues(alpha: .38);
  }
  return Theme.of(context).extension<TimetableVisuals>()?.gridColor ??
      Theme.of(context).dividerColor.withValues(alpha: .5);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.date,
    required this.protectText,
  });
  final int day;
  final DateTime? date;
  final bool protectText;
  @override
  Widget build(BuildContext context) {
    final today = date == SemesterCalendar.schoolToday;
    final color = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          ['一', '二', '三', '四', '五', '六', '日'][day],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            shadows: _protectiveShadows(context, protectText),
          ),
        ),
        if (date != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: today ? color.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              date!.day == 1 && day != 0 ? '${date!.month}/1' : '${date!.day}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                color: today ? color.onPrimary : color.onSurfaceVariant,
                shadows: today
                    ? null
                    : _protectiveShadows(context, protectText),
              ),
            ),
          ),
      ],
    );
  }
}
