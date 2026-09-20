import 'package:flutter_test/flutter_test.dart';
import 'package:shanghaitech_timetable/domain/course_meeting.dart';

void main() {
  test('maps a school meeting response without depending on display HTML', () {
    final meeting = CourseMeeting.fromSchoolJson({
      'KCDM': 'TEST1001',
      'KCMC': '示例课程',
      'BJDM': 'CLASS-01',
      'ZCMC': '1-3,5周',
      'XQ': '4',
      'KSJCDM': 2,
      'JSJCDM': 4,
      'JGJSXM': '示例教师',
      'JASMC': '教学楼 101',
      'JCFADM': '01',
    });

    expect(meeting.courseCode, 'TEST1001');
    expect(meeting.courseName, '示例课程');
    expect(meeting.weeks, [1, 2, 3, 5]);
    expect(meeting.weekday, 4);
    expect(meeting.startPeriod, 2);
    expect(meeting.endPeriod, 4);
    expect(meeting.location, '教学楼 101');
  });
}
