import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/appearance/app_appearance.dart';
import 'package:shanghaitech_timetable/data/backup_document.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';
import 'package:shanghaitech_timetable/domain/semester_calendar.dart';

void main() {
  test('complete backup round-trips schedule, appearance and background', () {
    final backup = TimetableBackup(
      createdAt: DateTime(2026, 9, 20, 20, 30),
      appVersion: '1.0.1',
      schedule: _schedule(),
      appearance: const AppAppearance(
        preset: AppThemePreset.shanghaitech,
        themePreference: AppThemePreference.dark,
        cardStyle: TimetableCardStyle.translucent,
        backgroundOverlay: .4,
        timetableSurfaceOpacity: .15,
        backgroundScale: 1.5,
        backgroundX: -.2,
        backgroundY: .3,
      ),
      backgroundBytes: const [1, 2, 3, 4, 5],
      backgroundExtension: 'png',
    );

    final restored = TimetableBackup.decode(backup.encode());
    expect(restored.appVersion, '1.0.1');
    expect(restored.schedule.termCode, '20261');
    expect(restored.schedule.meetings.single.courseName, '示例课程');
    expect(restored.appearance.preset, AppThemePreset.shanghaitech);
    expect(restored.appearance.cardStyle, TimetableCardStyle.translucent);
    expect(restored.appearance.backgroundScale, 1.5);
    expect(restored.appearance.timetableSurfaceOpacity, .15);
    expect(restored.appearance.backgroundPath, isNull);
    expect(restored.backgroundBytes, [1, 2, 3, 4, 5]);
    expect(restored.backgroundExtension, 'png');
  });

  test('backup rejects a changed payload', () {
    final encoded = TimetableBackup(
      createdAt: DateTime(2026, 9, 20),
      schedule: _schedule(),
      appearance: const AppAppearance(),
    ).encode();
    final changed = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    final schedule = Map<String, dynamic>.from(changed['schedule'] as Map);
    schedule['termLabel'] = '被修改的学期';
    changed['schedule'] = schedule;

    expect(
      () => TimetableBackup.decode(jsonEncode(changed)),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown appearance values safely fall back to defaults', () {
    final appearance = AppAppearance.fromJson({
      'preset': 'unknown',
      'themePreference': 'unknown',
      'cardStyle': 'unknown',
      'backgroundOverlay': 99,
      'backgroundScale': 99,
      'timetableSurfaceOpacity': -2,
      'backgroundX': -9,
      'backgroundY': 9,
    });
    expect(appearance.preset, AppThemePreset.clean);
    expect(appearance.themePreference, AppThemePreference.preset);
    expect(appearance.cardStyle, TimetableCardStyle.solid);
    expect(appearance.backgroundOverlay, .75);
    expect(appearance.backgroundScale, 2.5);
    expect(appearance.timetableSurfaceOpacity, 0);
    expect(appearance.backgroundX, -1);
    expect(appearance.backgroundY, 1);
  });
}

SyncResult _schedule() => SyncResult(
  termCode: '20261',
  termLabel: '2026-2027学年 第一学期',
  syncedAt: DateTime(2026, 9, 20),
  calendar: SemesterCalendar(
    firstMonday: DateTime.utc(2026, 9, 14),
    totalWeeks: 20,
    source: '用户确认',
    verifiedAt: DateTime(2026, 9, 20),
  ),
  meetings: const [
    CourseMeeting(
      courseCode: 'TEST',
      courseName: '示例课程',
      classCode: '01',
      weekText: '1-2周',
      weeks: [1, 2],
      weekday: 1,
      startPeriod: 1,
      endPeriod: 2,
      teacher: '教师',
      location: '教室',
      periodSchemeId: '01',
    ),
  ],
);
