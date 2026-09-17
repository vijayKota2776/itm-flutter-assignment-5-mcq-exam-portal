import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('McqExamApp renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const McqExamApp());
    expect(find.byType(McqExamApp), findsOneWidget);
  });
}
