import 'dart:ui';

/// Which corner of a page slot is the drag-anchor during a flip.
///
/// See research.md R11 for the corner-selection rules.
enum FlipCorner {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft;

  /// The Cartesian position of this corner inside a slot of [slotSize],
  /// in slot-local coordinates (top-left origin, Y-down).
  Offset position(Size slotSize) {
    switch (this) {
      case FlipCorner.topLeft:
        return Offset.zero;
      case FlipCorner.topRight:
        return Offset(slotSize.width, 0);
      case FlipCorner.bottomRight:
        return Offset(slotSize.width, slotSize.height);
      case FlipCorner.bottomLeft:
        return Offset(0, slotSize.height);
    }
  }

  /// The diagonally-opposite corner. Used to parameterize the pointer path
  /// along the drag diagonal when translating a 1-D progress scalar into a
  /// 2-D pointer position.
  FlipCorner get opposite {
    switch (this) {
      case FlipCorner.topLeft:
        return FlipCorner.bottomRight;
      case FlipCorner.topRight:
        return FlipCorner.bottomLeft;
      case FlipCorner.bottomRight:
        return FlipCorner.topLeft;
      case FlipCorner.bottomLeft:
        return FlipCorner.topRight;
    }
  }

  /// Whether this corner is on the right-hand side of its slot. Right-side
  /// corners drive forward flips; left-side corners drive backward flips.
  bool get isRightSide =>
      this == FlipCorner.topRight || this == FlipCorner.bottomRight;

  /// Picks a drag-anchor corner from a pointer position at drag start.
  ///
  /// The slot is split horizontally at the midpoint and vertically at
  /// `cornerFraction * slotSize.height` (default `0.5`). Pointers exactly
  /// on a boundary snap to the lower-right quadrant (`bottomRight`) to give
  /// a deterministic, common-case default.
  static FlipCorner pickFromPointer(
    Offset localPointer,
    Size slotSize, {
    double cornerFraction = 0.5,
  }) {
    final bool right = localPointer.dx >= slotSize.width / 2;
    final bool bottom = localPointer.dy >= slotSize.height * cornerFraction;
    if (right && bottom) return FlipCorner.bottomRight;
    if (right && !bottom) return FlipCorner.topRight;
    if (!right && bottom) return FlipCorner.bottomLeft;
    return FlipCorner.topLeft;
  }
}
