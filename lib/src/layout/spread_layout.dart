import 'package:flutter/widgets.dart';

/// Layout mode for a [FlipPage] render slot.
enum SpreadMode {
  /// Single page fills the available area.
  portrait,

  /// Two pages are shown side-by-side as a book spread.
  landscape,
}

/// Pure resolver: picks the spread mode from [BoxConstraints].
///
/// Landscape is chosen when the aspect ratio (width ÷ height) reaches
/// [landscapeThreshold] (default `1.2`). Below that, portrait is used.
/// Using the raw ratio rather than [MediaQueryData.orientation] means the
/// widget works inside dialogs, sheets, and resizable desktop windows.
class SpreadLayout {
  /// Default aspect-ratio threshold for switching to landscape.
  static const double landscapeThreshold = 1.2;

  /// Returns the [SpreadMode] for the given [constraints].
  ///
  /// If [constraints] has unbounded height the resolver falls back to
  /// portrait (no sensible aspect ratio can be computed).
  static SpreadMode resolve(
    BoxConstraints constraints, {
    double threshold = landscapeThreshold,
  }) {
    if (!constraints.hasBoundedHeight || constraints.maxHeight == 0) {
      return SpreadMode.portrait;
    }
    final double ratio = constraints.maxWidth / constraints.maxHeight;
    return ratio >= threshold ? SpreadMode.landscape : SpreadMode.portrait;
  }
}
