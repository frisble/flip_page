import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how many times each page id is mounted, so tests can assert a page's
/// State survives a flip instead of remounting (which is what caused the
/// visible image-reload flicker).
final Map<String, int> _mountCounts = {};

class _CountingPage extends StatefulWidget {
  _CountingPage(this.id) : super(key: ValueKey(id));

  final String id;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    _mountCounts.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colors.grey, child: const SizedBox.expand());
}

Widget _harness() => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 400,
      height: 600,
      child: FlipPage(
        pages: [_CountingPage('A'), _CountingPage('B'), _CountingPage('C')],
      ),
    ),
  ),
);

void main() {
  setUp(_mountCounts.clear);

  group('FlipPage page-state retention', () {
    testWidgets('a reverting drag does not remount the current page', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(_mountCounts['A'], 1);

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      // Start inside the right edge hit-zone, nudge a little (below the 50%
      // completion threshold), then release → the flip reverts to page A.
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(-size.width * 0.1, 0));
      await tester.pump();

      // Mid-drag the outgoing page is kept mounted (offstage), never re-created.
      expect(_mountCounts['A'], 1);

      // The revealed page must still get the full slot size — the offstage
      // keep-alive must not collapse the Stack (regression guard).
      expect(
        tester.getSize(find.byKey(const ValueKey('B'))).width,
        moreOrLessEquals(size.width, epsilon: 1),
      );

      await gesture.up();
      await tester.pumpAndSettle();

      // Back on A, and it was never remounted → no image reload.
      expect(_mountCounts['A'], 1);
    });

    testWidgets('neighbour pages are pre-mounted at idle and survive reveal', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // On page A (index 0) the next page B is already mounted (offstage) so a
      // flip reveals it without building/loading from scratch. C is beyond the
      // ±1 warm window, so it is not mounted yet.
      expect(_mountCounts['B'], 1);
      expect(_mountCounts['C'], isNull);

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      await tester.dragFrom(
        Offset(center.dx + size.width * 0.3, center.dy),
        Offset(-size.width * 0.7, 0),
      );
      await tester.pumpAndSettle();

      // B migrated from the warm slot into view — never rebuilt.
      expect(_mountCounts['B'], 1);
    });

    testWidgets('completing a flip mounts the destination page exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.3, center.dy);
      await tester.dragFrom(start, Offset(-size.width * 0.7, 0));
      await tester.pumpAndSettle();

      // B was shown live during the drag (peek) then settled into the idle
      // slot. Without stable page identity it would mount twice.
      expect(_mountCounts['B'], 1);
    });
  });
}
