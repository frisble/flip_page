import 'package:flutter/gestures.dart';

/// Custom horizontal-drag recognizer with edge-hit-zone gating.
///
/// Only enters the gesture arena when the pointer-down occurs within the
/// outer [edgeHitZoneFraction] of the slot width on either side. Pointers
/// outside that zone are silently rejected so child recognizers (buttons,
/// scrollables) can claim them without competition.
class FlipDragRecognizer extends OneSequenceGestureRecognizer {
  FlipDragRecognizer({
    super.supportedDevices,
    this.edgeHitZoneFraction = 0.4,
    this.slotWidth = double.infinity,
  }) : super(allowedButtonsFilter: _defaultButtonAcceptBehavior);

  static bool _defaultButtonAcceptBehavior(int buttons) =>
      buttons == kPrimaryButton;

  /// Fraction of the slot width on each side that is sensitive to flip drags.
  ///
  /// `0.4` means the outer 40% on the left and the outer 40% on the right
  /// are hot zones — leaving a 20% dead-zone in the centre.
  double edgeHitZoneFraction;

  /// Current slot width. Updated by the widget factory on each build.
  double slotWidth;

  GestureDragStartCallback? onStart;
  GestureDragUpdateCallback? onUpdate;
  GestureDragEndCallback? onEnd;
  GestureDragCancelCallback? onCancel;

  @override
  String get debugDescription => 'flip drag';

  int? _pointer;
  bool _accepted = false;
  Offset? _initialGlobalPosition;
  Offset? _initialLocalPosition;
  int? _initialButtons;
  VelocityTracker? _velocityTracker;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_pointer != null) return true;
    if (!super.isPointerAllowed(event)) return false;
    if (slotWidth <= 0 || slotWidth.isInfinite) return true;
    final double x = _slotLocalX(event.localPosition.dx);
    final double edgeWidth = slotWidth * edgeHitZoneFraction.clamp(0.0, 0.5);
    return x <= edgeWidth || x >= slotWidth - edgeWidth;
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    if (_pointer != null) return true;
    if (!super.isPointerPanZoomAllowed(event)) return false;
    if (slotWidth <= 0 || slotWidth.isInfinite) return true;
    final double x = _slotLocalX(event.localPosition.dx);
    final double edgeWidth = slotWidth * edgeHitZoneFraction.clamp(0.0, 0.5);
    return x <= edgeWidth || x >= slotWidth - edgeWidth;
  }

  double _slotLocalX(double x) {
    if (x < 0) return x;
    return x % slotWidth;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }

    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _accepted = false;
    _initialGlobalPosition = event.position;
    _initialLocalPosition = event.localPosition;
    _initialButtons = event.buttons;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    if (_pointer != null) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }

    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _accepted = false;
    _initialGlobalPosition = event.position;
    _initialLocalPosition = event.localPosition;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, Offset.zero);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;

    if (event is PointerMoveEvent) {
      if (event.buttons != _initialButtons) {
        _rejectPointer(event.pointer);
        return;
      }
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      if (!_accepted) {
        final Offset moved = event.position - _initialGlobalPosition!;
        final double dx = moved.dx.abs();
        final double dy = moved.dy.abs();
        if (dy > kTouchSlop && dy > dx) {
          _rejectPointer(event.pointer);
          return;
        }
        if (dx >= kTouchSlop && dx > dy) {
          resolve(GestureDisposition.accepted);
        }
      }
      if (_accepted) {
        onUpdate?.call(
          DragUpdateDetails(
            sourceTimeStamp: event.timeStamp,
            delta: Offset(event.delta.dx, 0),
            primaryDelta: event.delta.dx,
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        );
      }
      return;
    }

    if (event is PointerPanZoomUpdateEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.pan);
      final Offset position = event.position + event.pan;
      final Offset localPosition = event.localPosition + event.localPan;

      if (!_accepted) {
        final double dx = event.pan.dx.abs();
        final double dy = event.pan.dy.abs();
        if (dy > kTouchSlop && dy > dx) {
          _rejectPointer(event.pointer);
          return;
        }
        if (dx >= kTouchSlop && dx > dy) {
          resolve(GestureDisposition.accepted);
        }
      }
      if (_accepted) {
        onUpdate?.call(
          DragUpdateDetails(
            sourceTimeStamp: event.timeStamp,
            delta: Offset(event.panDelta.dx, 0),
            primaryDelta: event.panDelta.dx,
            globalPosition: position,
            localPosition: localPosition,
          ),
        );
      }
      return;
    }

    if (event is PointerUpEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      if (_accepted) {
        final Velocity trackedVelocity =
            _velocityTracker?.getVelocity() ?? Velocity.zero;
        final Velocity velocity = Velocity(
          pixelsPerSecond: Offset(trackedVelocity.pixelsPerSecond.dx, 0),
        );
        onEnd?.call(
          DragEndDetails(
            velocity: velocity,
            primaryVelocity: velocity.pixelsPerSecond.dx,
          ),
        );
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _reset();
      return;
    }

    if (event is PointerPanZoomEndEvent) {
      if (_accepted) {
        final Velocity trackedVelocity =
            _velocityTracker?.getVelocity() ?? Velocity.zero;
        final Velocity velocity = Velocity(
          pixelsPerSecond: Offset(trackedVelocity.pixelsPerSecond.dx, 0),
        );
        onEnd?.call(
          DragEndDetails(
            velocity: velocity,
            primaryVelocity: velocity.pixelsPerSecond.dx,
          ),
        );
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _reset();
      return;
    }

    if (event is PointerCancelEvent) {
      if (_accepted) {
        onCancel?.call();
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      _reset();
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _accepted) return;
    _accepted = true;
    onStart?.call(
      DragStartDetails(
        globalPosition: _initialGlobalPosition!,
        localPosition: _initialLocalPosition,
      ),
    );
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    if (_accepted) onCancel?.call();
    stopTrackingPointer(pointer);
    _reset();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  void _rejectPointer(int pointer) {
    if (_accepted) onCancel?.call();
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
    _reset();
  }

  void _reset() {
    _pointer = null;
    _accepted = false;
    _initialGlobalPosition = null;
    _initialLocalPosition = null;
    _initialButtons = null;
    _velocityTracker = null;
  }
}
