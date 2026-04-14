import 'package:flip_page/src/layout/spread_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpreadLayout.resolve', () {
    test('portrait when ratio below 1.2', () {
      const constraints = BoxConstraints(
        maxWidth: 400,
        maxHeight: 800,
      );
      expect(SpreadLayout.resolve(constraints), equals(SpreadMode.portrait));
    });

    test('landscape when ratio at 1.2', () {
      const constraints = BoxConstraints(
        maxWidth: 480,
        maxHeight: 400,
      );
      expect(SpreadLayout.resolve(constraints), equals(SpreadMode.landscape));
    });

    test('landscape when ratio above 1.2', () {
      const constraints = BoxConstraints(
        maxWidth: 800,
        maxHeight: 400,
      );
      expect(SpreadLayout.resolve(constraints), equals(SpreadMode.landscape));
    });

    test('portrait when height unbounded', () {
      const constraints = BoxConstraints(maxWidth: 1000);
      expect(SpreadLayout.resolve(constraints), equals(SpreadMode.portrait));
    });

    test('portrait when height is zero', () {
      const constraints = BoxConstraints(maxWidth: 1000, maxHeight: 0);
      expect(SpreadLayout.resolve(constraints), equals(SpreadMode.portrait));
    });

    test('custom threshold respected', () {
      const constraints = BoxConstraints(maxWidth: 100, maxHeight: 100);
      expect(
        SpreadLayout.resolve(constraints, threshold: 0.9),
        equals(SpreadMode.landscape),
      );
      expect(
        SpreadLayout.resolve(constraints, threshold: 1.1),
        equals(SpreadMode.portrait),
      );
    });
  });
}
