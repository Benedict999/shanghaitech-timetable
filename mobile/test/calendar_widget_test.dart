import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/features/timetable/weekly_timetable.dart';

import 'calendar_and_storage_test.dart' show sample;

void main() {
  testWidgets(
    'phone header crosses months, shows times and reaches empty week 20',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyTimetable(
              schedule: sample(),
              initialWeek: 3,
              onWeekChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10/1'), findsOneWidget);
      expect(find.text('08:15\n09:00'), findsOneWidget);
      expect(find.textContaining('共 20 周'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('第 4 周'), findsOneWidget);
      expect(find.text('10/1'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 4; i < 20; i++) {
        await tester.tap(find.byTooltip('下一周'));
        await tester.pumpAndSettle();
      }
      expect(find.text('第 20 周'), findsOneWidget);
      expect(find.textContaining('1月25日—1月31日'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('week controls and weekday header scroll away with the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyTimetable(
            schedule: sample(),
            initialWeek: 1,
            onWeekChanged: (_) {},
            hasBackground: true,
            surfaceOpacity: 0,
            translucentCards: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.byKey(const ValueKey('current-week-label'));
    final before = tester.getTopLeft(label).dy;

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(label).dy, lessThan(before - 120));
    expect(tester.takeException(), isNull);
  });
}
