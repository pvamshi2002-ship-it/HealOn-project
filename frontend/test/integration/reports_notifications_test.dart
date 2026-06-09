import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('user dashboard loads notification-capable workspace', (
    tester,
  ) async {
    await loginWithRole(tester, role: 'User');

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byIcon(Icons.refresh), findsWidgets);
  });

  testWidgets('admin work monitoring report section opens', (tester) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    await openSidebarMenu(tester, 'Work Monitoring');
    expect(find.text('Work Monitoring'), findsWidgets);
  });

  testWidgets('admin pending requests section is reachable', (tester) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    await scrollToAndTap(tester, find.textContaining('Pending approvals'));
    expect(find.textContaining('Total Requests'), findsWidgets);
  });

  testWidgets('attendance report month controls appear for user', (
    tester,
  ) async {
    await loginWithRole(tester, role: 'User');
    await openSidebarMenu(tester, 'Attendance');
    await openSidebarMenu(tester, 'Daily Attendance');

    expect(find.textContaining('Attendance'), findsWidgets);
  });
}
