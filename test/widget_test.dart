import 'package:flutter_test/flutter_test.dart';

import 'package:mysynk_client/main.dart';

void main() {
  testWidgets('MySynk inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MySynkApp());

    expect(find.text('MySynk'), findsOneWidget);
    expect(find.text('Mi espacio'), findsWidgets);
  });
}