import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/appearance/app_appearance.dart';
import 'package:shanghaitech_timetable/data/appearance_repository.dart';
import 'package:shanghaitech_timetable/data/schedule_repository.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';
import 'package:shanghaitech_timetable/features/home/home_page.dart';

void main() {
  testWidgets('shows the safe school sync entry point with no saved schedule', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomePage(store: _MemoryStore())));
    await tester.pumpAndSettle();

    expect(find.text('上科大课表'), findsOneWidget);
    expect(find.text('登录并读取课表'), findsOneWidget);
    expect(find.textContaining('应用不会保存你的密码'), findsOneWidget);
  });

  testWidgets('opens a saved schedule and switches weeks', (tester) async {
    final store = _MemoryStore(schedule: _schedule(), selectedWeek: 1);
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('第 1 周'), findsOneWidget);
    expect(find.text('第一周课程'), findsOneWidget);
    expect(find.text('第二周课程'), findsNothing);

    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 周'), findsOneWidget);
    expect(find.text('第一周课程'), findsNothing);
    expect(find.text('第二周课程'), findsOneWidget);
    expect(store.selectedWeek, 2);
  });

  testWidgets('v0.4 settings fit a phone and expose themes and backup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appearance = AppearanceController(_MemoryAppearanceRepository());
    await appearance.load();
    addTearDown(appearance.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          store: _MemoryStore(schedule: _schedule()),
          appearanceController: appearance,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('简洁白'), findsOneWidget);
    expect(find.text('背景收藏与历史'), findsOneWidget);
    expect(find.text('导出完整备份'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
    expect(find.textContaining('作者：夜斗绽星明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SyncResult _schedule() => SyncResult(
  termCode: '2026-1',
  termLabel: '2026-2027学年 第一学期',
  syncedAt: DateTime(2026, 9, 19),
  meetings: [
    _meeting(name: '第一周课程', weeks: const [1]),
    _meeting(name: '第二周课程', weeks: const [2], weekday: 2),
  ],
);

CourseMeeting _meeting({
  required String name,
  required List<int> weeks,
  int weekday = 1,
}) => CourseMeeting(
  courseCode: name,
  courseName: name,
  classCode: '01',
  weekText: '${weeks.join(',')}周',
  weeks: weeks,
  weekday: weekday,
  startPeriod: 2,
  endPeriod: 4,
  teacher: '教师',
  location: '教学楼 101',
  periodSchemeId: '01',
);

class _MemoryStore implements ScheduleStore {
  _MemoryStore({this.schedule, this.selectedWeek});

  SyncResult? schedule;
  int? selectedWeek;

  @override
  Future<SyncResult?> load() async => schedule;

  @override
  Future<int?> loadSelectedWeek() async => selectedWeek;

  @override
  Future<void> save(SyncResult schedule) async {
    this.schedule = schedule;
  }

  @override
  Future<void> saveSelectedWeek(int week) async {
    selectedWeek = week;
  }
}

class _MemoryAppearanceRepository implements AppearanceStore {
  AppAppearance value = const AppAppearance();
  final backgrounds = <BackgroundEntry>[];

  @override
  Future<AppAppearance> load() async => value;

  @override
  Future<void> save(AppAppearance value) async {
    this.value = value;
  }

  @override
  Future<void> removeBackground(String? path) async {}

  @override
  Future<List<BackgroundEntry>> loadBackgrounds(String? activePath) async =>
      backgrounds;

  @override
  Future<void> setBackgroundFavorite(String path, bool favorite) async {}

  @override
  Future<String> saveBackgroundBytes(
    List<int> bytes, {
    String extension = 'jpg',
  }) async => 'memory/background.$extension';
}
