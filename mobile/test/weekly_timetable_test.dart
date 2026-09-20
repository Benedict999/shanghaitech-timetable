import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';
import 'package:shanghaitech_timetable/features/timetable/weekly_timetable.dart';

void main() {
  test(
    'filters other weeks and merges adjacent periods of the same course',
    () {
      final meetings = [
        _meeting(start: 2, end: 2, weeks: const [1, 2]),
        _meeting(start: 3, end: 4, weeks: const [1]),
        _meeting(start: 5, end: 5, weeks: const [2]),
      ];

      final weekOne = mergeMeetingsForWeek(meetings, 1);
      expect(weekOne, hasLength(1));
      expect(weekOne.single.startPeriod, 2);
      expect(weekOne.single.endPeriod, 4);

      final weekTwo = mergeMeetingsForWeek(meetings, 2);
      expect(weekTwo, hasLength(2));
    },
  );

  test('saved schedule JSON can be restored', () {
    final original = SyncResult(
      termCode: '2026-1',
      termLabel: '第一学期',
      meetings: [
        _meeting(start: 2, end: 4, weeks: const [1, 3]),
      ],
      syncedAt: DateTime(2026, 9, 19, 8, 30),
    );

    final restored = SyncResult.fromJson(original.toJson());
    expect(restored.termCode, original.termCode);
    expect(restored.syncedAt, original.syncedAt);
    expect(restored.meetings.single.weeks, [1, 3]);
    expect(restored.meetings.single.endPeriod, 4);
  });

  test(
    'separates a room number so it cannot be truncated with the building',
    () {
      expect(splitLocationForCard('物质学院 1-201'), (
        prefix: '物质学院',
        room: '1-201',
      ));
      expect(splitLocationForCard('物质学院4-122'), (
        prefix: '物质学院',
        room: '4-122',
      ));
      expect(splitLocationForCard('教学中心102'), (prefix: '教学中心', room: '102'));
      expect(splitLocationForCard('在线教学'), (prefix: '在线教学', room: ''));
    },
  );

  testWidgets('a narrow three-period card keeps the complete room number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyTimetable(
            schedule: SyncResult(
              termCode: '2026-1',
              termLabel: '第一学期',
              meetings: [
                CourseMeeting(
                  courseCode: 'PHY1001',
                  courseName: '高等量子力学（上）',
                  classCode: '01',
                  weekText: '1-16周',
                  weeks: const [1],
                  weekday: 1,
                  startPeriod: 2,
                  endPeriod: 4,
                  teacher: '教师',
                  location: '物质学院 1-201',
                  periodSchemeId: '01',
                ),
              ],
              syncedAt: DateTime(2026, 9, 20),
            ),
            initialWeek: 1,
            onWeekChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1-201'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

CourseMeeting _meeting({
  required int start,
  required int end,
  required List<int> weeks,
}) => CourseMeeting(
  courseCode: 'PHY1001',
  courseName: '示例课程',
  classCode: '01',
  weekText: '测试周次',
  weeks: weeks,
  weekday: 1,
  startPeriod: start,
  endPeriod: end,
  teacher: '教师',
  location: '教室',
  periodSchemeId: '01',
);
