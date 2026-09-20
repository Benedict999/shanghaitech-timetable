import 'week_pattern.dart';
import 'semester_calendar.dart';

class CourseMeeting {
  const CourseMeeting({
    required this.courseCode,
    required this.courseName,
    required this.classCode,
    required this.weekText,
    required this.weeks,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.teacher,
    required this.location,
    required this.periodSchemeId,
  });

  final String courseCode;
  final String courseName;
  final String classCode;
  final String weekText;
  final List<int> weeks;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final String teacher;
  final String location;
  final String periodSchemeId;

  factory CourseMeeting.fromSchoolJson(Map<String, dynamic> json) {
    final weekText = _text(json['ZCMC']);
    return CourseMeeting(
      courseCode: _text(json['KCDM']),
      courseName: _text(json['KCMC'], fallback: '未命名课程'),
      classCode: _text(json['BJDM']),
      weekText: weekText,
      weeks: WeekPatternParser.parse(weekText),
      weekday: _number(json['XQ']),
      startPeriod: _number(json['KSJCDM']),
      endPeriod: _number(json['JSJCDM']),
      teacher: _text(json['JGJSXM']),
      location: _text(json['JASMC']),
      periodSchemeId: _text(json['JCFADM']),
    );
  }

  factory CourseMeeting.fromJson(Map<String, dynamic> json) {
    return CourseMeeting(
      courseCode: _text(json['courseCode']),
      courseName: _text(json['courseName'], fallback: '未命名课程'),
      classCode: _text(json['classCode']),
      weekText: _text(json['weekText']),
      weeks: (json['weeks'] as List<dynamic>? ?? const [])
          .map(_number)
          .where((week) => week >= 1 && week <= 30)
          .toList(growable: false),
      weekday: _number(json['weekday']),
      startPeriod: _number(json['startPeriod']),
      endPeriod: _number(json['endPeriod']),
      teacher: _text(json['teacher']),
      location: _text(json['location']),
      periodSchemeId: _text(json['periodSchemeId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'classCode': classCode,
    'weekText': weekText,
    'weeks': weeks,
    'weekday': weekday,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
    'teacher': teacher,
    'location': location,
    'periodSchemeId': periodSchemeId,
  };

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _number(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SyncResult {
  const SyncResult({
    required this.termCode,
    required this.termLabel,
    required this.meetings,
    required this.syncedAt,
    this.calendar = const SemesterCalendar(),
    this.periodTimes = const [],
  });

  final String termCode;
  final String termLabel;
  final List<CourseMeeting> meetings;
  final DateTime syncedAt;
  final SemesterCalendar calendar;
  final List<PeriodTime> periodTimes;

  SyncResult withCalendar(SemesterCalendar value) => SyncResult(
    termCode: termCode,
    termLabel: termLabel,
    meetings: meetings,
    syncedAt: syncedAt,
    calendar: value,
    periodTimes: periodTimes,
  );

  SyncResult retainSettings(SyncResult? previous) => SyncResult(
    termCode: termCode,
    termLabel: termLabel,
    meetings: meetings,
    syncedAt: syncedAt,
    calendar: previous?.termCode == termCode && previous!.calendar.confirmed
        ? previous.calendar
        : calendar,
    periodTimes: periodTimes.isNotEmpty
        ? periodTimes
        : previous?.termCode == termCode
        ? previous!.periodTimes
        : periodTimes,
  );

  PeriodTime? timeFor(int period, {String? scheme}) {
    final candidates = periodTimes.where((p) => p.period == period).toList();
    if (scheme != null) {
      final exact = candidates.where((p) => p.scheme == scheme).toList();
      if (exact.isNotEmpty) return exact.first;
    }
    if (candidates.isEmpty) return null;
    if (candidates.every(
      (p) => p.start == candidates.first.start && p.end == candidates.first.end,
    )) {
      return candidates.first;
    }
    return null;
  }

  factory SyncResult.fromBridgeMessage(Map<String, dynamic> message) {
    final data = message['data'];
    if (data is! Map) {
      throw const FormatException('学校返回的数据格式不完整');
    }
    final rawMeetings = data['jgList'];
    if (rawMeetings is! List) {
      throw const FormatException('学校返回的数据中没有排课结果');
    }

    final meetings = rawMeetings
        .whereType<Map>()
        .map(
          (item) =>
              CourseMeeting.fromSchoolJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.weekday >= 1 && item.weekday <= 7)
        .where(
          (item) => item.startPeriod > 0 && item.endPeriod >= item.startPeriod,
        )
        .toList(growable: false);

    if (meetings.length != rawMeetings.length ||
        meetings.any(
          (m) => m.endPeriod > 30 || m.weeks.isEmpty || m.courseName == '未命名课程',
        )) {
      throw const FormatException('部分排课数据不完整，已停止同步以保护原课表');
    }

    return SyncResult(
      termCode: message['termCode']?.toString() ?? '',
      termLabel: message['termLabel']?.toString() ?? '当前学期',
      meetings: meetings,
      syncedAt: DateTime.now(),
      calendar: message['suggestedMonday'] is String
          ? SemesterCalendar(
              firstMonday: DateTime.tryParse(
                message['suggestedMonday'] as String,
              ),
              source: '课程日期交叉校验，待确认',
            )
          : const SemesterCalendar(),
      periodTimes: (message['periodTimes'] as List? ?? [])
          .whereType<Map>()
          .map((p) => PeriodTime.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    final rawMeetings = json['meetings'];
    if (rawMeetings is! List) {
      throw const FormatException('本地课表数据不完整');
    }
    return SyncResult(
      termCode: json['termCode']?.toString() ?? '',
      termLabel: json['termLabel']?.toString() ?? '当前学期',
      meetings: rawMeetings
          .whereType<Map>()
          .map(
            (item) => CourseMeeting.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      syncedAt:
          DateTime.tryParse(json['syncedAt']?.toString() ?? '') ??
          DateTime.now(),
      calendar: json['calendar'] is Map
          ? SemesterCalendar.fromJson(
              Map<String, dynamic>.from(json['calendar'] as Map),
            )
          : const SemesterCalendar(),
      periodTimes: (json['periodTimes'] as List? ?? [])
          .whereType<Map>()
          .map((p) => PeriodTime.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'calendar': calendar.toJson(),
    'periodTimes': periodTimes.map((p) => p.toJson()).toList(),
    'termCode': termCode,
    'termLabel': termLabel,
    'meetings': meetings.map((meeting) => meeting.toJson()).toList(),
    'syncedAt': syncedAt.toIso8601String(),
  };

  int get maxWeek {
    var maximum = 1;
    for (final meeting in meetings) {
      for (final week in meeting.weeks) {
        if (week > maximum) maximum = week;
      }
    }
    return maximum.clamp(1, 30);
  }
}
