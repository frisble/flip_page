import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  FlipPageController? controller,
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
          controller: controller,
          onPageChanged: onPageChanged,
          initialPage: initialPage,
        ),
      ),
    ),
  );
}

List<Widget> _fivePages() => const [
      ColoredBox(key: Key('P0'), color: Colors.red, child: SizedBox.expand()),
      ColoredBox(key: Key('P1'), color: Colors.green, child: SizedBox.expand()),
      ColoredBox(key: Key('P2'), color: Colors.blue, child: SizedBox.expand()),
      ColoredBox(key: Key('P3'), color: Colors.amber, child: SizedBox.expand()),
      ColoredBox(key: Key('P4'), color: Colors.pink, child: SizedBox.expand()),
    ];

void main() {
  group('FlipPageController with widget', () {
    testWidgets('controller.jumpTo changes page without animation',
        (tester) async {
      final controller = FlipPageController();
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _fivePages(),
        controller: controller,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P0')), findsOneWidget);

      controller.jumpTo(3);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P3')), findsOneWidget);
      expect(changedTo, equals(3));

      controller.dispose();
    });

    testWidgets('controller.jumpTo out of range is a no-op', (tester) async {
      final controller = FlipPageController();
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _fivePages(),
        controller: controller,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      controller.jumpTo(99);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P0')), findsOneWidget);
      expect(changedTo, isNull);

      controller.dispose();
    });

    testWidgets('controller.next animates forward', (tester) async {
      final controller = FlipPageController();
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _fivePages(),
        controller: controller,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      controller.next();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P1')), findsOneWidget);
      expect(changedTo, equals(1));

      controller.dispose();
    });

    testWidgets('controller.previous at page 0 is a no-op', (tester) async {
      final controller = FlipPageController();
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _fivePages(),
        controller: controller,
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      controller.previous();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('P0')), findsOneWidget);
      expect(changedTo, isNull);

      controller.dispose();
    });

    testWidgets('gesture-driven flip also fires onPageChanged once',
        (tester) async {
      final controller = FlipPageController();
      final changes = <int>[];
      await tester.pumpWidget(_harness(
        pages: _fivePages(),
        controller: controller,
        onPageChanged: (i) => changes.add(i),
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start =
          Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(changes, equals([1]));
      expect(controller.currentPage, equals(1));

      controller.dispose();
    });
  });
}
