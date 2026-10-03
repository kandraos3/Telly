import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/app.dart';

void main() {
  testWidgets('TellyApp smoke test renders app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TellyApp(),
      ),
    );

    expect(find.text('Telly — Your Personal TV Canon'), findsOneWidget);
  });
}

