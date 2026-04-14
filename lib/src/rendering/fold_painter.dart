import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'fold_geometry.dart';

/// Paints the peeled-page layers driven by a [FoldGeometry].
///
/// Draws, in order inside [paint]:
/// 1. unfolded portion of the outgoing page (clipped to `unfoldedRegion`);
/// 2. reflected/peeled portion tinted with `backTintColor`;
/// 3. a soft drop shadow along the fold line, clipped to the unfolded region.
///
/// All three layers share the same `snapshot` input so the paint cost is one
/// image blit per layer, no per-frame allocation of images.
class FoldPainter extends CustomPainter {
  FoldPainter({
    required this.snapshot,
    required this.geometry,
    required this.backTintColor,
    required this.shadowColor,
    this.shadowSigma = 8,
  });

  final ui.Image snapshot;
  final FoldGeometry geometry;
  final Color backTintColor;
  final Color shadowColor;
  final double shadowSigma;

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.foldLine == null) return;

    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Layer 1: unfolded outgoing page.
    canvas.save();
    canvas.clipPath(geometry.unfoldedRegion);
    canvas.drawImageRect(snapshot, srcRect, dstRect, Paint());
    canvas.restore();

    // Layer 2: peeled / reflected page with tint overlay.
    canvas.save();
    canvas.clipPath(geometry.reflectedFoldedPolygon);
    canvas.transform(geometry.reflectionMatrix.storage);
    canvas.drawImageRect(snapshot, srcRect, dstRect, Paint());
    canvas.restore();

    canvas.save();
    canvas.clipPath(geometry.reflectedFoldedPolygon);
    final Paint tintPaint = Paint()..color = backTintColor;
    canvas.drawPath(geometry.reflectedFoldedPolygon, tintPaint);
    canvas.restore();

    // Layer 3: soft shadow along fold line, clipped to unfolded region.
    canvas.save();
    canvas.clipPath(geometry.unfoldedRegion);
    final Paint shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowSigma);
    canvas.drawPath(geometry.shadowPath, shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FoldPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.geometry != geometry ||
        oldDelegate.backTintColor != backTintColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowSigma != shadowSigma;
  }
}
