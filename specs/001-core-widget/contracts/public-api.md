# Phase 1 Contract: Public Dart API

**Feature**: 001-core-widget · **Date**: 2026-04-14

The contract for a Flutter library is its public Dart surface. Everything documented here is reachable from `package:flip_page/flip_page.dart`. Anything not listed here must live under `lib/src/` and remain unexported.

---

## Exports (`lib/flip_page.dart`)

```dart
library;

export 'src/flip_page_widget.dart' show FlipPage;
export 'src/flip_page_controller.dart' show FlipPageController;
```

No other exports. `FlipDirection`, `FlipCorner`, `SpreadMode`, `SpreadSlot`, `FoldGeometry`, `FoldPainter`, and the gesture recognizer are all internal.

---

## `class FlipPage extends StatefulWidget`

```dart
class FlipPage extends StatefulWidget {
  const FlipPage({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.initialPage = 0,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
    this.edgeHitZoneFraction,
    this.flipCornerFraction = 0.5,
    this.backTintColor = const Color(0x66000000),
    this.shadowColor = const Color(0x33000000),
  });

  final List<Widget> pages;
  final FlipPageController? controller;
  final ValueChanged<int>? onPageChanged;
  final int initialPage;
  final Duration animationDuration;
  final Curve animationCurve;
  final double? edgeHitZoneFraction;      // null ⇒ default 0.4
  final double flipCornerFraction;        // R11 top/bottom anchor split
  final Color backTintColor;              // R12 paper-back tint
  final Color shadowColor;                // R12 fold shadow color

  @override
  State<FlipPage> createState();
}
```

**Contract invariants**:

1. `pages.isEmpty` → widget renders an empty container sized to its incoming constraints; gestures disabled; never calls `onPageChanged`.
2. `controller == null` → widget owns an internal controller (created in `initState`, disposed in `dispose`).
3. `initialPage` is clamped to `[0, pages.length - 1]` at `initState`.
4. `pages.length` change via `didUpdateWidget`: if `currentPage >= newLength`, snap (no animation, no `onPageChanged`) to `newLength - 1` (or detach if empty).
5. `animationDuration == Duration.zero` → controller-driven settle completes instantly; drag tracking still updates `_progress` per frame.
6. Reads incoming `BoxConstraints` via `LayoutBuilder` — usable inside `Column`, `Row`, `Expanded`, `Dialog`, `Sheet` without forcing an intrinsic size.
7. `edgeHitZoneFraction ∈ (0, 1]` when provided; `flipCornerFraction ∈ [0, 1]`.

---

## `class FlipPageController extends ChangeNotifier`

```dart
class FlipPageController extends ChangeNotifier {
  FlipPageController({int initialPage = 0});

  int get currentPage;
  bool get hasClients;

  void jumpTo(int index);
  Future<void> animateTo(int index);
  Future<void> next();
  Future<void> previous();

  @override
  void dispose();
}
```

**Contract invariants**:

1. Detached (`hasClients == false`) → all navigation methods are silent no-ops.
2. `jumpTo(outOfRange)` → silent no-op, no notification.
3. `animateTo(int)`:
   - Valid AND different from `currentPage` → plays the curl settle from `_progress=0` to `_progress=1` over `widget.animationDuration`; updates `currentPage`; notifies listeners; fires `onPageChanged` **once**; resolves the returned `Future`.
   - Valid AND equal to `currentPage` → no-op, `Future` resolves immediately.
   - Invalid → no-op, `Future` resolves immediately.
4. `next()` / `previous()` → delegate to `animateTo(currentPage ± 1)` including the returned `Future`.
5. Disposing while an animation is in flight cancels the animation; must not throw.
6. Attaching a second live `FlipPage` to the same controller throws `FlutterError` in debug (mirrors `ScrollController`); in release, the second attach silently wins.

---

## Callback contract: `onPageChanged`

Typedef: `ValueChanged<int>` from `package:flutter/foundation.dart`.

**Semantics**:
- Fires **exactly once** per settled page change, **after** `currentPage` is updated.
- Does **not** fire for drags that revert (below threshold).
- Does **not** fire for rubber-banded drags at boundaries.
- Does **not** fire for `jumpTo` calls that are no-ops (out-of-range, same index).
- **Does** fire for `jumpTo` calls that successfully change the page (no animation, but callback still fires).
- Fires for `animateTo` / `next` / `previous` after the settle animation completes.
- Argument is the new `currentPage`, always in `[0, pages.length - 1]`.

---

## Semantics contract (a11y)

- Current visible page(s) wrapped in `Semantics(label: "Page ${i+1} of ${pages.length}", liveRegion: true)`.
- Non-visible pages wrapped in `ExcludeSemantics`.
- On settled change, `SemanticsService.announce("Page ${i+1}", TextDirection.ltr)`.
- `MediaQuery.disableAnimations == true`: controller transitions run with `Duration.zero`; drag tracking still updates `_progress` per frame so the user sees feedback that a drag is in progress.

---

## Platform contract

No branching on `defaultTargetPlatform` or `kIsWeb` in public paths. The widget compiles and runs identically on iOS, Android, Web, macOS, Windows, Linux. Any platform-specific behavior lives in the Flutter SDK (e.g., scrollbar sliding on desktop), not here.

---

## Versioning contract

- v0.1.x: breaking API changes allowed between minor versions (pre-1.0).
- From v1.0 onward: SemVer strict. Adding a new optional parameter with default = patch / minor; removing / renaming / reordering = major.
- This file is the source of truth. Any PR changing exported symbols must update it in the same commit.
