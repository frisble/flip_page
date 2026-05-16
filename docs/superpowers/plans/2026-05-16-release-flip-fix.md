# Release Flip Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `FlipPage` turn pages in Flutter `--release` builds while removing the premature `0.1.1` touch-slop API change.

**Architecture:** Roll back the public touch-slop surface, replace the recognizer internals with explicit flip-drag arena handling, and remove debug-only snapshot gating. Keep the `FlipPage` API stable and verify behavior from package tests plus the package `example/` app.

**Tech Stack:** Dart 3.11.4, Flutter 3.41.6 via FVM, Flutter SDK gesture/rendering APIs only.

---

## File Map

- Modify `pubspec.yaml`: restore package version from `0.1.1` to `0.1.0` until a real fix version is chosen.
- Modify `CHANGELOG.md`: remove the invalid `0.1.1` entry.
- Modify `lib/src/flip_page_widget.dart`: remove `FlipPage.touchSlop`, stop passing touch slop to the recognizer, and remove `debugNeedsPaint` from snapshot capture.
- Replace internals in `lib/src/gestures/flip_drag_recognizer.dart`: keep the same class name and public `edgeHitZoneFraction` / `slotWidth` fields, but implement arena claiming explicitly with `OneSequenceGestureRecognizer`.
- Modify `test/widget/gesture_flip_test.dart`: keep existing gesture behavior covered and add a regression test for short release-style edge movement.
- Modify `test/widget/interactive_child_test.dart`: preserve central dead-zone, button, and vertical-scroll behavior after the recognizer rewrite.
- Add `test/widget/snapshot_fallback_test.dart`: prove a missing snapshot does not block page settling.

## Task 1: Roll Back the Premature 0.1.1 API Change

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `lib/src/flip_page_widget.dart`
- Modify: `lib/src/gestures/flip_drag_recognizer.dart`

- [ ] **Step 1: Restore package version and changelog**

Edit `pubspec.yaml`:

```yaml
name: flip_page
description: Realistic page-flip widget for Flutter with physics-based curl animation and full widget interactivity.
version: 0.1.0
homepage: https://github.com/frisble/flip_page
repository: https://github.com/frisble/flip_page
issue_tracker: https://github.com/frisble/flip_page/issues
```

Edit the top of `CHANGELOG.md` so it starts with:

```markdown
## 0.1.0

- Paper-curl page-flip animation with fold line, reflected back-of-page tint, and drop shadow.
- 4-corner drag anchor selection based on pointer quadrant at drag start.
- Interactive child support: buttons, scrollables, and form inputs work inside pages.
- Edge-hit-zone gesture arbitration via custom `HorizontalDragGestureRecognizer`.
- `FlipPageController` for programmatic navigation (`jumpTo`, `animateTo`, `next`, `previous`).
- `onPageChanged` callback fires exactly once per settled transition.
- Basic accessibility: `Semantics` wrapping, `SemanticsService.sendAnnouncement` on page change.
- Zero runtime dependencies; works on iOS, Android, Web, macOS, Windows, Linux.
```

- [ ] **Step 2: Remove the public `touchSlop` parameter**

In `lib/src/flip_page_widget.dart`, make the constructor end like this:

```dart
    this.animationCurve = Curves.easeOutCubic,
    this.backTintColor = const Color(0x66000000),
    this.shadowColor = const Color(0x33000000),
    this.edgeHitZoneFraction,
  });
```

Remove this field and its docs entirely:

```dart
  final double? touchSlop;
```

In the `GestureRecognizerFactoryWithHandlers<FlipDragRecognizer>` builder, keep only:

```dart
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
```

- [ ] **Step 3: Remove touch-slop customization from the recognizer**

In `lib/src/gestures/flip_drag_recognizer.dart`, delete:

```dart
const double kFlipPageDefaultTouchSlop = 6.0;
```

Also delete `_touchSlop`, `touchSlop`, and all `DeviceGestureSettings(touchSlop: ...)` usage.

- [ ] **Step 4: Run focused static check**

Run:

```bash
fvm flutter analyze
```

Expected: no references to `touchSlop` or `kFlipPageDefaultTouchSlop` remain. If analyze fails only because the recognizer is still mid-refactor, continue to Task 2 before fixing final analyzer output.

- [ ] **Step 5: Commit rollback**

```bash
git add pubspec.yaml CHANGELOG.md lib/src/flip_page_widget.dart lib/src/gestures/flip_drag_recognizer.dart
git commit -m "fix: remove premature touch slop api"
```

## Task 2: Make Flip Drag Arena Claiming Explicit

**Files:**
- Modify: `lib/src/gestures/flip_drag_recognizer.dart`
- Test: `test/widget/gesture_flip_test.dart`
- Test: `test/widget/interactive_child_test.dart`

- [ ] **Step 1: Replace recognizer implementation**

Replace `lib/src/gestures/flip_drag_recognizer.dart` with:

```dart
import 'package:flutter/gestures.dart';

/// Custom horizontal drag recognizer with edge-hit-zone gating.
///
/// The recognizer enters the arena only for pointer-down events that start in
/// an edge zone, then explicitly accepts once horizontal movement dominates.
/// This keeps child taps and vertical scrollables usable while avoiding
/// runtime differences hidden by debug-only gesture behavior.
class FlipDragRecognizer extends OneSequenceGestureRecognizer {
  FlipDragRecognizer({
    super.debugOwner,
    super.supportedDevices,
    this.edgeHitZoneFraction = 0.4,
    this.slotWidth = double.infinity,
  });

  /// Fraction of the slot width on each side that is sensitive to flip drags.
  ///
  /// `0.4` means the outer 40% on the left and the outer 40% on the right
  /// are hot zones, leaving a 20% dead-zone in the centre.
  double edgeHitZoneFraction;

  /// Current slot width. Updated by the widget factory on each build.
  double slotWidth;

  GestureDragStartCallback? onStart;
  GestureDragUpdateCallback? onUpdate;
  GestureDragEndCallback? onEnd;
  GestureDragCancelCallback? onCancel;

  int? _pointer;
  Offset? _initialGlobalPosition;
  Offset? _initialLocalPosition;
  Offset? _lastGlobalPosition;
  Offset? _lastLocalPosition;
  VelocityTracker? _velocityTracker;
  bool _accepted = false;

  static const double _claimSlop = kTouchSlop;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (!super.isPointerAllowed(event)) return false;
    if (slotWidth <= 0 || slotWidth.isInfinite) return true;

    final double edgeWidth =
        slotWidth * edgeHitZoneFraction.clamp(0.0, 0.5);
    final double x = event.localPosition.dx;
    return x <= edgeWidth || x >= slotWidth - edgeWidth;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      resolve(GestureDisposition.rejected);
      return;
    }

    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _initialGlobalPosition = event.position;
    _initialLocalPosition = event.localPosition;
    _lastGlobalPosition = event.position;
    _lastLocalPosition = event.localPosition;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _accepted = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;

    if (event is PointerMoveEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);

      if (!_accepted) {
        final Offset initial =
            _initialGlobalPosition ?? event.position;
        final Offset delta = event.position - initial;
        final double absDx = delta.dx.abs();
        final double absDy = delta.dy.abs();

        if (absDy > _claimSlop && absDy > absDx) {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);
          _reset();
          return;
        }

        if (absDx < _claimSlop || absDx < absDy) {
          return;
        }

        resolve(GestureDisposition.accepted);
      }

      if (_accepted) {
        final Offset lastGlobal =
            _lastGlobalPosition ?? event.position;
        final Offset delta = event.position - lastGlobal;

        _lastGlobalPosition = event.position;
        _lastLocalPosition = event.localPosition;

        onUpdate?.call(DragUpdateDetails(
          sourceTimeStamp: event.timeStamp,
          delta: delta,
          primaryDelta: delta.dx,
          globalPosition: event.position,
          localPosition: event.localPosition,
        ));

      }
    } else if (event is PointerUpEvent) {
      if (_accepted) {
        final Velocity velocity =
            _velocityTracker?.getVelocity() ?? Velocity.zero;
        onEnd?.call(DragEndDetails(
          velocity: velocity,
          primaryVelocity: velocity.pixelsPerSecond.dx,
        ));
      }
      stopTrackingPointer(event.pointer);
      _reset();
    } else if (event is PointerCancelEvent) {
      if (_accepted) {
        onCancel?.call();
      }
      stopTrackingPointer(event.pointer);
      _reset();
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _accepted) return;
    _accepted = true;
    onStart?.call(DragStartDetails(
      globalPosition: _initialGlobalPosition ?? Offset.zero,
      localPosition: _initialLocalPosition,
    ));
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    if (_accepted) {
      onCancel?.call();
    }
    stopTrackingPointer(pointer);
    _reset();
  }

  @override
  String get debugDescription => 'flip drag';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  void _reset() {
    _pointer = null;
    _initialGlobalPosition = null;
    _initialLocalPosition = null;
    _lastGlobalPosition = null;
    _lastLocalPosition = null;
    _velocityTracker = null;
    _accepted = false;
  }
}
```

- [ ] **Step 2: Add a short edge drag regression test**

Append this test inside the `FlipPage gesture` group in `test/widget/gesture_flip_test.dart`:

```dart
    testWidgets('edge drag claims arena after horizontal movement',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_harness(
        pages: _threePages(),
        onPageChanged: (i) => changedTo = i,
      ));
      await tester.pumpAndSettle();

      final Finder flip = find.byType(FlipPage);
      final Offset center = tester.getCenter(flip);
      final Size size = tester.getSize(flip);
      final Offset start = Offset(center.dx + size.width * 0.35, center.dy);
      final TestGesture gesture = await tester.startGesture(start);

      await gesture.moveBy(const Offset(-24, 1));
      await tester.pump();
      await gesture.moveBy(Offset(-size.width * 0.55, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('B')), findsOneWidget);
      expect(changedTo, equals(1));
    });
```

- [ ] **Step 3: Run gesture and child-interaction tests**

Run:

```bash
fvm flutter test test/widget/gesture_flip_test.dart test/widget/interactive_child_test.dart
```

Expected: all tests pass. If the vertical scroll test fails, adjust the recognizer so vertical movement that exceeds `_claimSlop` and dominates `dx` rejects the flip gesture before `onStart`.

- [ ] **Step 4: Commit recognizer fix**

```bash
git add lib/src/gestures/flip_drag_recognizer.dart test/widget/gesture_flip_test.dart test/widget/interactive_child_test.dart
git commit -m "fix: claim flip drag arena explicitly"
```

## Task 3: Remove Debug-Only Snapshot Gating

**Files:**
- Modify: `lib/src/flip_page_widget.dart`
- Add: `test/widget/snapshot_fallback_test.dart`

- [ ] **Step 1: Remove `debugNeedsPaint` from snapshot capture**

Change `_captureSnapshotFrom()` in `lib/src/flip_page_widget.dart` to:

```dart
  ui.Image? _captureSnapshotFrom(GlobalKey key) {
    final RenderObject? ro = key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    try {
      return ro.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } on Object {
      return null;
    }
  }
```

- [ ] **Step 2: Add snapshot fallback test**

Create `test/widget/snapshot_fallback_test.dart`:

```dart
import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<Widget> pages,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: FlipPage(
          pages: pages,
          onPageChanged: onPageChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('drag can settle even when snapshot capture is unavailable',
      (tester) async {
    int? changedTo;
    await tester.pumpWidget(_harness(
      pages: const [
        SizedBox.expand(
          key: Key('A'),
          child: ColoredBox(color: Colors.red),
        ),
        SizedBox.expand(
          key: Key('B'),
          child: ColoredBox(color: Colors.blue),
        ),
      ],
      onPageChanged: (i) => changedTo = i,
    ));

    final Finder flip = find.byType(FlipPage);
    final Offset center = tester.getCenter(flip);
    final Size size = tester.getSize(flip);
    final Offset start = Offset(center.dx + size.width * 0.35, center.dy);

    final TestGesture gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(-size.width * 0.7, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('B')), findsOneWidget);
    expect(changedTo, equals(1));
  });
}
```

- [ ] **Step 3: Run snapshot-focused test**

Run:

```bash
fvm flutter test test/widget/snapshot_fallback_test.dart
```

Expected: PASS. This test is a behavioral guard; it verifies that the absence of a settled pre-drag pump does not block page settling.

- [ ] **Step 4: Commit snapshot fix**

```bash
git add lib/src/flip_page_widget.dart test/widget/snapshot_fallback_test.dart
git commit -m "fix: avoid debug snapshot gate"
```

## Task 4: Full Verification and Release Harness Check

**Files:**
- Read: `example/lib/main.dart`
- No code changes expected unless the example fails to build.

- [ ] **Step 1: Run full test suite**

Run:

```bash
fvm flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

Run:

```bash
fvm flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Validate package example in release mode**

From `example/`, run on a physical device:

```bash
fvm flutter run --release
```

Expected manual result:

- Dragging from the right or left edge turns the page.
- The page settles forward/backward after release.
- The button page still receives taps.
- The scrollable page still scrolls vertically.

- [ ] **Step 4: Record verification result**

If release verification passes, add a new top changelog section for the real fix:

```markdown
## 0.1.1

- Fix: page flips now work in Flutter release builds by making flip drag arena claiming release-safe.
- Fix: snapshot capture no longer depends on debug-only render state.
```

Keep `pubspec.yaml` at `0.1.0` until publishing is explicitly requested, or bump to `0.1.1` in the same commit only if the package is ready to be published immediately.

- [ ] **Step 5: Commit verification docs if changed**

If `CHANGELOG.md` was updated:

```bash
git add CHANGELOG.md
git commit -m "docs: document release flip fix"
```

## Self-Review

Spec coverage:

- Rollback of the previous touch-slop change is covered by Task 1.
- Gesture arena release-safety is covered by Task 2.
- Removal of `debugNeedsPaint` is covered by Task 3.
- Automated and manual release verification are covered by Task 4.

Placeholder scan:

- No `TBD`, `TODO`, or unspecified implementation steps remain.

Type consistency:

- `FlipDragRecognizer` keeps the same class name and callback names used by `RawGestureDetector`.
- `FlipPage` keeps `edgeHitZoneFraction` and removes only the unwanted `touchSlop`.
- Test commands use existing Flutter/FVM project commands.
