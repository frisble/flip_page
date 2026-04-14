import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flip_page_controller.dart';
import 'gestures/flip_drag_recognizer.dart';
import 'rendering/flip_corner.dart';
import 'layout/spread_layout.dart';
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
    this.controller,
    this.onPageChanged,
    this.initialPage = 0,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
    this.backTintColor = const Color(0x66000000),
    this.shadowColor = const Color(0x33000000),
    this.flipCornerFraction = 0.5,
    this.edgeHitZoneFraction,
  });

  /// Ordered list of pages to display. May be empty.
  final List<Widget> pages;

  /// Optional controller for programmatic navigation.
  ///
  /// If `null`, the widget owns an internal controller. If supplied, the
  /// caller is responsible for [FlipPageController.dispose].
  final FlipPageController? controller;

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

  /// Fraction of the slot width on each side that is sensitive to flip
  /// drags. `null` defaults to `0.4` (outer 40% on each side).
  final double? edgeHitZoneFraction;

  @override
  State<FlipPage> createState() => _FlipPageState();
}

class _FlipPageState extends State<FlipPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late FlipPageController _effectiveController;
  FlipPageController? _ownedController;
  late int _currentIndex;
  double _progress = 0;
  FlipDirection _direction = FlipDirection.none;
  FlipCorner? _anchor;
  ui.Image? _outgoingSnapshot;
  final GlobalKey _snapshotKey = GlobalKey(debugLabel: 'flip_page.snapshot');
  final GlobalKey _snapshotKeyRight = GlobalKey(debugLabel: 'flip_page.snapshot_r');
  bool _isLandscape = false;
  bool _activeSlotIsRight = true;

  static const double _flingVelocityThreshold = 600;
  static const double _completeThreshold = 0.5;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.initialPage);
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onTick);
    _initController();
  }

  @override
  void didUpdateWidget(FlipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationDuration != oldWidget.animationDuration) {
      _animController.duration = widget.animationDuration;
    }
    if (widget.controller != oldWidget.controller) {
      _effectiveController.detach();
      if (oldWidget.controller == null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _initController();
    }
    if (widget.pages.length != oldWidget.pages.length) {
      _effectiveController.updatePageCount(widget.pages.length);
      final int newIndex = _clampIndex(_currentIndex);
      if (newIndex != _currentIndex) {
        _currentIndex = newIndex;
        _resetDragState();
      }
    }
  }

  @override
  void dispose() {
    _effectiveController.detach();
    _ownedController?.dispose();
    _outgoingSnapshot?.dispose();
    _animController
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _initController() {
    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _ownedController = FlipPageController(initialPage: _currentIndex);
      _effectiveController = _ownedController!;
    }
    _effectiveController.attach(
      pageCount: widget.pages.length,
      currentPage: _currentIndex,
      animateHook: _controllerAnimateTo,
      jumpHook: _controllerJumpTo,
    );
  }

  void _controllerJumpTo(int index) {
    setState(() {
      _currentIndex = index;
      _resetDragState();
    });
    _effectiveController.syncCurrentPage(index);
    widget.onPageChanged?.call(index);
  }

  Future<void> _controllerAnimateTo(int index) async {
    // Determine direction for the animation.
    final bool forward = index > _currentIndex;
    final FlipCorner anchor =
        forward ? FlipCorner.bottomRight : FlipCorner.bottomLeft;
    final FlipDirection dir =
        forward ? FlipDirection.forward : FlipDirection.backward;

    final ui.Image? snapshot = _captureSnapshot();

    setState(() {
      _direction = dir;
      _anchor = anchor;
      _progress = 0;
      _outgoingSnapshot?.dispose();
      _outgoingSnapshot = snapshot;
    });

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration dur =
        reduceMotion ? Duration.zero : widget.animationDuration;
    _animController.value = 0;
    await _animController.animateTo(
      1.0,
      duration: dur,
      curve: widget.animationCurve,
    );
    if (!mounted) return;
    _settleComplete(targetIndex: index);
  }

  int _clampIndex(int i) {
    if (widget.pages.isEmpty) return 0;
    return i.clamp(0, widget.pages.length - 1);
  }

  void _onTick() {
    setState(() => _progress = _animController.value);
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.pages.length <= 1) return;
    if (_animController.isAnimating) _animController.stop();

    final Size? fullSize = context.size;
    if (fullSize == null) return;

    // In landscape the pointer's x is in the full-width coordinate space.
    // Determine which slot the pointer landed in.
    final double localX = details.localPosition.dx;
    if (_isLandscape) {
      _activeSlotIsRight = localX >= fullSize.width / 2;
    } else {
      _activeSlotIsRight = true; // meaningless in portrait
    }

    // Remap pointer to slot-local coordinates for corner selection.
    final Size slotSize = _isLandscape
        ? Size(fullSize.width / 2, fullSize.height)
        : fullSize;
    final Offset slotLocal = _isLandscape && _activeSlotIsRight
        ? Offset(localX - fullSize.width / 2, details.localPosition.dy)
        : Offset(
            _isLandscape ? localX : details.localPosition.dx,
            details.localPosition.dy,
          );

    final FlipCorner corner = FlipCorner.pickFromPointer(
      slotLocal,
      slotSize,
      cornerFraction: widget.flipCornerFraction,
    );

    // In landscape: right-slot drag → forward, left-slot drag → backward.
    final FlipDirection candidate;
    if (_isLandscape) {
      candidate = _activeSlotIsRight
          ? FlipDirection.forward
          : FlipDirection.backward;
    } else {
      candidate = corner.isRightSide
          ? FlipDirection.forward
          : FlipDirection.backward;
    }

    final int step = _isLandscape ? 2 : 1;
    final bool atBoundary = (candidate == FlipDirection.forward &&
            _currentIndex + step > widget.pages.length - 1) ||
        (candidate == FlipDirection.backward && _currentIndex - step < 0);
    if (atBoundary) {
      _direction = FlipDirection.none;
      return;
    }

    // Capture snapshot from the appropriate slot's RepaintBoundary.
    final GlobalKey captureKey =
        _isLandscape && _activeSlotIsRight ? _snapshotKeyRight : _snapshotKey;
    final ui.Image? snapshot = _captureSnapshotFrom(captureKey);

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
    final double fullWidth = context.size?.width ?? 1;
    final double slotWidth = _isLandscape ? fullWidth / 2 : fullWidth;
    final int sign = _direction == FlipDirection.forward ? -1 : 1;
    final double delta = sign * details.delta.dx / slotWidth;
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

    _animController.value = _progress;
    _animController
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

  void _settleComplete({int? targetIndex}) {
    final int step = _isLandscape ? 2 : 1;
    final int newIndex = targetIndex ??
        (_currentIndex + (_direction == FlipDirection.forward ? step : -step));
    setState(() {
      _currentIndex = newIndex;
      _resetDragState();
    });
    _effectiveController.syncCurrentPage(newIndex);
    widget.onPageChanged?.call(newIndex);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Page ${newIndex + 1}',
      TextDirection.ltr,
    );
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

  ui.Image? _captureSnapshot() => _captureSnapshotFrom(_snapshotKey);

  ui.Image? _captureSnapshotFrom(GlobalKey key) {
    final RenderObject? ro = key.currentContext?.findRenderObject();
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
        _isLandscape =
            SpreadLayout.resolve(constraints) == SpreadMode.landscape;
        final double slotWidth = _isLandscape
            ? constraints.biggest.width / 2
            : constraints.biggest.width;
        return RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
            FlipDragRecognizer:
                GestureRecognizerFactoryWithHandlers<FlipDragRecognizer>(
              () => FlipDragRecognizer(
                edgeHitZoneFraction:
                    widget.edgeHitZoneFraction ?? 0.4,
                slotWidth: slotWidth,
              ),
              (FlipDragRecognizer instance) {
                instance
                  ..edgeHitZoneFraction =
                      widget.edgeHitZoneFraction ?? 0.4
                  ..slotWidth = slotWidth
                  ..onStart = _onDragStart
                  ..onUpdate = _onDragUpdate
                  ..onEnd = _onDragEnd;
              },
            ),
          },
          behavior: HitTestBehavior.translucent,
          child: _isLandscape
              ? _buildLandscape(constraints.biggest)
              : _buildPortrait(constraints.biggest),
        );
      },
    );
  }

  // --------------- Portrait (single page) ---------------

  Widget _buildPortrait(Size slotSize) {
    final bool dragging =
        _direction != FlipDirection.none && _progress > 0;

    if (!dragging) {
      return Semantics(
        label: 'Page ${_currentIndex + 1} of ${widget.pages.length}',
        liveRegion: true,
        child: RepaintBoundary(
          key: _snapshotKey,
          child: SizedBox.expand(child: widget.pages[_currentIndex]),
        ),
      );
    }

    return _buildDragOverlay(slotSize, _currentIndex, _isLandscape);
  }

  // --------------- Landscape (two-page spread) ---------------

  Widget _buildLandscape(Size fullSize) {
    final int leftIndex = _currentIndex;
    final int rightIndex = _currentIndex + 1;
    final bool hasRight = rightIndex < widget.pages.length;
    final bool dragging =
        _direction != FlipDirection.none && _progress > 0;
    final Size slotSize = Size(fullSize.width / 2, fullSize.height);

    Widget leftSlot;
    Widget rightSlot;

    if (dragging && _activeSlotIsRight && hasRight) {
      // Right slot is being flipped.
      leftSlot = _idlePage(leftIndex, _snapshotKey);
      rightSlot = _buildDragOverlay(slotSize, rightIndex, true);
    } else if (dragging && !_activeSlotIsRight) {
      // Left slot is being flipped.
      leftSlot = _buildDragOverlay(slotSize, leftIndex, true);
      rightSlot = hasRight
          ? _idlePage(rightIndex, _snapshotKeyRight)
          : const SizedBox.expand();
    } else {
      // Idle.
      leftSlot = _idlePage(leftIndex, _snapshotKey);
      rightSlot = hasRight
          ? _idlePage(rightIndex, _snapshotKeyRight)
          : const SizedBox.expand();
    }

    return Row(
      children: [
        Expanded(child: leftSlot),
        Expanded(child: rightSlot),
      ],
    );
  }

  Widget _idlePage(int index, GlobalKey key) {
    return Semantics(
      label: 'Page ${index + 1} of ${widget.pages.length}',
      liveRegion: true,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.expand(child: widget.pages[index]),
      ),
    );
  }

  // --------------- Shared drag overlay ---------------

  Widget _buildDragOverlay(Size slotSize, int outgoingIndex, bool inSpread) {
    final ui.Image? snapshot = _outgoingSnapshot;
    if (snapshot == null) {
      return SizedBox.expand(child: widget.pages[outgoingIndex]);
    }

    final bool isForward = _direction == FlipDirection.forward;
    final int step = inSpread && _isLandscape ? 2 : 1;
    final int peekIndex = isForward
        ? outgoingIndex + step
        : outgoingIndex - step;
    final int safePeekIndex = peekIndex.clamp(0, widget.pages.length - 1);

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
        Positioned.fill(child: widget.pages[safePeekIndex]),
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
