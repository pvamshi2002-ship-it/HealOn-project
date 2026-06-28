import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  tearDown(tearDownHealOnTests);

  testWidgets('shows HealOn login screen elements', (tester) async {
    setUpHealOnTests();
    await pumpHealOnApp(tester);

    expect(find.text('HealOn'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(usernameField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('shows validation when login fields are empty', (tester) async {
    setUpHealOnTests();
    await pumpHealOnApp(tester);

    await tapLogin(tester);

    expect(find.textContaining('Please fill in all fields'), findsOneWidget);
  });

  testWidgets('shows error for invalid credentials', (tester) async {
    setUpHealOnTests(authStatusCode: 400);
    await pumpHealOnApp(tester);
    await enterLoginCredentials(tester);
    await tapLogin(tester);

    expect(find.textContaining('Invalid'), findsWidgets);
    await drainNotificationTimers(tester);
  });
}
