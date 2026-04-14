import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'rendering/flip_corner.dart';
import 'rendering/fold_geometry.dart';
import 'rendering/fold_painter.dart';

/// A page-turning widget with a drag-driven paper-curl animation.
///
/// In v0.1:
/// - Portrait layouts show one page at a time.
/// - Landscape two-page spread is planned for User Story 3; this MVP
///   renders portrait only.
/// - Flips are initiated by a horizontal drag. The drag-anchor corner is
///   picked from the pointer position at drag start (4 corners in portrait,
///   see [FlipCorner.pickFromPointer]). Releasing past the halfway
///   threshold (or with sufficient velocity) completes the flip; otherwise
///   it reverts.
///
/// See `specs/001-core-widget/quickstart.md` for usage snippets.
class FlipPage extends StatefulWidget {
  /// Creates a [FlipPage] with an ordered list of [pages].
  const FlipPage({
    super.key,
    required this.pages,
    this.onPageChanged,
    this.initialPage = 0,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
    this.backTintColor = const Color(0x66000000),
    this.shadowColor = const Color(0x33000000),
    this.flipCornerFraction = 0.5,
  });

  /// Ordered list of pages to display. May be empty.
  final List<Widget> pages;

  /// Invoked once per settled page transition with the new index.
  final ValueChanged<int>? onPageChanged;

  /// Initial page index. Clamped to `[0, pages.length - 1]`.
  final int initialPage;

  /// Duration of the settle animation after the user releases a drag.
  final Duration animationDuration;

  /// Curve applied to the settle animation.
  final Curve animationCurve;

  /// Tint blended over the reflected (back) side of the peeling page.
  ///
  /// Defaults to a semi-transparent black that reads as "paper back".
  final Color backTintColor;

  /// Colour of the soft drop shadow drawn along the fold line.
  final Color shadowColor;

  /// Vertical split (in `[0, 1]`) between top-corner and bottom-corner
  /// anchors. Passed to [FlipCorner.pickFromPointer] at drag start.
  final double flipCornerFraction;

  @override
  State<FlipPage> createState() => _FlipPageState();
}

class _FlipPageState extends State<FlipPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _currentIndex;
  double _progress = 0;
  FlipDirection _direction = FlipDirection.none;
  FlipCorner? _anchor;
  ui.Image? _outgoingSnapshot;
  final GlobalKey _snapshotKey = GlobalKey(debugLabel: 'flip_page.snapshot');

  static const double _flingVelocityThreshold = 600;
  static const double _completeThreshold = 0.5;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.initialPage);
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onTick);
  }

  @override
  void didUpdateWidget(FlipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationDuration != oldWidget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    if (widget.pages.length != oldWidget.pages.length) {
      final int newIndex = _clampIndex(_currentIndex);
      if (newIndex != _currentIndex) {
        _currentIndex = newIndex;
        _resetDragState();
      }
    }
  }

  @override
  void dispose() {
    _outgoingSnapshot?.dispose();
    _controller
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  int _clampIndex(int i) {
    if (widget.pages.isEmpty) return 0;
    return i.clamp(0, widget.pages.length - 1);
  }

  void _onTick() {
    setState(() => _progress = _controller.value);
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.pages.length <= 1) return;
    if (_controller.isAnimating) _controller.stop();

    final Size? slotSize = context.size;
    if (slotSize == null) return;

    final FlipCorner corner = FlipCorner.pickFromPointer(
      details.localPosition,
      slotSize,
      cornerFraction: widget.flipCornerFraction,
    );
    final FlipDirection candidate = corner.isRightSide
        ? FlipDirection.forward
        : FlipDirection.backward;

    final bool atBoundary = (candidate == FlipDirection.forward &&
            _currentIndex >= widget.pages.length - 1) ||
        (candidate == FlipDirection.backward && _currentIndex <= 0);
    if (atBoundary) {
      _direction = FlipDirection.none;
      return;
    }

    final ui.Image? snapshot = _captureSnapshot();

    setState(() {
      _direction = candidate;
      _anchor = corner;
      _progress = 0;
      _outgoingSnapshot?.dispose();
      _outgoingSnapshot = snapshot;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_direction == FlipDirection.none) return;
    final double width = context.size?.width ?? 1;
    final int sign = _direction == FlipDirection.forward ? -1 : 1;
    final double delta = sign * details.delta.dx / width;
    setState(() {
      _progress = (_progress + delta).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_direction == FlipDirection.none) return;

    final double velocity = details.velocity.pixelsPerSecond.dx;
    final int sign = _direction == FlipDirection.forward ? -1 : 1;
    final double signedVelocity = sign * velocity;
    final bool shouldComplete = _progress >= _completeThreshold ||
        signedVelocity >= _flingVelocityThreshold;
    final double target = shouldComplete ? 1.0 : 0.0;

    _controller.value = _progress;
    _controller
        .animateTo(
      target,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
    )
        .whenComplete(() {
      if (!mounted) return;
      if (shouldComplete) {
        _settleComplete();
      } else {
        _settleRevert();
      }
    });
  }

  void _settleComplete() {
    final int newIndex = _currentIndex +
        (_direction == FlipDirection.forward ? 1 : -1);
    setState(() {
      _currentIndex = newIndex;
      _resetDragState();
    });
    widget.onPageChanged?.call(newIndex);
  }

  void _settleRevert() {
    setState(_resetDragState);
  }

  void _resetDragState() {
    _progress = 0;
    _direction = FlipDirection.none;
    _anchor = null;
    _outgoingSnapshot?.dispose();
    _outgoingSnapshot = null;
  }

  ui.Image? _captureSnapshot() {
    final RenderObject? ro = _snapshotKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    if (ro.debugNeedsPaint) return null;
    try {
      return ro.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape spread (US3) is deferred; render portrait for v0.1 MVP.
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: _buildContent(constraints.biggest),
        );
      },
    );
  }

  Widget _buildContent(Size slotSize) {
    final bool dragging =
        _direction != FlipDirection.none && _progress > 0;

    if (!dragging) {
      return RepaintBoundary(
        key: _snapshotKey,
        child: SizedBox.expand(child: widget.pages[_currentIndex]),
      );
    }

    final ui.Image? snapshot = _outgoingSnapshot;
    if (snapshot == null) {
      // Fallback — snapshot not available. Show the current page flat; the
      // settle logic still runs and completes / reverts as expected.
      return SizedBox.expand(child: widget.pages[_currentIndex]);
    }

    final bool isForward = _direction == FlipDirection.forward;
    final int peekIndex =
        isForward ? _currentIndex + 1 : _currentIndex - 1;
    final FlipCorner anchor = _anchor ?? _defaultAnchorFor(isForward);
    final Offset anchorPos = anchor.position(slotSize);
    final Offset oppositePos = anchor.opposite.position(slotSize);
    final Offset pointer = Offset.lerp(anchorPos, oppositePos, _progress)!;
    final FoldGeometry geometry = FoldGeometry(
      slotSize: slotSize,
      anchor: anchor,
      pointer: pointer,
    );

    return Stack(
      children: [
        Positioned.fill(child: widget.pages[peekIndex]),
        Positioned.fill(
          child: CustomPaint(
            painter: FoldPainter(
              snapshot: snapshot,
              geometry: geometry,
              backTintColor: widget.backTintColor,
              shadowColor: widget.shadowColor,
            ),
          ),
        ),
      ],
    );
  }

  FlipCorner _defaultAnchorFor(bool forward) =>
      forward ? FlipCorner.bottomRight : FlipCorner.bottomLeft;
}
