import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../appearance/app_appearance.dart';
import '../../data/appearance_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/course_meeting.dart';
import '../../domain/semester_calendar.dart';
import '../../domain/schedule_diff.dart';
import 'calendar_settings_page.dart';
import '../settings/settings_page.dart';
import '../sync/school_login_page.dart';
import '../timetable/weekly_timetable.dart';

class HomePage extends StatefulWidget {
  const HomePage({this.store, this.appearanceController, super.key});

  final ScheduleStore? store;
  final AppearanceController? appearanceController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScheduleStore _store;
  SyncResult? _schedule;
  var _selectedWeek = 1;
  var _loading = true;
  String? _loadError;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ScheduleRepository();
    _loadSavedSchedule();
  }

  Future<void> _loadSavedSchedule() async {
    try {
      final schedule = await _store.load();
      final selectedWeek = await _store.loadSelectedWeek();
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _selectedWeek =
            schedule?.calendar.weekAt(SemesterCalendar.schoolToday) ??
            selectedWeek ??
            1;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '本地课表读取失败，原数据仍保留。请重试。';
        });
      }
    }
  }

  Future<void> _startSync() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Navigator.of(context).push<SyncResult>(
        MaterialPageRoute(builder: (_) => const SchoolLoginPage()),
      );
      if (result == null || !mounted) return;
      if (result.meetings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('学校返回空课表，已保留原课表。请检查学期和登录状态。')),
        );
        return;
      }
      final candidate = result.retainSettings(_schedule);
      final changes = scheduleChanges(_schedule, candidate);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认同步'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.termLabel),
                  const SizedBox(height: 12),
                  if (changes.isEmpty) const Text('课程安排没有变化，将更新同步时间。'),
                  for (final change in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(change),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留原课表'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存新课表'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      try {
        await _store.save(candidate);
        if (!mounted) return;
        setState(() {
          _schedule = candidate;
          _selectedWeek =
              (candidate.calendar.weekAt(SemesterCalendar.schoolToday) ??
                      _selectedWeek)
                  .clamp(1, candidate.calendar.totalWeeks);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('课表已同步并保存到手机')));
      } on Object {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('课表已读取，但保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCalendar() async {
    final value = await Navigator.of(context).push<SyncResult>(
      MaterialPageRoute(
        builder: (_) => CalendarSettingsPage(schedule: _schedule!),
      ),
    );
    if (value == null || !mounted) return;
    try {
      await _store.save(value);
      if (mounted) {
        setState(() {
          _schedule = value;
          _selectedWeek =
              (value.calendar.weekAt(SemesterCalendar.schoolToday) ?? 1).clamp(
                1,
                value.calendar.totalWeeks,
              );
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，原课表仍保留')));
      }
    }
  }

  Future<void> _openSettings() async {
    final appearance = widget.appearanceController;
    if (appearance == null) return;
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          store: _store,
          appearance: appearance,
          hasSchedule: _schedule != null,
          onEditCalendar: _schedule == null
              ? null
              : () {
                  Navigator.pop(context);
                  _editCalendar();
                },
        ),
      ),
    );
    if (restored == true) {
      setState(() => _loading = true);
      await _loadSavedSchedule();
    }
  }

  void _rememberWeek(int week) {
    _selectedWeek = week;
    _store.saveSelectedWeek(week).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final appearance =
        widget.appearanceController?.value ?? const AppAppearance();
    final background = appearance.backgroundPath;
    final hasBackground = background != null && File(background).existsSync();
    final backgroundCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(720, 1440);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        if (hasBackground)
          Positioned.fill(
            child: RepaintBoundary(
              child: ClipRect(
                child: Transform.scale(
                  scale: appearance.backgroundScale,
                  child: Image.file(
                    File(background),
                    fit: BoxFit.cover,
                    cacheWidth: backgroundCacheWidth,
                    filterQuality: FilterQuality.medium,
                    alignment: Alignment(
                      appearance.backgroundX,
                      appearance.backgroundY,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (hasBackground)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: appearance.backgroundOverlay,
                ),
              ),
            ),
          ),
        Scaffold(
          backgroundColor: appearance.hasBackground ? Colors.transparent : null,
          appBar: AppBar(
            titleSpacing: 16,
            foregroundColor: appearance.hasBackground ? Colors.white : null,
            title: widget.appearanceController == null
                ? const Text('上科大课表')
                : _UniversityLogo(hasBackground: appearance.hasBackground),
            actions: [
              if (_schedule != null)
                IconButton(
                  tooltip: '同步课表',
                  onPressed: _busy ? null : _startSync,
                  icon: const Icon(Icons.sync_rounded),
                ),
              if (widget.appearanceController != null)
                IconButton(
                  tooltip: '设置',
                  onPressed: _busy ? null : _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loadError = null;
                              _loading = true;
                            });
                            _loadSavedSchedule();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _schedule == null
                ? _EmptySchedule(onSync: _startSync)
                : WeeklyTimetable(
                    key: ValueKey(
                      '${_schedule!.syncedAt}-${_schedule!.calendar.verifiedAt}',
                    ),
                    schedule: _schedule!,
                    initialWeek: _selectedWeek,
                    onWeekChanged: _rememberWeek,
                    onConfigure: _editCalendar,
                    translucentCards:
                        appearance.cardStyle == TimetableCardStyle.translucent,
                    hasBackground: hasBackground,
                    surfaceOpacity: appearance.timetableSurfaceOpacity,
                  ),
          ),
        ),
      ],
    );
  }
}

class _UniversityLogo extends StatelessWidget {
  const _UniversityLogo({required this.hasBackground});
  final bool hasBackground;

  @override
  Widget build(BuildContext context) {
    final white =
        hasBackground || Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '上海科技大学',
      child: SvgPicture.asset(
        white
            ? 'assets/branding/shanghaitech_logo_white.svg'
            : 'assets/branding/shanghaitech_logo_red.svg',
        height: 34,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onSync});

  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  '导入你的课表',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  '第一次需要登录上海科技大学官方页面。同步成功后，课表会保存在手机里，以后打开应用可以直接查看。\n\n应用不会保存你的密码。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('登录并读取课表'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
