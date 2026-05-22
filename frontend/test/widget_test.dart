import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/main.dart';

void main() {
  testWidgets('shows the HealOn login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('HealOn'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
