import 'package:flutter/widgets.dart';

import 'flip_corner.dart';

/// Direction of an in-progress flip.
enum FlipDirection { none, forward, backward }

/// Pure value object describing a paper-fold state.
///
/// Given a slot size, an anchor corner, and a current pointer position,
/// computes the fold line (perpendicular bisector of `anchor → pointer`)
/// and the derived clip paths / reflection matrix used to render the peel.
///
/// All math is pure; safe to construct anywhere and 100% unit-testable.
/// See research.md R1 for the algorithm.
@immutable
class FoldGeometry {
  FoldGeometry({
    required this.slotSize,
    required this.anchor,
    required this.pointer,
  }) {
    final Offset anchorPos = anchor.position(slotSize);
    _anchorPosition = anchorPos;

    final Offset v = pointer - anchorPos;
    final double vLen = v.distance;
    if (vLen < _epsilon) {
      // Identity case: no fold.
      _foldLine = null;
      _reflectionMatrix = Matrix4.identity();
      _unfoldedRegion = _rectPath(slotSize);
      _foldedPolygon = Path();
      _reflectedFoldedPolygon = Path();
      _shadowPath = Path();
      _progress = 0;
      return;
    }

    final Offset normal = Offset(v.dx / vLen, v.dy / vLen);
    final Offset mid = Offset(
      (anchorPos.dx + pointer.dx) / 2,
      (anchorPos.dy + pointer.dy) / 2,
    );

    // Fold line represented by two points far apart along the perpendicular
    // direction, well beyond the slot rectangle so clipping logic sees a
    // line (not a segment).
    final double span = slotSize.width + slotSize.height;
    final Offset perp = Offset(-normal.dy, normal.dx);
    _foldLine = (
      a: mid - perp * span,
      b: mid + perp * span,
    );

    _reflectionMatrix = _buildReflectionMatrix(normal, mid);

    // Polygon clipping: slot rect in CCW order.
    final List<Offset> slotPoly = [
      Offset.zero,
      Offset(slotSize.width, 0),
      Offset(slotSize.width, slotSize.height),
      Offset(0, slotSize.height),
    ];

    // Unfolded region: half-plane on the pointer side (signed distance via
    // `normal` is positive for pointer-side points).
    final List<Offset> unfolded = _clipHalfPlane(slotPoly, mid, normal);
    final List<Offset> folded = _clipHalfPlane(
      slotPoly,
      mid,
      Offset(-normal.dx, -normal.dy),
    );

    _unfoldedRegion = _polyPath(unfolded);
    _foldedPolygon = _polyPath(folded);
    _reflectedFoldedPolygon = _polyPath(
      folded.map((p) => _reflect(p, normal, mid)).toList(growable: false),
    );
    _shadowPath = _buildShadowPath(unfolded, mid, perp, normal);

    _progress = (vLen / _diagonal(slotSize)).clamp(0.0, 1.0);
  }

  static const double _epsilon = 1e-6;

  /// Slot rendering size.
  final Size slotSize;

  /// Drag-anchor corner.
  final FlipCorner anchor;

  /// Current pointer position in slot-local coordinates. Caller is
  /// responsible for clamping the pointer to the slot's valid half-plane.
  final Offset pointer;

  late final Offset _anchorPosition;
  late final ({Offset a, Offset b})? _foldLine;
  late final Matrix4 _reflectionMatrix;
  late final Path _unfoldedRegion;
  late final Path _foldedPolygon;
  late final Path _reflectedFoldedPolygon;
  late final Path _shadowPath;
  late final double _progress;

  /// Anchor corner position in slot-local coords.
  Offset get anchorPosition => _anchorPosition;

  /// Fold line defined by two points, or `null` when pointer equals anchor.
  ({Offset a, Offset b})? get foldLine => _foldLine;

  /// Affine 2-D reflection across the fold line, embedded in a 4x4 matrix.
  Matrix4 get reflectionMatrix => _reflectionMatrix;

  /// Slot rect clipped to the pointer-side half-plane.
  Path get unfoldedRegion => _unfoldedRegion;

  /// Slot rect clipped to the anchor-side half-plane.
  Path get foldedPolygon => _foldedPolygon;

  /// [foldedPolygon] put through [reflectionMatrix].
  Path get reflectedFoldedPolygon => _reflectedFoldedPolygon;

  /// Thin band along the fold line clipped to [unfoldedRegion].
  Path get shadowPath => _shadowPath;

  /// Normalized fold progress in `[0, 1]`.
  double get progress => _progress;

  static Matrix4 _buildReflectionMatrix(Offset n, Offset m) {
    final double nx = n.dx;
    final double ny = n.dy;
    final double k = 2 * (nx * m.dx + ny * m.dy);
    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(0, 0, 1 - 2 * nx * nx)
      ..setEntry(0, 1, -2 * nx * ny)
      ..setEntry(0, 3, k * nx)
      ..setEntry(1, 0, -2 * nx * ny)
      ..setEntry(1, 1, 1 - 2 * ny * ny)
      ..setEntry(1, 3, k * ny);
    return matrix;
  }

  static Offset _reflect(Offset p, Offset n, Offset m) {
    final double d = (p.dx - m.dx) * n.dx + (p.dy - m.dy) * n.dy;
    return Offset(p.dx - 2 * d * n.dx, p.dy - 2 * d * n.dy);
  }

  /// Sutherland-Hodgman single-plane clip.
  ///
  /// Keeps points where `(p - origin) · normal >= 0`. Input `polygon` must
  /// be a closed polygon in CCW order.
  static List<Offset> _clipHalfPlane(
    List<Offset> polygon,
    Offset origin,
    Offset normal,
  ) {
    if (polygon.isEmpty) return const [];
    final List<Offset> out = [];
    for (int i = 0; i < polygon.length; i++) {
      final Offset curr = polygon[i];
      final Offset prev = polygon[(i - 1 + polygon.length) % polygon.length];
      final double currSide = _signedDist(curr, origin, normal);
      final double prevSide = _signedDist(prev, origin, normal);
      if (currSide >= 0) {
        if (prevSide < 0) {
          out.add(_intersectOnPlane(prev, curr, origin, normal));
        }
        out.add(curr);
      } else if (prevSide >= 0) {
        out.add(_intersectOnPlane(prev, curr, origin, normal));
      }
    }
    return out;
  }

  static double _signedDist(Offset p, Offset origin, Offset normal) {
    return (p.dx - origin.dx) * normal.dx + (p.dy - origin.dy) * normal.dy;
  }

  static Offset _intersectOnPlane(
    Offset a,
    Offset b,
    Offset origin,
    Offset normal,
  ) {
    final double da = _signedDist(a, origin, normal);
    final double db = _signedDist(b, origin, normal);
    final double denom = da - db;
    if (denom.abs() < _epsilon) return a;
    final double t = da / denom;
    return Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
  }

  static Path _polyPath(List<Offset> vertices) {
    final Path path = Path();
    if (vertices.isEmpty) return path;
    path.moveTo(vertices.first.dx, vertices.first.dy);
    for (int i = 1; i < vertices.length; i++) {
      path.lineTo(vertices[i].dx, vertices[i].dy);
    }
    path.close();
    return path;
  }

  static Path _rectPath(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  /// Returns a narrow quadrilateral along the fold line, intersected with
  /// the unfolded polygon so the shadow never spills outside the page.
  static Path _buildShadowPath(
    List<Offset> unfoldedPoly,
    Offset mid,
    Offset perp,
    Offset normal,
  ) {
    if (unfoldedPoly.isEmpty) return Path();

    // A thin strip: two lines parallel to the fold line, one on each side
    // of the fold, offset by a few device-independent pixels. We only need
    // the unfolded-side sliver for the shadow — the other side is behind
    // the peeled layer and gets painted opaque anyway.
    const double stripOffset = 0.5;
    final double span = 10000;
    final Offset stripInner = Offset(
      mid.dx + stripOffset * normal.dx,
      mid.dy + stripOffset * normal.dy,
    );
    final List<Offset> stripPoly = [
      mid - perp * span,
      mid + perp * span,
      stripInner + perp * span,
      stripInner - perp * span,
    ];

    // Clip the strip to the unfolded region by clipping against each edge
    // of the unfolded polygon. For simplicity we treat each unfolded edge
    // as an interior half-plane.
    List<Offset> result = stripPoly;
    for (int i = 0; i < unfoldedPoly.length; i++) {
      final Offset a = unfoldedPoly[i];
      final Offset b = unfoldedPoly[(i + 1) % unfoldedPoly.length];
      final Offset edge = b - a;
      final Offset edgeNormal = Offset(-edge.dy, edge.dx); // interior normal for CCW polygon
      final double edgeLen = edgeNormal.distance;
      if (edgeLen < _epsilon) continue;
      final Offset unit = Offset(edgeNormal.dx / edgeLen, edgeNormal.dy / edgeLen);
      result = _clipHalfPlane(result, a, unit);
      if (result.isEmpty) return Path();
    }
    return _polyPath(result);
  }

  static double _diagonal(Size size) {
    return (size.width * size.width + size.height * size.height);
  }
}
