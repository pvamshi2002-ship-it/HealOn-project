import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('user login loads dashboard workspace', (tester) async {
    await loginWithRole(tester, role: 'User');

    expect(find.text('Login'), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Test Employee'), findsWidgets);
  });

  testWidgets('admin login loads admin dashboard navigation', (tester) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    expect(find.text('Employee Management'), findsWidgets);
    expect(find.text('Work Monitoring'), findsWidgets);
  });

  testWidgets('hr login loads hr navigation and employee tools', (tester) async {
    await loginWithRole(
      tester,
      role: 'HR',
      username: 'hr',
      password: 'HR@123',
    );

    expect(find.text('Employee Management'), findsWidgets);
    expect(find.text('Employee Payroll'), findsWidgets);
  });

  testWidgets('dashboard refresh control is available after login', (tester) async {
    await loginWithRole(tester, role: 'User');

    expect(find.byIcon(Icons.refresh), findsWidgets);
  });
}
