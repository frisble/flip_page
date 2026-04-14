import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flip_page_controller.dart';
import 'gestures/flip_drag_recognizer.dart';
import 'layout/spread_layout.dart';
import 'rendering/flip_corner.dart';
import 'rendering/fold_geometry.dart';
import 'rendering/fold_painter.dart';

/// A page-turning widget with a drag-driven paper-curl animation.
///
/// Flips are initiated by dragging from any edge or corner. The anchor is the
/// nearest point on the slot perimeter to the drag-start position. The fold
/// follows the finger in real time (2-D tracking). Releasing past the halfway
/// threshold completes the flip; otherwise it reverts.
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
    this.edgeHitZoneFraction,
  });

  /// Ordered list of pages to display. May be empty.
  final List<Widget> pages;

  /// Optional controller for programmatic navigation.
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
  final Color backTintColor;

  /// Colour of the soft drop shadow drawn along the fold line.
  final Color shadowColor;

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

  // Drag / settle state.
  FlipDirection _direction = FlipDirection.none;
  Offset? _anchorOffset; // perimeter-clamped drag start point
  Offset? _pointer; // live finger position (slot-local)
  Offset? _settleFrom; // pointer snapshot at drag-end (settle start)
  Offset? _settleTo; // settle end (opposite point or anchor)
  ui.Image? _outgoingSnapshot;

  final GlobalKey _snapshotKey =
      GlobalKey(debugLabel: 'flip_page.snapshot');
  final GlobalKey _snapshotKeyRight =
      GlobalKey(debugLabel: 'flip_page.snapshot_r');
  bool _isLandscape = false;
  bool _activeSlotIsRight = true;
  Size _lastSlotSize = Size.zero;

  static const double _flingVelocityThreshold = 600;
  static const double _completeThreshold = 0.5;

  // ────────────── Lifecycle ──────────────

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

  // ────────────── Controller wiring ──────────────

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
    final bool forward = index > _currentIndex;
    final FlipDirection dir =
        forward ? FlipDirection.forward : FlipDirection.backward;
    final Size slotSize = _lastSlotSize;

    // Use a default corner anchor for controller-driven animations.
    final FlipCorner corner =
        forward ? FlipCorner.bottomRight : FlipCorner.bottomLeft;
    final Offset anchor = corner.position(slotSize);
    final Offset target = _oppositePoint(anchor, slotSize);

    final ui.Image? snapshot = _captureSnapshot();

    setState(() {
      _direction = dir;
      _anchorOffset = anchor;
      _pointer = anchor;
      _settleFrom = anchor;
      _settleTo = target;
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

  // ────────────── Helpers ──────────────

  int _clampIndex(int i) {
    if (widget.pages.isEmpty) return 0;
    return i.clamp(0, widget.pages.length - 1);
  }

  /// Diametrically opposite point through the slot center.
  static Offset _oppositePoint(Offset anchor, Size slot) =>
      Offset(slot.width - anchor.dx, slot.height - anchor.dy);

  /// Clamp a point to the nearest location on the slot rectangle perimeter.
  static Offset _clampToPerimeter(Offset p, Size size) {
    final double dLeft = p.dx;
    final double dRight = size.width - p.dx;
    final double dTop = p.dy;
    final double dBottom = size.height - p.dy;
    final double minD = [dLeft, dRight, dTop, dBottom].reduce(math.min);
    if (minD == dLeft) {
      return Offset(0, p.dy.clamp(0, size.height));
    }
    if (minD == dRight) {
      return Offset(size.width, p.dy.clamp(0, size.height));
    }
    if (minD == dTop) {
      return Offset(p.dx.clamp(0, size.width), 0);
    }
    return Offset(p.dx.clamp(0, size.width), size.height);
  }

  /// Derive a scalar progress from the current pointer for threshold checks.
  double _deriveProgress(Size slotSize) {
    final Offset anchor = _anchorOffset ?? Offset.zero;
    final Offset ptr = _pointer ?? anchor;
    final double maxDist =
        (anchor - _oppositePoint(anchor, slotSize)).distance;
    if (maxDist < 1e-6) return 0;
    return ((ptr - anchor).distance / maxDist).clamp(0.0, 1.0);
  }

  // ────────────── Tick (settle animation) ──────────────

  void _onTick() {
    final Offset from = _settleFrom ?? _anchorOffset ?? Offset.zero;
    final Offset to = _settleTo ?? _anchorOffset ?? Offset.zero;
    setState(() {
      _pointer = Offset.lerp(from, to, _animController.value);
    });
  }

  // ────────────── Gesture handlers ──────────────

  void _onDragStart(DragStartDetails details) {
    if (widget.pages.length <= 1) return;
    if (_animController.isAnimating) _animController.stop();

    final Size? fullSize = context.size;
    if (fullSize == null) return;

    // Slot detection for landscape.
    final double localX = details.localPosition.dx;
    if (_isLandscape) {
      _activeSlotIsRight = localX >= fullSize.width / 2;
    } else {
      _activeSlotIsRight = true;
    }

    final Size slotSize = _isLandscape
        ? Size(fullSize.width / 2, fullSize.height)
        : fullSize;

    // Remap pointer to slot-local coords.
    final Offset slotLocal = _isLandscape && _activeSlotIsRight
        ? Offset(localX - fullSize.width / 2, details.localPosition.dy)
        : Offset(
            _isLandscape ? localX : details.localPosition.dx,
            details.localPosition.dy,
          );

    // Continuous anchor: nearest perimeter point.
    final Offset anchor = _clampToPerimeter(slotLocal, slotSize);

    // Direction from anchor horizontal position.
    final FlipDirection candidate;
    if (_isLandscape) {
      candidate = _activeSlotIsRight
          ? FlipDirection.forward
          : FlipDirection.backward;
    } else {
      candidate = anchor.dx >= slotSize.width / 2
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

    final GlobalKey captureKey =
        _isLandscape && _activeSlotIsRight ? _snapshotKeyRight : _snapshotKey;
    final ui.Image? snapshot = _captureSnapshotFrom(captureKey);

    setState(() {
      _direction = candidate;
      _anchorOffset = anchor;
      _pointer = slotLocal; // raw 2-D pointer
      _settleFrom = null;
      _settleTo = null;
      _outgoingSnapshot?.dispose();
      _outgoingSnapshot = snapshot;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_direction == FlipDirection.none || _anchorOffset == null) return;
    final Size? fullSize = context.size;
    if (fullSize == null) return;

    // Remap to slot-local coords.
    final double localX = details.localPosition.dx;
    final Offset slotLocal = _isLandscape && _activeSlotIsRight
        ? Offset(localX - fullSize.width / 2, details.localPosition.dy)
        : Offset(
            _isLandscape ? localX : details.localPosition.dx,
            details.localPosition.dy,
          );

    setState(() => _pointer = slotLocal);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_direction == FlipDirection.none || _anchorOffset == null) return;
    final Size? fullSize = context.size;
    if (fullSize == null) return;

    final Size slotSize = _isLandscape
        ? Size(fullSize.width / 2, fullSize.height)
        : fullSize;

    final double progress = _deriveProgress(slotSize);
    final double velocity = details.velocity.pixelsPerSecond.dx;
    final int sign = _direction == FlipDirection.forward ? -1 : 1;
    final double signedVelocity = sign * velocity;
    final bool shouldComplete =
        progress >= _completeThreshold ||
        signedVelocity >= _flingVelocityThreshold;

    final Offset from = _pointer ?? _anchorOffset!;
    final Offset to = shouldComplete
        ? _oppositePoint(_anchorOffset!, slotSize)
        : _anchorOffset!;

    _settleFrom = from;
    _settleTo = to;
    _animController.value = 0;
    _animController
        .animateTo(
      1.0,
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

  // ────────────── Settle ──────────────

  void _settleComplete({int? targetIndex}) {
    final int step = _isLandscape ? 2 : 1;
    final int newIndex = targetIndex ??
        (_currentIndex +
            (_direction == FlipDirection.forward ? step : -step));
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
    _direction = FlipDirection.none;
    _anchorOffset = null;
    _pointer = null;
    _settleFrom = null;
    _settleTo = null;
    _outgoingSnapshot?.dispose();
    _outgoingSnapshot = null;
  }

  // ────────────── Snapshot ──────────────

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

  // ────────────── Build ──────────────

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
        _lastSlotSize = _isLandscape
            ? Size(slotWidth, constraints.biggest.height)
            : constraints.biggest;
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

  // ────────────── Portrait ──────────────

  bool get _isDragging =>
      _direction != FlipDirection.none &&
      _anchorOffset != null &&
      _pointer != null &&
      _pointer != _anchorOffset;

  Widget _buildPortrait(Size slotSize) {
    if (!_isDragging) {
      return _idlePage(_currentIndex, _snapshotKey);
    }
    return _buildDragOverlay(slotSize, _currentIndex);
  }

  // ────────────── Landscape ──────────────

  Widget _buildLandscape(Size fullSize) {
    final int leftIndex = _currentIndex;
    final int rightIndex = _currentIndex + 1;
    final bool hasRight = rightIndex < widget.pages.length;
    final Size slotSize = Size(fullSize.width / 2, fullSize.height);

    Widget leftSlot;
    Widget rightSlot;

    if (_isDragging && _activeSlotIsRight && hasRight) {
      leftSlot = _idlePage(leftIndex, _snapshotKey);
      rightSlot = _buildDragOverlay(slotSize, rightIndex);
    } else if (_isDragging && !_activeSlotIsRight) {
      leftSlot = _buildDragOverlay(slotSize, leftIndex);
      rightSlot = hasRight
          ? _idlePage(rightIndex, _snapshotKeyRight)
          : const SizedBox.expand();
    } else {
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

  // ────────────── Drag overlay ──────────────

  Widget _buildDragOverlay(Size slotSize, int outgoingIndex) {
    final ui.Image? snapshot = _outgoingSnapshot;
    if (snapshot == null) {
      return SizedBox.expand(child: widget.pages[outgoingIndex]);
    }

    final bool isForward = _direction == FlipDirection.forward;
    final int step = _isLandscape ? 2 : 1;
    final int peekIndex = isForward
        ? outgoingIndex + step
        : outgoingIndex - step;
    final int safePeekIndex = peekIndex.clamp(0, widget.pages.length - 1);

    final FoldGeometry geometry = FoldGeometry(
      slotSize: slotSize,
      anchor: _anchorOffset!,
      pointer: _pointer!,
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
}
