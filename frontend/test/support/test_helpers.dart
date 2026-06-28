import 'package:attendance_app/healon_http.dart';
import 'package:attendance_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_api_client.dart';

const _sidebarParentBySubmenu = <String, String>{
  'Daily Attendance': 'Attendance',
  'Regularization Attendance': 'Attendance',
  'Attendance Reports': 'Attendance',
  'Apply Leave': 'Leaves',
  'Leave Calendar': 'Leaves',
  'Leave Overview': 'Leaves',
  'Documents': 'Career',
  'Pending Tasks': 'Tasks',
  'Payslips': 'Salary',
  'Compensation & Benefits': 'Salary',
  'Bonus & Incentives': 'Salary',
  'Tax Details': 'Salary',
  'Add Employee': 'Employee Management',
  'Edit Employee': 'Employee Management',
  'Delete Employee': 'Employee Management',
  'Add Location': 'Smart Location Management',
  'Edit Location': 'Smart Location Management',
  'Help Desk': 'Helpdesk',
  'Reimbursement': 'Employee Payroll',
  'Salary Structure': 'Employee Payroll',
};

bool _isBenignLayoutOverflow(Object exception) {
  final message = exception.toString();
  return message.contains('RenderFlex overflowed') ||
      message.contains('overflowed by') ||
      message.contains('A RenderFlex overflowed') ||
      message.contains('Multiple exceptions');
}

void drainBenignLayoutExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    if (!_isBenignLayoutOverflow(exception!)) {
      fail('Unexpected test exception: $exception');
    }
  }
}

Future<void> settleIgnoringBenignOverflow(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    drainBenignLayoutExceptions(tester);
  }
}

void setUpHealOnTests({String authRole = 'User', int authStatusCode = 200}) {
  resetHealonHttpClientForTests();
  setHealonHttpClientForTests(
    createHealOnMockClient(
      authRole: authRole,
      authStatusCode: authStatusCode,
    ),
  );
}

void tearDownHealOnTests() {
  resetHealonHttpClientForTests();
}

void configureHealOnTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpHealOnApp(WidgetTester tester) async {
  configureHealOnTestViewport(tester);
  await tester.pumpWidget(const MyApp());
  await settleIgnoringBenignOverflow(tester);
}

Finder get usernameField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText?.toLowerCase() == 'username',
    );

Finder get passwordField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Password',
    );

Finder get loginRoleDropdown =>
    find.byType(DropdownButtonFormField<String>).first;

Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      target,
      72,
      scrollable: scrollables.first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await settleIgnoringBenignOverflow(tester);

  final inkWell = find.ancestor(
    of: target,
    matching: find.byType(InkWell),
  );
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.last);
  } else {
    await tester.tap(target);
  }
  await settleIgnoringBenignOverflow(tester);
}

Future<void> drainNotificationTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
}

Future<void> enterLoginCredentials(
  WidgetTester tester, {
  String username = 'employee',
  String password = 'Employee@123',
}) async {
  await tester.enterText(usernameField, username);
  await tester.enterText(passwordField, password);
}

Future<void> tapLogin(WidgetTester tester) async {
  await scrollToAndTap(tester, find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await settleIgnoringBenignOverflow(tester);
}

Future<void> loginAsUser(WidgetTester tester) async {
  await enterLoginCredentials(tester);
  await tapLogin(tester);
}

Future<void> selectRole(WidgetTester tester, String role) async {
  if (role == 'User') {
    return;
  }

  await scrollToAndTap(tester, loginRoleDropdown);
  final roleItem = find.text(role);
  expect(roleItem, findsWidgets);
  await scrollToAndTap(tester, roleItem.last);
}

Future<void> expectLoggedIn(WidgetTester tester) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    drainBenignLayoutExceptions(tester);
    if (find.text('Login').evaluate().isEmpty &&
        find.text('Dashboard').evaluate().isNotEmpty) {
      return;
    }
  }
  expect(find.text('Login'), findsNothing);
  expect(find.text('Dashboard'), findsWidgets);
}

Future<void> loginWithRole(
  WidgetTester tester, {
  required String role,
  String username = 'employee',
  String password = 'Employee@123',
}) async {
  setUpHealOnTests(authRole: role);
  await pumpHealOnApp(tester);
  await selectRole(tester, role);
  await enterLoginCredentials(
    tester,
    username: role == 'Admin'
        ? 'admin'
        : role == 'HR'
            ? 'hr'
            : username,
    password: role == 'Admin'
        ? 'Admin@123'
        : role == 'HR'
            ? 'HR@123'
            : password,
  );
  await tapLogin(tester);
  await expectLoggedIn(tester);
}

Future<void> openSidebarMenu(
  WidgetTester tester,
  String label, {
  String? parent,
}) async {
  final resolvedParent = parent ?? _sidebarParentBySubmenu[label];
  if (resolvedParent != null && resolvedParent != label) {
    if (find.text(label).evaluate().isEmpty) {
      await scrollToAndTap(tester, find.text(resolvedParent).first);
    }
    if (find.text(label).evaluate().isNotEmpty) {
      await scrollToAndTap(tester, find.text(label).first);
    }
    return;
  }

  if (find.text(label).evaluate().isNotEmpty) {
    await scrollToAndTap(tester, find.text(label).first);
  }
}
