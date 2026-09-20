class WeekPatternParser {
  const WeekPatternParser._();

  static List<int> parse(String raw) {
    final normalized = raw
        .replaceAll('周', '')
        .replaceAll('第', '')
        .replaceAll('，', ',')
        .replaceAll('－', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+'), '');

    if (normalized.isEmpty) return const [];

    final weeks = <int>{};
    for (final part in normalized.split(',')) {
      if (part.isEmpty) continue;
      final range = part.split('-');

      if (range.length == 1) {
        final week = int.tryParse(range.first);
        if (_isValidWeek(week)) weeks.add(week!);
        continue;
      }

      if (range.length == 2) {
        final start = int.tryParse(range.first);
        final end = int.tryParse(range.last);
        if (!_isValidWeek(start) || !_isValidWeek(end) || start! > end!) {
          continue;
        }
        weeks.addAll(
          List<int>.generate(end - start + 1, (index) => start + index),
        );
      }
    }

    final result = weeks.toList()..sort();
    return List.unmodifiable(result);
  }

  static bool _isValidWeek(int? week) =>
      week != null && week >= 1 && week <= 30;
}
