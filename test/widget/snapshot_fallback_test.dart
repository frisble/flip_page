import 'package:flip_page/src/flip_page_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: FlipPage(pages: pages, onPageChanged: onPageChanged),
      ),
    ),
  );
}

List<Widget> _pages() => const [
  ColoredBox(key: Key('A'), color: Colors.red, child: SizedBox.expand()),
  ColoredBox(key: Key('B'), color: Colors.green, child: SizedBox.expand()),
];

void main() {
  group('FlipPage snapshot fallback', () {
    testWidgets('missing snapshot does not block drag settling', (
      tester,
    ) async {
      int? changedTo;
      debugDisableFlipPageSnapshotCapture = true;
      addTearDown(() => debugDisableFlipPageSnapshotCapture = false);

      await tester.pumpWidget(
        _harness(pages: _pages(), onPageChanged: (i) => changedTo = i),
      );

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);

      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('A')), findsNothing);
      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });
  });
}
