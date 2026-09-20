import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shanghaitech_timetable/data/schedule_repository.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';
import 'package:shanghaitech_timetable/domain/semester_calendar.dart';
import 'package:shanghaitech_timetable/domain/schedule_diff.dart';

void main() {
  test(
    'calendar crosses month/year and does not clamp outside-semester weeks',
    () {
      final c = SemesterCalendar(
        firstMonday: DateTime.utc(2026, 9, 14),
        totalWeeks: 20,
        verifiedAt: DateTime(2026),
        source: '用户确认',
      );
      expect(c.weekAt(DateTime(2026, 9, 13)), 0);
      expect(c.weekAt(DateTime(2026, 9, 20)), 1);
      expect(c.weekAt(DateTime(2026, 9, 21)), 2);
      expect(c.dateFor(3, 4), DateTime.utc(2026, 10, 1));
      expect(c.dateFor(20, 7), DateTime.utc(2027, 1, 31));
      expect(c.weekAt(DateTime(2027, 2, 1)), 21);
      expect(const SemesterCalendar().weekAt(DateTime(2026, 9, 20)), isNull);
    },
  );

  test('time schemes and pending date suggestion survive serialization', () {
    final s = sample();
    final copy = SyncResult.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(copy.timeFor(1, scheme: '01')!.start, '08:15');
    expect(copy.calendar.totalWeeks, 20);
    expect(copy.maxWeek, 2);
    expect(copy.calendar.confirmed, isTrue);
    final fresh = sample(room: '新教室');
    final diff = scheduleChanges(s, fresh);
    expect(diff.any((s) => s.startsWith('新增：') && s.contains('新教室')), isTrue);
    expect(diff.any((s) => s.startsWith('移除：') && s.contains('旧教室')), isTrue);
    expect(scheduleChanges(s, copy), isEmpty);
  });

  test('v0.2 migration is idempotent and failed save rolls back both current and history', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: ScheduleRepository.createSchema,
      ),
    );
    addTearDown(db.close);
    final oldJson = sample().toJson()
      ..remove('calendar')
      ..remove('periodTimes');
    var reads = 0;
    final store = ScheduleRepository(
      database: Future.value(db),
      legacyReader: () async {
        reads++;
        return jsonEncode(oldJson);
      },
    );
    final migrated = await store.load();
    expect(migrated!.calendar.confirmed, isFalse);
    expect(migrated.meetings.single.location, '旧教室');
    expect((await store.load())!.meetings, hasLength(1));
    expect(reads, 1);
    await store.save(sample());
    expect((await store.load())!.calendar.confirmed, isTrue);
    final count = (await db.query('snapshots')).length;
    await db.execute(
      "CREATE TRIGGER fail_test BEFORE INSERT ON meetings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      store.save(sample(room: '新教室')),
      throwsA(isA<DatabaseException>()),
    );
    expect((await store.load())!.meetings.single.location, '旧教室');
    expect((await db.query('snapshots')).length, count);
  });
}

SyncResult sample({String room = '旧教室'}) => SyncResult(
  termCode: '20261',
  termLabel: '第一学期',
  syncedAt: DateTime(2026, 9, 20),
  calendar: SemesterCalendar(
    firstMonday: DateTime.utc(2026, 9, 14),
    totalWeeks: 20,
    verifiedAt: DateTime(2026, 9, 20),
    source: '用户确认',
  ),
  periodTimes: const [
    PeriodTime(period: 1, start: '08:15', end: '09:00', scheme: '01'),
  ],
  meetings: [
    CourseMeeting(
      courseCode: 'TEST',
      courseName: '示例课程',
      classCode: '01',
      weekText: '1-2周',
      weeks: const [1, 2],
      weekday: 1,
      startPeriod: 1,
      endPeriod: 1,
      teacher: '示例教师',
      location: room,
      periodSchemeId: '01',
    ),
  ],
);
