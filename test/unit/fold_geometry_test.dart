import 'package:flip_page/src/rendering/fold_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size slot = Size(400, 600);
  // Common anchor points (perimeter).
  const Offset topRight = Offset(400, 0);
  const Offset bottomRight = Offset(400, 600);
  const Offset bottomLeft = Offset(0, 600);

  group('FoldGeometry identity case', () {
    test('pointer == anchor → foldLine is null', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: topRight,
        pointer: topRight,
      );
      expect(geom.foldLine, isNull);
      expect(geom.progress, equals(0.0));
    });

    test('identity case → unfolded region covers the whole slot', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: bottomRight,
        pointer: bottomRight,
      );
      final bounds = geom.unfoldedRegion.getBounds();
      expect(bounds.width, equals(slot.width));
      expect(bounds.height, equals(slot.height));
    });
  });

  group('FoldGeometry reflection invariant', () {
    test('reflectionMatrix maps anchor to pointer', () {
      const Offset pointer = Offset(120, 250);
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: topRight,
        pointer: pointer,
      );
      final v = _Vec(topRight.dx, topRight.dy, 0);
      final transformed = _apply(geom.reflectionMatrix, v);
      expect(transformed.x, closeTo(pointer.dx, 1e-6));
      expect(transformed.y, closeTo(pointer.dy, 1e-6));
    });

    test('reflection is an involution (applying twice returns the input)', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: bottomLeft,
        pointer: const Offset(250, 120),
      );
      const start = _Vec(100, 200, 0);
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
        anchor: bottomRight,
        pointer: const Offset(100, 300),
      );
      final u = geom.unfoldedRegion.getBounds();
      final f = geom.foldedPolygon.getBounds();
      expect(u.left, greaterThanOrEqualTo(-1e-3));
      expect(u.top, greaterThanOrEqualTo(-1e-3));
      expect(u.right, lessThanOrEqualTo(slot.width + 1e-3));
      expect(u.bottom, lessThanOrEqualTo(slot.height + 1e-3));
      expect(f.left, greaterThanOrEqualTo(-1e-3));
      expect(f.top, greaterThanOrEqualTo(-1e-3));
      expect(f.right, lessThanOrEqualTo(slot.width + 1e-3));
      expect(f.bottom, lessThanOrEqualTo(slot.height + 1e-3));
      expect(u.width * u.height, greaterThan(0));
      expect(f.width * f.height, greaterThan(0));
    });

    test('folded polygon contains the anchor', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: topRight,
        pointer: const Offset(120, 200),
      );
      expect(geom.foldedPolygon.contains(geom.anchorPosition), isTrue);
    });

    test('unfolded region contains the opposite point', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: topRight,
        pointer: const Offset(120, 200),
      );
      // Opposite of topRight(400,0) through center = (0, 600)
      expect(geom.unfoldedRegion.contains(bottomLeft), isTrue);
    });

    test('works with edge-center anchor (not a corner)', () {
      // Anchor at the middle of the right edge.
      const Offset midRight = Offset(400, 300);
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: midRight,
        pointer: const Offset(150, 300),
      );
      expect(geom.foldLine, isNotNull);
      expect(geom.foldedPolygon.contains(midRight), isTrue);
    });

    test('works with top-edge anchor (not a corner)', () {
      // Anchor at top edge, 75% across.
      const Offset topEdge = Offset(300, 0);
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: topEdge,
        pointer: const Offset(100, 400),
      );
      expect(geom.foldLine, isNotNull);
      final f = geom.foldedPolygon.getBounds();
      expect(f.width * f.height, greaterThan(0));
    });
  });

  group('FoldGeometry progress', () {
    test('progress is 0 at identity', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: bottomRight,
        pointer: bottomRight,
      );
      expect(geom.progress, equals(0));
    });

    test('progress is monotonic in pointer distance from anchor', () {
      const Offset anchor = bottomRight;
      const Offset opposite = Offset(0, 0); // diag opposite of bottomRight
      final progresses = [0.0, 0.25, 0.5, 0.75, 1.0].map((t) {
        final p = Offset.lerp(anchor, opposite, t)!;
        return FoldGeometry(
          slotSize: slot,
          anchor: anchor,
          pointer: p,
        ).progress;
      }).toList();
      for (int i = 1; i < progresses.length; i++) {
        expect(progresses[i], greaterThanOrEqualTo(progresses[i - 1] - 1e-9));
      }
      expect(progresses.last, greaterThan(0));
    });

    test('progress is clamped to [0, 1]', () {
      final geom = FoldGeometry(
        slotSize: slot,
        anchor: const Offset(0, 0),
        pointer: const Offset(10000, 10000),
      );
      expect(geom.progress, lessThanOrEqualTo(1.0));
    });
  });
}

class _Vec {
  const _Vec(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

_Vec _apply(Matrix4 m, _Vec v) {
  final double nx = m.entry(0, 0) * v.x +
      m.entry(0, 1) * v.y +
      m.entry(0, 2) * v.z +
      m.entry(0, 3);
  final double ny = m.entry(1, 0) * v.x +
      m.entry(1, 1) * v.y +
      m.entry(1, 2) * v.z +
      m.entry(1, 3);
  final double nz = m.entry(2, 0) * v.x +
      m.entry(2, 1) * v.y +
      m.entry(2, 2) * v.z +
      m.entry(2, 3);
  return _Vec(nx, ny, nz);
}
