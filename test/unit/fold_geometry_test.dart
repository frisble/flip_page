import 'package:flip_page/src/rendering/flip_corner.dart';
import 'package:flip_page/src/rendering/fold_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size slot = Size(400, 600);

  group('FoldGeometry identity case', () {
    test('pointer == anchor → foldLine is null', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.topRight,
        pointer: FlipCorner.topRight.position(slot),
      );
      expect(geom.foldLine, isNull);
      expect(geom.progress, equals(0.0));
    });

    test('identity case → unfolded region covers the whole slot', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.bottomRight,
        pointer: FlipCorner.bottomRight.position(slot),
      );
      final bounds = geom.unfoldedRegion.getBounds();
      expect(bounds.width, equals(slot.width));
      expect(bounds.height, equals(slot.height));
    });
  });

  group('FoldGeometry reflection invariant', () {
    test('reflectionMatrix maps anchorPosition to pointer', () {
      final Offset anchorPos = FlipCorner.topRight.position(slot);
      const Offset pointer = Offset(120, 250);
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.topRight,
        pointer: pointer,
      );
      final v = Vector3Like(anchorPos.dx, anchorPos.dy, 0);
      final transformed = _apply(geom.reflectionMatrix, v);
      expect(transformed.x, closeTo(pointer.dx, 1e-6));
      expect(transformed.y, closeTo(pointer.dy, 1e-6));
    });

    test('reflection is an involution (applying twice returns the input)', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.bottomLeft,
        pointer: const Offset(250, 120),
      );
      const start = Vector3Like(100, 200, 0);
      final once = _apply(geom.reflectionMatrix, start);
      final twice = _apply(geom.reflectionMatrix, once);
      expect(twice.x, closeTo(start.x, 1e-6));
      expect(twice.y, closeTo(start.y, 1e-6));
    });
  });

  group('FoldGeometry partition of the slot rect', () {
    test('unfolded + folded bounds cover the slot', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.bottomRight,
        pointer: const Offset(100, 300),
      );
      final u = geom.unfoldedRegion.getBounds();
      final f = geom.foldedPolygon.getBounds();
      // Each region fits inside the slot rect.
      expect(u.left, greaterThanOrEqualTo(-1e-3));
      expect(u.top, greaterThanOrEqualTo(-1e-3));
      expect(u.right, lessThanOrEqualTo(slot.width + 1e-3));
      expect(u.bottom, lessThanOrEqualTo(slot.height + 1e-3));
      expect(f.left, greaterThanOrEqualTo(-1e-3));
      expect(f.top, greaterThanOrEqualTo(-1e-3));
      expect(f.right, lessThanOrEqualTo(slot.width + 1e-3));
      expect(f.bottom, lessThanOrEqualTo(slot.height + 1e-3));
      // Both regions are non-empty when fold line is present.
      expect(u.width * u.height, greaterThan(0));
      expect(f.width * f.height, greaterThan(0));
    });

    test('folded polygon contains the anchor corner', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.topRight,
        pointer: const Offset(120, 200),
      );
      expect(geom.foldedPolygon.contains(geom.anchorPosition), isTrue);
    });

    test('unfolded region contains the opposite corner', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.topRight,
        pointer: const Offset(120, 200),
      );
      final opposite = FlipCorner.topRight.opposite.position(slot);
      expect(geom.unfoldedRegion.contains(opposite), isTrue);
    });
  });

  group('FoldGeometry progress', () {
    test('progress is 0 at identity', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.bottomRight,
        pointer: FlipCorner.bottomRight.position(slot),
      );
      expect(geom.progress, equals(0));
    });

    test('progress is monotonic in pointer distance from anchor', () {
      final Offset anchorPos = FlipCorner.bottomRight.position(slot);
      final Offset oppositePos = FlipCorner.bottomRight.opposite.position(slot);
      final progresses = [0.0, 0.25, 0.5, 0.75, 1.0].map((t) {
        final p = Offset.lerp(anchorPos, oppositePos, t)!;
        return FoldGeometry(
          slotSize: slot,
          anchor: FlipCorner.bottomRight,
          pointer: p,
        ).progress;
      }).toList();
      for (int i = 1; i < progresses.length; i++) {
        expect(progresses[i], greaterThanOrEqualTo(progresses[i - 1] - 1e-9));
      }
      // At the opposite corner the fold line bisects the rect — progress
      // is high, but not necessarily 1 (diagonal parameterization).
      expect(progresses.last, greaterThan(0));
    });

    test('progress is clamped to [0, 1]', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: FlipCorner.topLeft,
        pointer: const Offset(10000, 10000),
      );
      expect(geom.progress, lessThanOrEqualTo(1.0));
    });
  });
}

class Vector3Like {
  const Vector3Like(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

Vector3Like _apply(Matrix4 m, Vector3Like v) {
  // Row-ordered application: out = M * (x, y, z, 1)
  final double nx =
      m.entry(0, 0) * v.x + m.entry(0, 1) * v.y + m.entry(0, 2) * v.z + m.entry(0, 3);
  final double ny =
      m.entry(1, 0) * v.x + m.entry(1, 1) * v.y + m.entry(1, 2) * v.z + m.entry(1, 3);
  final double nz =
      m.entry(2, 0) * v.x + m.entry(2, 1) * v.y + m.entry(2, 2) * v.z + m.entry(2, 3);
  return Vector3Like(nx, ny, nz);
}
