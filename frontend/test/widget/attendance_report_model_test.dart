import 'package:attendance_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceReport model', () {
    test('parses API payload correctly', () {
      final report = AttendanceReport.fromJson({
        'month': '2026-06',
        'summary': {
          'present_days': 10,
          'total_hours': 80.5,
          'late_days': 2,
        },
        'days': [
          {
            'date': '2026-06-01',
            'status': 'Present',
            'check_in': '09:00',
            'check_out': '18:00',
            'total_hours': 8,
          },
        ],
      });

      expect(report.month, '2026-06');
      expect(report.presentDays, 10);
      expect(report.totalHours, 80.5);
      expect(report.lateDays, 2);
      expect(report.days, hasLength(1));
      expect(report.days.first.status, 'Present');
      expect(report.days.first.totalHours, 8);
    });
  });
}
