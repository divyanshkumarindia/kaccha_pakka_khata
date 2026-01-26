import 'package:flutter_test/flutter_test.dart';
import 'package:kaccha_pakka_khata/main.dart' as app;

void main() {
  testWidgets('basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const app.MyApp());
    // The index screen shows the app title (updated UI)
    expect(find.text('KACCHA PAKKA KHATA '), findsOneWidget);
  });
}
