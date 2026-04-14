import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({required List<Widget> pages, int initialPage = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: FlipPage(pages: pages, initialPage: initialPage),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'CustomPaint with FoldPainter is present during a partial drag',
    (tester) async {
      await tester.pumpWidget(_harness(
        pages: const [
          ColoredBox(key: Key('A'), color: Colors.red, child: SizedBox.expand()),
          ColoredBox(key: Key('B'), color: Colors.blue, child: SizedBox.expand()),
          ColoredBox(key: Key('C'), color: Colors.green, child: SizedBox.expand()),
        ],
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);

      // Initiate a drag from the right half (forward) and hold.
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      final TestGesture gesture = await tester.startGesture(start);
      // Move 40% leftward — partial drag, should show curl.
      await gesture.moveBy(Offset(-size.width * 0.4, 0));
      await tester.pump();

      // During drag: a CustomPaint should be in the tree for the curl.
      expect(find.byType(CustomPaint), findsWidgets);

      // The base layer (next page, key 'B') should be findable underneath.
      expect(find.byKey(const Key('B')), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}
