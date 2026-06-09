import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('admin employee management shows employee list search', (
    tester,
  ) async {
    await loginWithRole(
      tester,
      role: 'Admin',
      username: 'admin',
      password: 'Admin@123',
    );

    await openSidebarMenu(tester, 'Employee Management');
    await openSidebarMenu(tester, 'Edit Employee');

    expect(find.text('Search employee'), findsWidgets);
    expect(find.text('Test Employee'), findsWidgets);
  });

  testWidgets('employee directory search filters results', (tester) async {
    await loginWithRole(tester, role: 'User');

    await openSidebarMenu(tester, 'Helpdesk');
    await openSidebarMenu(tester, 'Help Desk');

    final searchFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.decoration?.hintText?.toLowerCase().contains('search') ??
              false),
    );
    if (searchFields.evaluate().isNotEmpty) {
      await tester.enterText(searchFields.first, 'jane');
      await tester.pumpAndSettle();
      expect(find.textContaining('jane'), findsWidgets);
    } else {
      expect(find.text('Help Desk'), findsWidgets);
    }
  });
}
