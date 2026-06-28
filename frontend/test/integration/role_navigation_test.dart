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
    expect(find.text('Helpdesk'), findsWidgets);
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
    expect(find.text('Helpdesk'), findsWidgets);
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

  testWidgets('user can navigate career documents section', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Career');
    await openSidebarMenu(tester, 'Documents');

    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Offer Letter'), findsWidgets);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('All document types'), findsOneWidget);
  });
}
