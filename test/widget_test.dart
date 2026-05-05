import 'package:flutter_test/flutter_test.dart';

import 'package:gino/main.dart';

void main() {
  testWidgets('L\'écran principal du jeu est visible', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Huit américain'), findsOneWidget);
    expect(find.text('Piocher'), findsOneWidget);
    expect(find.text('Votre main'), findsOneWidget);
  });
}
