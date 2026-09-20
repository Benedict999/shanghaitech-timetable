/// Dates are school civil dates, stored at UTC midnight to avoid DST arithmetic.
class SemesterCalendar {
  const SemesterCalendar({
    this.firstMonday,
    this.totalWeeks = 20,
    this.source = '待确认',
    this.verifiedAt,
  });

  final DateTime? firstMonday;
  final int totalWeeks;
  final String source;
  final DateTime? verifiedAt;
  bool get confirmed => firstMonday != null && verifiedAt != null;

  static DateTime civil(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  static DateTime get schoolToday {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return civil(now);
  }

  DateTime? dateFor(int week, int weekday) => firstMonday == null
      ? null
      : civil(firstMonday!).add(Duration(days: (week - 1) * 7 + weekday - 1));

  int? weekAt(DateTime date) {
    if (!confirmed) return null;
    final days = civil(date).difference(civil(firstMonday!)).inDays;
    return (days / 7).floor() + 1;
  }

  factory SemesterCalendar.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['firstMonday']?.toString() ?? '');
    final weeks = int.tryParse('${json['totalWeeks']}') ?? 20;
    if (weeks < 1 || weeks > 30 || (start != null && start.weekday != 1)) {
      throw const FormatException('学期日期或总周数无效');
    }
    return SemesterCalendar(
      firstMonday: start == null ? null : civil(start),
      totalWeeks: weeks,
      source: json['source']?.toString() ?? '待确认',
      verifiedAt: DateTime.tryParse(json['verifiedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'firstMonday': firstMonday?.toIso8601String(),
    'totalWeeks': totalWeeks,
    'source': source,
    'verifiedAt': verifiedAt?.toIso8601String(),
  };
}

class PeriodTime {
  const PeriodTime({
    required this.period,
    required this.start,
    required this.end,
    this.scheme = '',
    this.source = '学校课表',
  });
  final int period;
  final String start;
  final String end;
  final String scheme;
  final String source;

  static bool validTime(String value) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
  factory PeriodTime.fromJson(Map<String, dynamic> json) {
    final p = int.tryParse('${json['period']}') ?? 0;
    final start = json['start']?.toString() ?? '';
    final end = json['end']?.toString() ?? '';
    if (p < 1 ||
        p > 30 ||
        !validTime(start) ||
        !validTime(end) ||
        start.compareTo(end) >= 0) {
      throw const FormatException('节次时间无效');
    }
    return PeriodTime(
      period: p,
      start: start,
      end: end,
      scheme: json['scheme']?.toString() ?? '',
      source: json['source']?.toString() ?? '学校课表',
    );
  }
  Map<String, dynamic> toJson() => {
    'period': period,
    'start': start,
    'end': end,
    'scheme': scheme,
    'source': source,
  };
}
