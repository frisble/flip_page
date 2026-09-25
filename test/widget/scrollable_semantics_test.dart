import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _grid(int page) => GridView.count(
  crossAxisCount: 2,
  physics: const NeverScrollableScrollPhysics(),
  children: [for (var i = 0; i < 4; i++) Text('p$page g$i')],
);

Widget _list(int page) =>
    ListView(children: [for (var i = 0; i < 4; i++) Text('p$page l$i')]);

Widget _scroll(int page) => SingleChildScrollView(
  child: Column(children: [for (var i = 0; i < 4; i++) Text('p$page s$i')]),
);

Widget _harness(
  Widget Function(int) page, {
  FlipPageController? controller,
  double width = 400,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: 600,
        child: FlipPage(
          controller: controller,
          pages: [for (var i = 0; i < 4; i++) page(i)],
        ),
      ),
    ),
  ),
);

Future<void> _drag(WidgetTester tester, {required bool forward}) async {
  final Finder flip = find.byType(FlipPage);
  final Offset center = tester.getCenter(flip);
  final Size size = tester.getSize(flip);
  final double sign = forward ? 1 : -1;
  final gesture = await tester.startGesture(
    Offset(center.dx + sign * size.width * 0.35, center.dy),
  );
  for (var i = 0; i < 7; i++) {
    await gesture.moveBy(Offset(-sign * size.width * 0.1, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  final Map<String, Widget Function(int)> kinds = {
    'GridView(NeverScrollable)': _grid,
    'ListView': _list,
    'SingleChildScrollView': _scroll,
  };

  for (final MapEntry(key: name, value: page) in kinds.entries) {
    group('FlipPage with $name pages and semantics on', () {
      testWidgets('drag forward then backward does not assert', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(page));
        await tester.pumpAndSettle();

        await _drag(tester, forward: true);
        expect(tester.takeException(), isNull);
        expect(find.text('p1 ${name[0].toLowerCase()}0'), findsWidgets);

        await _drag(tester, forward: false);
        expect(tester.takeException(), isNull);
        handle.dispose();
      });

      testWidgets('reverted drag does not assert', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(page));
        await tester.pumpAndSettle();

        final Finder flip = find.byType(FlipPage);
        final Offset center = tester.getCenter(flip);
        final Size size = tester.getSize(flip);
        final gesture = await tester.startGesture(
          Offset(center.dx + size.width * 0.35, center.dy),
        );
        await gesture.moveBy(Offset(-size.width * 0.1, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        handle.dispose();
      });

      testWidgets('controller next/previous does not assert', (tester) async {
        final handle = tester.ensureSemantics();
        final controller = FlipPageController();
        await tester.pumpWidget(_harness(page, controller: controller));
        await tester.pumpAndSettle();

        controller.next();
        await tester.pumpAndSettle();
        controller.next();
        await tester.pumpAndSettle();
        controller.previous();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(controller.currentPage, 1);
        handle.dispose();
        controller.dispose();
      });

      testWidgets('landscape spread flips do not assert', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_harness(page, width: 900));
        await tester.pumpAndSettle();

        await _drag(tester, forward: true);
        expect(tester.takeException(), isNull);
        await _drag(tester, forward: false);
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    });
  }

  testWidgets('a scrolled page keeps its offset across a flip and back', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        (page) => ListView(
          key: PageStorageKey<int>(page),
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 50, child: Text('p$page r$i')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(300);
    await tester.pump();
    expect(find.text('p0 r0'), findsNothing);

    await _drag(tester, forward: true);
    await _drag(tester, forward: false);
    expect(tester.takeException(), isNull);
    expect(find.text('p0 r0'), findsNothing);
    expect(find.text('p0 r6'), findsOneWidget);
    handle.dispose();
  });
}
