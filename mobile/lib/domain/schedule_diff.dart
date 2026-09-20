import 'dart:convert';

import 'course_meeting.dart';

/// Compare individual teaching periods so splitting a block is not a change.
List<String> scheduleChanges(SyncResult? before, SyncResult after) {
  if (before == null || before.termCode != after.termCode) {
    return ['导入 ${after.termLabel}，共 ${after.meetings.length} 条排课安排'];
  }
  Map<String, String> expand(SyncResult data) {
    final result = <String, String>{};
    for (final c in data.meetings) {
      for (final week in c.weeks) {
        for (var period = c.startPeriod; period <= c.endPeriod; period++) {
          final key = jsonEncode([
            c.courseCode,
            c.classCode,
            c.courseName,
            week,
            c.weekday,
            period,
            c.teacher,
            c.location,
            c.periodSchemeId,
          ]);
          result[key] =
              '${c.courseName} · 第 $week 周 周${['一', '二', '三', '四', '五', '六', '日'][c.weekday - 1]} 第 $period 节'
              '${c.location.isEmpty ? '' : ' · ${c.location}'}${c.teacher.isEmpty ? '' : ' · ${c.teacher}'}';
        }
      }
    }
    return result;
  }

  final old = expand(before);
  final next = expand(after);
  return [
    for (final key in old.keys)
      if (!next.containsKey(key)) '移除：${old[key]}',
    for (final key in next.keys)
      if (!old.containsKey(key)) '新增：${next[key]}',
    if (jsonEncode(before.periodTimes.map((p) => p.toJson()).toList()) !=
        jsonEncode(after.periodTimes.map((p) => p.toJson()).toList()))
      '上课时间表已更新',
  ];
}
