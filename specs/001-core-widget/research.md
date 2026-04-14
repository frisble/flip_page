# Phase 0 Research: Core FlipPage Widget

**Feature**: 001-core-widget · **Date**: 2026-04-14

Technical Context has **no open `NEEDS CLARIFICATION`** items. Research below captures best-practice decisions for each design surface so implementation does not re-litigate them.

---

## R1 — Curl rendering strategy

**Decision**: Three-layer canvas render during drag: (1) base layer = next page flat and live, (2) outgoing page clipped to the unfolded half-plane of the fold line, (3) peeled region = outgoing page reflected across the fold line, tinted darker, clipped to the folded polygon, with a soft drop shadow painted along the fold line. Widget-level `Stack` orchestrates the layers; layers 2 and 3 are drawn by a single `CustomPainter` operating on a `ui.Image` snapshot of the outgoing page.

**Math** (pure — no Flutter specifics):

- `C0`: original position of the drag-anchor corner (see R11).
- `P`: current pointer position (clamped to the half-plane in which a fold is geometrically valid).
- **Fold line** `F`: perpendicular bisector of segment `(C0, P)`. Every point on `F` is equidistant from `C0` and `P`.
- **Unfolded region**: intersection of the page rectangle with the half-plane on the `P` side of `F`.
- **Folded polygon**: intersection of the page rectangle with the half-plane on the `C0` side of `F`.
- **Reflection**: affine map `M_F` that reflects a point across `F`. Applying `M_F` to the folded polygon lays it on top of the unfolded region, with `C0` landing exactly at `P`.
- **Shadow**: a blurred path stroked along `F`, clipped to the unfolded region (shadow only under the peel, not beyond the page edge).

**Rendering layer order** (bottom to top):

1. `pages[nextIndex]` (or `pages[previousIndex]` for backward flip), flat and live — base.
2. `ClipPath(unfoldedRegion) → drawImageRect(snapshot)` — what remains flat of the outgoing page.
3. `ClipPath(reflectedFoldedPolygon) → drawImageRect(snapshot, transform: M_F, tint: backTintColor)` — the peeled back.
4. Shadow path (same `CustomPainter` as layer 3, painted last before returning).

**Rationale**:
- Reproduces the canonical turn.js UX (corner peel, visible paper back, drop shadow, next page showing through). This is what users are calibrated on; flat card-flip feels dated.
- Math is 5 lines of geometry (perpendicular bisector + 2-D line reflection). Pure Dart, 100% unit-testable, no dependencies, no platform branching.
- Operating on a `ui.Image` snapshot costs one blit per layer — one `toImageSync` per drag (not per frame), then cheap per-frame paint.
- Stays at Widget / CustomPaint level rather than custom `RenderBox`. The RenderBox path (used by `turnable_page`) would keep children live during the flip without snapshotting — worth revisiting in v0.2 if profiling on a real device shows the snapshot approach dropping frames under scroll-heavy child content.

**Alternatives considered**:
- *Mesh deformation* (`Canvas.drawVertices` with a subdivided grid, vertices on a cylindrical curl surface). Rejected for v0.1: more realistic soft-paper bend but ≈ 10× the math and ≈ 5× paint cost. Revisit v0.2.
- *Custom `RenderBox`* (the approach `turnable_page` takes). Rejected for v0.1 scope: keeps child widgets interactive during the flip without snapshotting but requires deep Flutter rendering knowledge and more code.
- *Fragment shader* (`FragmentProgram`). Rejected: Flutter Web shader support is still spotty across renderers — violates FR-013 ("no platform-specific paths").
- *Flat card-flip* (single `rotateY` around left edge, previously shipped MVP). Rejected after UX reference review — doesn't match the corner-peel visual expected by users.

**License note**: `turnable_page` by saeedahmed725 (proprietary, TPPL v1.0) was reviewed at the architecture level only. No code ported. Math here is public-domain line-reflection geometry. MedRedha's MIT `Flutter-Page-Flipper` is a flat card-flip and does not cover this case.

---

## R2 — Gesture recognition & arbitration

**Decision**: Subclass `HorizontalDragGestureRecognizer` as `FlipDragRecognizer`, registered via `RawGestureDetector` with a `GestureRecognizerFactoryWithHandlers`. Keep the base class's default `kTouchSlop` arena-deferral (so child taps win static taps); add an `edgeHitZoneFraction` override on `isPointerAllowed` to reject pointer-downs outside the outer `edgeHitZoneFraction` of the slot half facing the spine.

**Rationale**:
- `HorizontalDragGestureRecognizer` already handles multi-touch (first-pointer-wins), slop, and fling velocity.
- Deferring arena win to `kTouchSlop` is what descendants need: a `TapGestureRecognizer` inside a child button wins the tap because we haven't claimed the pointer yet. Satisfies FR-006 and US2.
- Edge-hit-zone gating prevents center-of-page drags from stealing gestures from vertical scrollables inside child content.

**Alternatives considered**:
- *Plain `GestureDetector` with `onHorizontalDragUpdate`*. Used briefly by the MVP; works for simple cases but can't gate on hit-zone and wins the arena eagerly on some platforms.
- *`Listener` widget + manual pointer tracking*. Would reimplement slop, velocity, arena cooperation for no benefit. Rejected.

---

## R3 — Preserving child interactivity during idle + drag

**Decision**: Two render modes:
1. **Idle / settled**: `pages[currentIndex]` rendered as a live `Widget` — full interactivity. Wrapped in a `RepaintBoundary` with a `GlobalKey` so its render object is snapshot-ready.
2. **During drag / settle animation**: outgoing page painted from a `ui.Image` snapshot captured via `(key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImageSync(pixelRatio: devicePixelRatio)`. Base layer (next / previous page) remains a live `Widget`.

**Rationale**:
- R1's reflection rendering operates on pixels, not on a widget subtree. A `Transform` with a reflection matrix on a live subtree would produce mirror-flipped child widgets, but clipping that to the folded polygon fights Flutter's render-order constraints (clip-then-transform vs transform-then-clip).
- FR-006 demands live taps when not flipping; snapshot only during the transient flip preserves idle interactivity.
- `toImageSync` is synchronous (Flutter ≥ 3.7) — no frame drop at drag-start.
- Keeping the next page live underneath means on settle-complete the user interacts with real widgets immediately; we just discard the snapshot and swap `currentIndex`.

**Alternatives considered**:
- *Always-live during drag*: incompatible with R1. Non-starter.
- *Always-snapshotted*: breaks idle interactivity. Non-starter.
- *Custom `RenderBox`*: avoids snapshot entirely by painting children directly into layers. Deferred to v0.2.

---

## R4 — Settle animation on release

**Decision**: Single `AnimationController` (duration `280 ms`, `Curves.easeOutCubic`) interpolating `_progress` from release value to `0.0` (revert) or `1.0` (complete). Cross the fling threshold by comparing `pointer.velocity.dx` (signed to match flip direction) against `600 px/s`.

**Rationale**:
- 280 ms / easeOutCubic matches Material motion spec for "large surface, user-initiated" transitions — feels snappy and native.
- Single controller avoids race conditions between revert and complete animations.

**Alternatives considered**:
- *Spring simulation (`SpringDescription`)*. More physical but harder to tune; no perceptible gain for a page-turn. Defer.
- *No animation on release* (snap). Looks broken.

---

## R5 — Portrait vs landscape two-page spread

**Decision**: `LayoutBuilder` at the top of `FlipPage.build` inspects `BoxConstraints`. If `maxWidth / maxHeight >= 1.2`, render landscape two-page spread (left slot = currentIndex, right slot = currentIndex + 1). Otherwise portrait single page. Threshold exposed via `SpreadLayout.landscapeThreshold` for testing; not publicly configurable in v0.1.

**Rationale**:
- Constraints-based branching (rather than `MediaQuery.orientation`) makes the widget work inside dialogs, sheets, and resizable desktop windows — not just fullscreen.
- 1.2 is where two portrait-proportion pages fit side-by-side with reasonable margins.

**Alternatives considered**:
- *`MediaQuery.orientation`*. Too coarse — breaks embedded usage.
- *Caller-forced `layoutMode` parameter*. Deferred to v0.2 as an optional override. v0.1 auto-detects.

---

## R6 — Boundary behavior (first / last page)

**Decision**: Rubber-band dampening — drag translation that would move past the boundary is scaled by `0.3` with a cubic falloff; animates back to `_progress = 0` on release. No page change ever occurs at boundaries. No haptic in v0.1 (keeps multi-platform parity — haptic APIs differ per platform).

**Rationale**: Matches iOS / macOS overscroll affordance users already understand. Pure math, no dependencies.

**Alternatives considered**:
- *Hard stop (drag clamped to 0)*. Feels broken.
- *Haptic at boundary*. Requires `HapticFeedback`; per-platform behavior differs. Deferred.

---

## R7 — Accessibility (basic, v0.1)

**Decision**:
- Wrap each visible page in `Semantics(label: "Page ${i+1} of ${pages.length}", liveRegion: true)`.
- Non-visible pages wrapped in `ExcludeSemantics`.
- On settled page change, call `SemanticsService.announce("Page ${i+1}", TextDirection.ltr)`.
- Respect `MediaQuery.disableAnimations`: controller-driven transitions run with `Duration.zero`; drag tracking still updates `_progress` in real time so the user sees feedback.

**Rationale**: Meets FR-014 without overreaching into v0.2 concerns (reduced-motion fine grain, custom focus order across a spread, content-level spoken descriptions).

**Alternatives considered**:
- *No semantics*. Fails FR-014.
- *Full focus traversal across spread pages*. Real work — defer to v0.2.

---

## R8 — Public API shape & naming

**Decision**:

```dart
class FlipPage extends StatefulWidget {
  const FlipPage({
    super.key,
    required List<Widget> pages,
    FlipPageController? controller,
    ValueChanged<int>? onPageChanged,
    int initialPage = 0,
    Duration animationDuration = const Duration(milliseconds: 280),
    Curve animationCurve = Curves.easeOutCubic,
    double? edgeHitZoneFraction,                    // default 0.4
    Color backTintColor = const Color(0x66000000),  // paper back (R12)
    Color shadowColor = const Color(0x33000000),
  });
}

class FlipPageController extends ChangeNotifier {
  FlipPageController({int initialPage = 0});
  int get currentPage;
  bool get hasClients;
  void jumpTo(int index);
  Future<void> animateTo(int index);
  Future<void> next();
  Future<void> previous();
}
```

**Rationale**: Names mirror `PageView` / `PageController` so existing Flutter users reach for the same muscle memory. Avoids prescriptive names like `BookWidget`. Explicit `FlipPageController` (not `FlipController`) for discoverability.

**Alternatives considered**:
- *`FlipBook` / `FlipBookController`*. Too prescriptive of the book-reader use case; carousels are valid.
- *Named constructors per mode* (`FlipPage.portrait`, `FlipPage.spread`). Rejected — auto-layout (R5) makes it unnecessary.

---

## R9 — Testing strategy

**Decision**:
- **Unit**: `fold_geometry_test.dart` (identity, reflection invariant, partition, progress monotonicity), `flip_corner_test.dart` (quadrant selection), `spread_layout_test.dart` (aspect-ratio threshold), `flip_page_controller_test.dart` (ChangeNotifier semantics, bounds, next/previous).
- **Widget**: one file per user story: `gesture_flip_test` (P1), `curl_render_test` (P1 visual contract), `interactive_child_test` (P2), `landscape_spread_test` (P2), `controller_test` (P3), `boundary_test` (polish).
- **Golden tests**: **excluded from v0.1**. Curl rendering differs subtly per renderer (Skia / Impeller / CanvasKit / html); cross-platform goldens cause CI false-positives. Add in v0.2 behind a single-platform filter.
- **Coverage gate**: ≥ 80% line coverage enforced in CI via `flutter test --coverage` + lcov threshold check.

**Rationale**: Hits SC-004 and FR-011. Perf claim (SC-002) verified manually on the example app, documented in `quickstart.md`.

**Alternatives considered**:
- *Include goldens*. CI-flaky across renderers. Defer.
- *Integration tests only*. Insufficient for controller unit logic.

---

## R10 — Publishing checklist (pre-1.0 but pub.dev-ready)

**Decision**: ship as `0.1.0` (pre-1.0 — breaking changes permitted) with:
- `pubspec.yaml` `homepage` / `repository` / `issue_tracker` filled once GitHub repo URL is known (tracked in CONVERSATION.md next steps).
- `example/` app builds on all 6 target platforms.
- `README.md` with usage snippet + demo GIF.
- `CHANGELOG.md` entry: "0.1.0 — initial public release".
- MIT `LICENSE` (already in place).
- Topic tags in `pubspec.yaml`: `widget`, `book`, `animation`, `page-turn` (already in place).

**Rationale**: hits SC-005 (pub-points ≥ 130) — platform coverage declared, valid license, example app, docs, no analyze issues.

**Alternatives considered**:
- *Ship as `1.0.0`*. Rejected — no external users yet; reserve SemVer commitment for after feedback.

---

## R11 — Drag-anchor selection *(revised — continuous edge anchor)*

**Decision**: At drag start, the anchor `C0` is the point on the slot rectangle perimeter **nearest** to `details.localPosition`. Any edge point or corner is valid — not just the 4 discrete corners. The anchor is locked at drag start and does not move.

**Nearest-perimeter algorithm**: project the pointer onto each of the 4 edges, pick the projection with the shortest distance. If the pointer is exactly on the perimeter, use it directly.

**Direction determination**: based on which half of the perimeter the anchor lands on:
- `anchor.dx >= slotWidth / 2` → forward (right-side anchor peels toward the left)
- `anchor.dx < slotWidth / 2` → backward (left-side anchor peels toward the right)

In landscape spread: the slot is the half-width slot, so the same rule applies per-slot. Right slot always → forward, left slot always → backward.

**Rationale**: Users should be able to initiate a peel from any point on any edge — top, bottom, right, left, or any corner. Restricting to 4 discrete corners felt rigid; the reference UX (physical books, turn.js) allows grabbing anywhere along the page edge. Continuous anchor is the natural extension.

**Alternatives considered**:
- *4 discrete corners from pointer quadrant* (previous R11). Shipped and worked, but user feedback: "I should be able to flip from all the main border points." Superseded.
- *Fixed anchor (always bottom-right)*. Rejected earlier — still rejected.

**Degenerate cases**:
- Pointer exactly at anchor after clamping: no fold → identity (idle render).
- Anchor at slot center (impossible — perimeter clamp guarantees an edge point).

---

## R13 — Live 2-D pointer tracking *(new)*

**Decision**: During the drag, `_FlipPageState` stores the raw `details.localPosition` (slot-local) as the pointer `P` each frame. `FoldGeometry` receives the actual 2-D pointer, not a 1-D progress scalar mapped to a diagonal. The fold tracks the finger continuously in both axes.

**Progress derivation**: a scalar `progress ∈ [0, 1]` is still derived from `(P - C0).distance / maxDistance` (where `maxDistance` is the distance from anchor to the diagonally-opposite point). This scalar is used **only** for the settle decision (threshold + velocity check), not for rendering.

**Settle animation**: on drag end, the `AnimationController` still drives a 0→1 scalar, but the rendering maps it to an `Offset` interpolation:
- **Complete**: `Offset.lerp(pointerAtRelease, targetOffset, t)` where `targetOffset = Offset(slotWidth - anchor.dx, slotHeight - anchor.dy)` (diametrically opposite anchor through the slot center).
- **Revert**: `Offset.lerp(pointerAtRelease, anchor, t)`.

This means the page "continues" from where the user released (not from a snapped position), and the settle path matches the user's drag trajectory.

**Rationale**: The previous 1-D progress model locked the fold to a single diagonal regardless of finger movement. Moving the finger sideways or back produced no visual change. Users expect the peel to follow the finger — enlarging when dragged further, shrinking when dragged back, changing angle when dragged sideways.

**Alternatives considered**:
- *1-D progress along the anchor diagonal* (previous approach). Shipped; insufficient per user feedback.
- *Pointer tracking with a spring model* (smooth out jitter). Interesting but adds complexity. Raw tracking is smooth enough at 60 fps. Defer.

---

## R12 — Shadow and back-of-paper treatment

**Decision**:
- **Shadow**: single path painted along fold line `F`, stroked with a wide soft-blurred paint (`MaskFilter.blur(BlurStyle.normal, 8)`, color = `shadowColor`), clipped to the unfolded region so it only appears under the peeled polygon.
- **Back of paper**: the reflected outgoing-page snapshot is drawn with `ColorFilter.mode(backTintColor, BlendMode.srcATop)`, simulating the "view-through-paper" look. Default `backTintColor = Color(0x66000000)` (semi-transparent black overlay). Both exposed as optional `FlipPage` params.

**Rationale**: Reference UX shows visible shadow and darker back; without them the peel looks flat and synthetic. Extra paint calls stay on the same `CustomPainter.paint` — no extra render passes.

**Alternatives considered**:
- *Physically accurate paper translucency* (second snapshot of the reverse page alpha-composited). Adds complexity and snapshot cost for marginal realism. Defer.
- *No shadow*. Looks like the page is floating.
