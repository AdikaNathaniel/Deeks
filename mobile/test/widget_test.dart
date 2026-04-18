import 'package:flutter_test/flutter_test.dart';
import 'package:deeks/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const DeeksApp());
  });
}
