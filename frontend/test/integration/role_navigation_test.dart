import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('user can navigate attendance and leave menus', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Attendance');
    expect(find.text('Daily Attendance'), findsWidgets);

    await openSidebarMenu(tester, 'Leaves');
    expect(find.text('Apply Leave'), findsWidgets);
    expect(find.text('Leave Overview'), findsWidgets);
  });

  testWidgets('user can navigate salary and helpdesk menus', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Salary');
    expect(find.text('Payslips'), findsWidgets);

    await openSidebarMenu(tester, 'Helpdesk');
    await openSidebarMenu(tester, 'Help Desk');

    expect(find.text('Help Desk'), findsWidgets);
  });

  testWidgets('admin can navigate employee management and helpdesk', (
    tester,
  ) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    await openSidebarMenu(tester, 'Employee Management');
    expect(find.text('Add Employee'), findsWidgets);

    await openSidebarMenu(tester, 'Helpdesk');
    await openSidebarMenu(tester, 'Help Desk');
    expect(find.text('Help Desk'), findsWidgets);
  });

  testWidgets('hr can navigate payroll section', (tester) async {
    await loginWithRole(
      tester,
      role: 'HR',
      username: 'hr',
      password: 'HR@123',
    );

    await openSidebarMenu(tester, 'Employee Payroll');
    expect(find.text('Employee Payroll'), findsWidgets);
  });
}
