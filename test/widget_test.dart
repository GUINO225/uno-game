import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gino/game_rules_manual.dart';

void main() {
  testWidgets('Le bouton des règles ouvre le manuel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: GameRulesButton())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Règles du jeu'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Règles du jeu'), findsOneWidget);
    expect(find.text('But du jeu'), findsOneWidget);
  });
}
