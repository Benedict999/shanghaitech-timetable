import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shanghaitech_timetable/appearance/app_appearance.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';
import 'package:shanghaitech_timetable/domain/semester_calendar.dart';
import 'package:shanghaitech_timetable/features/timetable/weekly_timetable.dart';

void main() {
  testWidgets('render phone preview with synthetic courses', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('PreviewChinese');
      font.addFont(
        File('C:/Windows/Fonts/msyh.ttc')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File(
          '../.toolchains/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
      await icons.load();
    });
    tester.view.physicalSize = const Size(432, 936);
    tester.view.devicePixelRatio = 1;
    final schedule = SyncResult(
      termCode: 'demo',
      termLabel: '示例学期',
      syncedAt: DateTime(2026, 9, 20, 10, 30),
      calendar: SemesterCalendar(
        firstMonday: DateTime.utc(2026, 9, 14),
        totalWeeks: 20,
        source: '演示',
        verifiedAt: DateTime(2026, 9, 20),
      ),
      periodTimes: [
        for (var i = 1; i <= 13; i++)
          PeriodTime(
            period: i,
            start: [
              '08:15',
              '09:10',
              '10:15',
              '11:10',
              '13:00',
              '13:55',
              '15:00',
              '15:55',
              '16:50',
              '18:00',
              '18:55',
              '19:50',
              '20:45',
            ][i - 1],
            end: [
              '09:00',
              '09:55',
              '11:00',
              '11:55',
              '13:45',
              '14:40',
              '15:45',
              '16:40',
              '17:35',
              '18:45',
              '19:40',
              '20:35',
              '21:30',
            ][i - 1],
          ),
      ],
      meetings: [
        for (var i = 1; i <= 5; i++)
          CourseMeeting(
            courseCode: 'demo$i',
            courseName: ['高等数学', '学术英语', '材料研究方法', '光子科学导论', '实验室安全'][i - 1],
            classCode: 'demo$i',
            weekText: '1-16周',
            weeks: List.generate(16, (i) => i + 1),
            weekday: i,
            startPeriod: i == 2 ? 1 : 2,
            endPeriod: i == 2 ? 2 : 4,
            teacher: '示例教师',
            location: '教学楼 101',
            periodSchemeId: '',
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppThemePreset.shanghaitech, Brightness.light)
            .copyWith(
              textTheme: ThemeData(fontFamily: 'PreviewChinese').textTheme,
            ),
        home: Scaffold(
          appBar: AppBar(
            title: SvgPicture.asset(
              'assets/branding/shanghaitech_logo_red.svg',
              height: 34,
            ),
            actions: const [
              Icon(Icons.sync),
              SizedBox(width: 20),
              Icon(Icons.settings_outlined),
              SizedBox(width: 14),
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF78C5D6),
                  Color(0xFFE9C4D4),
                  Color(0xFF6D8AC8),
                ],
              ),
            ),
            child: WeeklyTimetable(
              schedule: schedule,
              initialWeek: 1,
              onWeekChanged: (_) {},
              translucentCards: true,
              hasBackground: true,
              surfaceOpacity: .22,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../captures/v0.4.1-phone-preview.png'),
    );
  });
}
