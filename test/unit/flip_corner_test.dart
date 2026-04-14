import 'package:flip_page/src/rendering/flip_corner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size slot = Size(400, 600);

  group('FlipCorner.pickFromPointer', () {
    test('top-right quadrant → topRight', () {
      expect(
        FlipCorner.pickFromPointer(const Offset(300, 100), slot),
        equals(FlipCorner.topRight),
      );
    });

    test('bottom-right quadrant → bottomRight', () {
      expect(
        FlipCorner.pickFromPointer(const Offset(300, 500), slot),
        equals(FlipCorner.bottomRight),
      );
    });

    test('top-left quadrant → topLeft', () {
      expect(
        FlipCorner.pickFromPointer(const Offset(100, 100), slot),
        equals(FlipCorner.topLeft),
      );
    });

    test('bottom-left quadrant → bottomLeft', () {
      expect(
        FlipCorner.pickFromPointer(const Offset(100, 500), slot),
        equals(FlipCorner.bottomLeft),
      );
    });

    test('dead-center falls to bottomRight (documented default)', () {
      expect(
        FlipCorner.pickFromPointer(const Offset(200, 300), slot),
        equals(FlipCorner.bottomRight),
      );
    });

    test('custom cornerFraction biases top/bottom split', () {
      // With cornerFraction=0.2, Y > 120 is "bottom".
      expect(
        FlipCorner.pickFromPointer(
          const Offset(300, 150),
          slot,
          cornerFraction: 0.2,
        ),
        equals(FlipCorner.bottomRight),
      );
      expect(
        FlipCorner.pickFromPointer(
          const Offset(300, 100),
          slot,
          cornerFraction: 0.2,
        ),
        equals(FlipCorner.topRight),
      );
    });
  });

  group('FlipCorner.opposite', () {
    test('topLeft ↔ bottomRight', () {
      expect(FlipCorner.topLeft.opposite, equals(FlipCorner.bottomRight));
      expect(FlipCorner.bottomRight.opposite, equals(FlipCorner.topLeft));
    });

    test('topRight ↔ bottomLeft', () {
      expect(FlipCorner.topRight.opposite, equals(FlipCorner.bottomLeft));
      expect(FlipCorner.bottomLeft.opposite, equals(FlipCorner.topRight));
    });
  });

  group('FlipCorner.position', () {
    test('returns slot corner offsets', () {
      expect(FlipCorner.topLeft.position(slot), equals(Offset.zero));
      expect(FlipCorner.topRight.position(slot), equals(const Offset(400, 0)));
      expect(
        FlipCorner.bottomRight.position(slot),
        equals(const Offset(400, 600)),
      );
      expect(FlipCorner.bottomLeft.position(slot), equals(const Offset(0, 600)));
    });
  });

  group('FlipCorner.isRightSide', () {
    test('right corners → true', () {
      expect(FlipCorner.topRight.isRightSide, isTrue);
      expect(FlipCorner.bottomRight.isRightSide, isTrue);
    });

    test('left corners → false', () {
      expect(FlipCorner.topLeft.isRightSide, isFalse);
      expect(FlipCorner.bottomLeft.isRightSide, isFalse);
    });
  });
}
