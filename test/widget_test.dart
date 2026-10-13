import 'package:flutter_test/flutter_test.dart';
import 'package:bill_reminder/main.dart';

void main() {
  testWidgets('BillApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BillApp());
    expect(find.text('Bill Reminder & Payment'), findsOneWidget);
  });
}
