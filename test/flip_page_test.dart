import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders initial page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipPage(
            pages: [
              Text('hello'),
              Text('world'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('world'), findsNothing);
  });

  testWidgets('empty pages list renders without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipPage(pages: []),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
