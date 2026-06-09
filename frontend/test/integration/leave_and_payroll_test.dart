import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('apply leave form is visible for user role', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Leaves');
    await openSidebarMenu(tester, 'Apply Leave');

    expect(find.text('Apply Leave'), findsWidgets);
    expect(find.textContaining('Leave'), findsWidgets);
  });

  testWidgets('leave overview shows leave history section', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Leaves');
    await openSidebarMenu(tester, 'Leave Overview');

    expect(find.text('Leave Overview'), findsWidgets);
    expect(find.text('Leave History'), findsWidgets);
  });

  testWidgets('user payslip section loads salary view controls', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Salary');
    await openSidebarMenu(tester, 'Payslips');

    expect(find.text('Payslips'), findsWidgets);
    expect(find.text('Compensation & Benefits'), findsWidgets);
  });

  testWidgets('hr payroll reimbursement section is available', (tester) async {
    await loginWithRole(
      tester,
      role: 'HR',
      username: 'hr',
      password: 'HR@123',
    );

    await openSidebarMenu(tester, 'Employee Payroll');
    await openSidebarMenu(tester, 'Reimbursement');

    expect(find.text('Reimbursement'), findsWidgets);
  });
}
