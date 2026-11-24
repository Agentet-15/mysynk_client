import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mysynk_client/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MySynk inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MySynkApp());
    await tester.pumpAndSettle();

    expect(find.text('Mi espacio'), findsWidgets);
    expect(find.text('MySynk'), findsOneWidget);
  });
}
