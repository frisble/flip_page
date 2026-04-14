import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  ValueChanged<int>? onPageChanged,
  int initialPage = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: FlipPage(
          pages: pages,
          onPageChanged: onPageChanged,
          initialPage: initialPage,
        ),
      ),
    ),
  );
}

void main() {
  group('FlipPage boundary behavior', () {
    testWidgets('forward drag at last page stays on last page', (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: const [
          ColoredBox(key: Key('A'), color: Colors.red, child: SizedBox.expand()),
          ColoredBox(key: Key('B'), color: Colors.blue, child: SizedBox.expand()),
        ],
        initialPage: 1,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, isNull);
    });

    testWidgets('backward drag at page 0 stays on page 0', (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: const [
          ColoredBox(key: Key('A'), color: Colors.red, child: SizedBox.expand()),
          ColoredBox(key: Key('B'), color: Colors.blue, child: SizedBox.expand()),
        ],
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx - size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(changedTo, isNull);
    });

    testWidgets('empty pages list renders without throwing', (tester) async {
      await tester.pumpWidget(_harness(pages: const []));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('single page list: drag is a no-op', (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: const [
          ColoredBox(key: Key('only'), color: Colors.red, child: SizedBox.expand()),
        ],
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('only')), findsOneWidget);
      expect(changedTo, isNull);
    });
  });
}
