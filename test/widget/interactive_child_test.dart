import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  double? edgeHitZoneFraction,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: FlipPage(
          pages: pages,
          edgeHitZoneFraction: edgeHitZoneFraction,
          onPageChanged: onPageChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('FlipPage interactive children', () {
    testWidgets('button tap fires onPressed; no page change', (tester) async {
      bool tapped = false;
      int? changedTo;
      await tester.pumpWidget(
        _harness(
          pages: [
            Center(
              child: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('Tap'),
              ),
            ),
            const ColoredBox(color: Colors.blue, child: SizedBox.expand()),
          ],
          onPageChanged: (i) => changedTo = i,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(changedTo, isNull);
    });

    testWidgets(
      'vertical drag on child ListView scrolls list; no page change',
      (tester) async {
        int? changedTo;
        await tester.pumpWidget(
          _harness(
            pages: [
              ListView(
                children: List.generate(
                  50,
                  (i) => ListTile(title: Text('Row $i')),
                ),
              ),
              const ColoredBox(color: Colors.blue, child: SizedBox.expand()),
            ],
            onPageChanged: (i) => changedTo = i,
          ),
        );
        await tester.pumpAndSettle();

        // Drag vertically on the list.
        final Finder list = find.byType(ListView);
        await tester.drag(list, const Offset(0, -200));
        await tester.pumpAndSettle();

        // Row 0 should have scrolled off; later rows visible.
        expect(find.text('Row 10'), findsOneWidget);
        expect(changedTo, isNull);
      },
    );

    testWidgets(
      'horizontal drag from edge over button flips; button does not fire',
      (tester) async {
        bool tapped = false;
        int? changedTo;
        await tester.pumpWidget(
          _harness(
            pages: [
              // Button in the right-edge zone (within 40% of right side).
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Edge'),
                  ),
                ),
              ),
              const ColoredBox(
                key: Key('B'),
                color: Colors.blue,
                child: SizedBox.expand(),
              ),
            ],
            onPageChanged: (i) => changedTo = i,
          ),
        );
        await tester.pumpAndSettle();

        // Horizontal drag from the right edge area leftward past threshold.
        final Finder flip = find.byType(FlipPage);
        final Size size = tester.getSize(flip);
        final Offset center = tester.getCenter(flip);
        final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
        await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
        await tester.pumpAndSettle();

        expect(tapped, isFalse);
        expect(changedTo, equals(1));
      },
    );

    testWidgets('drag starting in central non-hit-zone does NOT flip', (
      tester,
    ) async {
      int? changedTo;
      await tester.pumpWidget(
        _harness(
          pages: const [
            ColoredBox(
              key: Key('A'),
              color: Colors.red,
              child: SizedBox.expand(),
            ),
            ColoredBox(
              key: Key('B'),
              color: Colors.blue,
              child: SizedBox.expand(),
            ),
          ],
          edgeHitZoneFraction: 0.4,
          onPageChanged: (i) => changedTo = i,
        ),
      );
      await tester.pumpAndSettle();

      // Drag starting at dead center (50% width = outside both edge zones).
      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      await tester.dragFrom(center, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsOneWidget);
      expect(changedTo, isNull);
    });
  });
}
