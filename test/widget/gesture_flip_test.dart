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

List<Widget> _threePages() => const [
      ColoredBox(key: Key('A'), color: Colors.red, child: SizedBox.expand()),
      ColoredBox(key: Key('B'), color: Colors.green, child: SizedBox.expand()),
      ColoredBox(key: Key('C'), color: Colors.blue, child: SizedBox.expand()),
    ];

void main() {
  group('FlipPage gesture', () {
    testWidgets('drag from right edge past threshold flips forward',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(find.byKey(const Key('B')), findsNothing);

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      // Start on the right half, drag leftward by 70% of width.
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsNothing);
      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });

    testWidgets('drag from left edge past threshold flips backward',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        initialPage: 1,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      // Start on the left half, drag rightward by 70% of width.
      final Offset start = Offset(center.dx - size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsNothing);
      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(changedTo, equals(0));
    });

    testWidgets('drag below threshold reverts to original page',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      // Only drag 20% — below the 50% distance threshold, low velocity.
      await tester.timedDragFrom(
        start,
        Offset(-size.width * 0.2, 0),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(find.byKey(const Key('B')), findsNothing);
      expect(changedTo, isNull);
    });

    testWidgets('fast fling below distance threshold still completes',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      // Short distance but fast — simulated via fling.
      await tester.flingFrom(start, Offset(-size.width * 0.25, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });

    testWidgets('forward drag at last page does not change page',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        initialPage: 2,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('C')), findsOneWidget);
      expect(changedTo, isNull);
    });
  });
}
