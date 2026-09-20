import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/domain/week_pattern.dart';

void main() {
  group('WeekPatternParser', () {
    test('parses a continuous range', () {
      expect(WeekPatternParser.parse('1-4周'), [1, 2, 3, 4]);
    });

    test('parses mixed ranges and individual weeks', () {
      expect(WeekPatternParser.parse('1-3,5-6,9周'), [1, 2, 3, 5, 6, 9]);
    });

    test('normalizes Chinese punctuation and removes duplicates', () {
      expect(WeekPatternParser.parse('第1，3，3，5－6周'), [1, 3, 5, 6]);
    });

    test('ignores malformed and out-of-range fragments', () {
      expect(WeekPatternParser.parse('0,2,8-5,31,abc周'), [2]);
    });
  });
}
