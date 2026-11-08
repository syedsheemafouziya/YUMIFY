import 'package:flutter_test/flutter_test.dart';
import 'package:yumify/main.dart';

void main() {
  testWidgets('Yumify app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const YumifyApp());

    expect(find.byType(YumifyApp), findsOneWidget);
  });
}