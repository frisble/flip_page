import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  required double width,
  required double height,
  int initialPage = 0,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: FlipPage(
          pages: pages,
          initialPage: initialPage,
          onPageChanged: onPageChanged,
        ),
      ),
    ),
  );
}

List<Widget> _sixPages() => const [
      ColoredBox(key: Key('P0'), color: Colors.red, child: SizedBox.expand()),
      ColoredBox(key: Key('P1'), color: Colors.green, child: SizedBox.expand()),
      ColoredBox(key: Key('P2'), color: Colors.blue, child: SizedBox.expand()),
      ColoredBox(key: Key('P3'), color: Colors.amber, child: SizedBox.expand()),
      ColoredBox(key: Key('P4'), color: Colors.pink, child: SizedBox.expand()),
      ColoredBox(key: Key('P5'), color: Colors.teal, child: SizedBox.expand()),
    ];

void main() {
  group('FlipPage landscape spread', () {
    testWidgets(
        'landscape constraints show two pages side by side',
        (tester) async {
      await tester.pumpWidget(_harness(
        pages: _sixPages(),
        width: 800,
        height: 400,
        initialPage: 2,
      ));
      await tester.pumpAndSettle();

      // Both pages of the spread should be visible.
      expect(find.byKey(const Key('P2')), findsOneWidget);
      expect(find.byKey(const Key('P3')), findsOneWidget);
    });

    testWidgets('portrait constraints show single page', (tester) async {
      await tester.pumpWidget(_harness(
        pages: _sixPages(),
        width: 400,
        height: 800,
        initialPage: 2,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P2')), findsOneWidget);
      expect(find.byKey(const Key('P3')), findsNothing);
    });

    testWidgets(
        'drag on right page in landscape advances spread by 2',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _sixPages(),
        width: 800,
        height: 400,
        initialPage: 0,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      // Right page occupies the right half (x: 400..800).
      // Drag from far right leftward past threshold.
      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.4, 0));
      await tester.pumpAndSettle();

      // Should have advanced by 2 — now showing pages 2 and 3.
      expect(changedTo, equals(2));
      expect(find.byKey(const Key('P2')), findsOneWidget);
      expect(find.byKey(const Key('P3')), findsOneWidget);
    });
  });
}
