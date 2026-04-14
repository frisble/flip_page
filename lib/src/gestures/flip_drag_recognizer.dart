import 'package:flutter/gestures.dart';

/// Custom horizontal-drag recognizer with edge-hit-zone gating.
///
/// Only enters the gesture arena when the pointer-down occurs within the
/// outer [edgeHitZoneFraction] of the slot width on either side. Pointers
/// outside that zone are silently rejected so child recognizers (buttons,
/// scrollables) can claim them without competition.
class FlipDragRecognizer extends HorizontalDragGestureRecognizer {
  FlipDragRecognizer({
    super.supportedDevices,
    this.edgeHitZoneFraction = 0.4,
    this.slotWidth = double.infinity,
  });

  /// Fraction of the slot width on each side that is sensitive to flip drags.
  ///
  /// `0.4` means the outer 40% on the left and the outer 40% on the right
  /// are hot zones — leaving a 20% dead-zone in the centre.
  double edgeHitZoneFraction;

  /// Current slot width. Updated by the widget factory on each build.
  double slotWidth;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (!super.isPointerAllowed(event)) return false;
    if (slotWidth <= 0 || slotWidth.isInfinite) return true;
    final double x = event.localPosition.dx;
    final double edgeWidth = slotWidth * edgeHitZoneFraction;
    return x <= edgeWidth || x >= slotWidth - edgeWidth;
  }
}
