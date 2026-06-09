import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('user attendance section shows daily attendance view', (
    tester,
  ) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Attendance');
    await openSidebarMenu(tester, 'Daily Attendance');

    expect(find.text('Daily Attendance'), findsWidgets);
    expect(find.textContaining('Check In'), findsWidgets);
  });

  testWidgets('user can open regularization attendance section', (
    tester,
  ) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Attendance');
    await openSidebarMenu(tester, 'Regularization Attendance');

    expect(find.text('Regularization Attendance'), findsWidgets);
  });

  testWidgets('admin attendance management section is reachable', (
    tester,
  ) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    await openSidebarMenu(tester, 'Attendance');
    await openSidebarMenu(tester, 'Daily Attendance');

    expect(find.text('Daily Attendance'), findsWidgets);
  });
}
