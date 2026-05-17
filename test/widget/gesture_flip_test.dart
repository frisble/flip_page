import 'package:flip_page/flip_page.dart';
import 'package:flutter/gestures.dart';
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
    testWidgets('drag from right edge past threshold flips forward', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
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

    testWidgets('drag from left edge past threshold flips backward', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(
          pages: _threePages(),
          initialPage: 1,
          onPageChanged: (i) => changedTo = i,
        ),
      );
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

    testWidgets('drag below threshold reverts to original page', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
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

    testWidgets('fast fling below distance threshold still completes', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
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

    testWidgets('edge drag claims arena after horizontal movement', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      final TestGesture gesture = await tester.startGesture(start);

      await gesture.moveBy(const Offset(-24, 1));
      await tester.pump();
      await gesture.moveBy(Offset(-size.width * 0.55, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });

    testWidgets(
      'second pointer outside edge does not cancel active edge drag',
      (tester) async {
        int? changedTo;
        await tester.pumpWidget(
          _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
        );
        await tester.pumpAndSettle();

        final Finder flip = find.byType(FlipPage);
        final Offset center = tester.getCenter(flip);
        final Size size = tester.getSize(flip);
        final Offset edgeStart = Offset(
          center.dx + size.width * 0.35,
          center.dy,
        );
        final Offset centerStart = center;

        final TestGesture edgeGesture = await tester.startGesture(edgeStart);
        final TestGesture centerGesture = await tester.startGesture(
          centerStart,
        );
        await centerGesture.up();

        await edgeGesture.moveBy(Offset(-size.width * 0.7, 0));
        await edgeGesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('B')), findsOneWidget);
        expect(changedTo, equals(1));
      },
    );

    testWidgets('secondary mouse drag from edge does not flip', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );

      await gesture.moveBy(Offset(-size.width * 0.7, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(changedTo, isNull);
    });

    testWidgets('secondary mouse pointer does not cancel active edge drag', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset edgeStart = Offset(center.dx + size.width * 0.35, center.dy);

      final TestGesture edgeGesture = await tester.startGesture(edgeStart);
      final TestGesture mouseGesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouseGesture.up();

      await edgeGesture.moveBy(Offset(-size.width * 0.7, 0));
      await edgeGesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });

    testWidgets('mouse button change cancels active edge drag', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);

      tester.binding.handlePointerEventForSource(
        PointerDownEvent(
          pointer: 1,
          position: start,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        ),
      );
      tester.binding.handlePointerEventForSource(
        PointerMoveEvent(
          pointer: 1,
          position: start + const Offset(-24, 0),
          delta: const Offset(-24, 0),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        ),
      );
      await tester.pump();
      tester.binding.handlePointerEventForSource(
        PointerMoveEvent(
          pointer: 1,
          position: start + Offset(-size.width * 0.7, 0),
          delta: Offset(-size.width * 0.7 + 24, 0),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton | kSecondaryMouseButton,
        ),
      );
      tester.binding.handlePointerEventForSource(
        PointerUpEvent(
          pointer: 1,
          position: start + Offset(-size.width * 0.7, 0),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(changedTo, isNull);
    });

    testWidgets('trackpad pan from edge flips forward', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(pages: _threePages(), onPageChanged: (i) => changedTo = i),
      );
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.trackpad,
      );

      await gesture.panZoomUpdate(start, pan: Offset(-size.width * 0.7, 0));
      await gesture.panZoomEnd();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });

    testWidgets('forward drag at last page does not change page', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(
          pages: _threePages(),
          initialPage: 2,
          onPageChanged: (i) => changedTo = i,
        ),
      );
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
