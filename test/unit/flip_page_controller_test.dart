import 'package:flip_page/flip_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlipPageController', () {
    test('hasClients false before attach', () {
      final c = FlipPageController();
      expect(c.hasClients, isFalse);
      expect(c.currentPage, equals(0));
      c.dispose();
    });

    test('jumpTo while detached is a silent no-op', () {
      final c = FlipPageController();
      int notifications = 0;
      c.addListener(() => notifications++);
      c.jumpTo(3);
      expect(c.currentPage, equals(0));
      expect(notifications, equals(0));
      c.dispose();
    });

    test('next/previous while detached are silent no-ops', () {
      final c = FlipPageController();
      c.next();
      c.previous();
      expect(c.currentPage, equals(0));
      c.dispose();
    });

    test('initialPage sets currentPage', () {
      final c = FlipPageController(initialPage: 5);
      expect(c.currentPage, equals(5));
      c.dispose();
    });
  });
}
