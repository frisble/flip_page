# Phase 1 Data Model: Core FlipPage Widget

**Feature**: 001-core-widget · **Date**: 2026-04-14

This package has no persistent or network data. "Data model" here captures the **runtime state** — public widget config, public controller, private widget state, internal value objects. Public API surface is formally defined in [contracts/public-api.md](./contracts/public-api.md).

---

## Public types

### `FlipPage` (widget, `StatefulWidget`)

Immutable configuration.

| Field | Type | Validation / default |
|---|---|---|
| `pages` | `List<Widget>` | non-null; `length >= 0` (zero allowed — renders empty) |
| `controller` | `FlipPageController?` | optional; if null, widget creates & owns an internal one |
| `onPageChanged` | `ValueChanged<int>?` | optional |
| `initialPage` | `int` | clamped to `[0, pages.length - 1]` at `initState` (or 0 if empty) |
| `animationDuration` | `Duration` | `>= Duration.zero`; `Duration.zero` ⇒ controller settles instantly |
| `animationCurve` | `Curve` | non-null |
| `edgeHitZoneFraction` | `double?` | `0 < f <= 1` when provided; default `0.4` |
| `flipCornerFraction` | `double` | `0 <= f <= 1`; default `0.5` (top/bottom corner split per R11) |
| `backTintColor` | `Color` | non-null; default `Color(0x66000000)` (R12) |
| `shadowColor` | `Color` | non-null; default `Color(0x33000000)` |

Relationships: attaches to (or owns) a `FlipPageController`; manages a private `_FlipPageState`.

### `FlipPageController` (public, `ChangeNotifier`)

| Field | Type | Notes |
|---|---|---|
| `_currentPage` | `int` | private; exposed via `currentPage` getter |
| `_attached` | `bool` | true when bound to a live `_FlipPageState` |
| `_pageCount` | `int` | synced from the widget on attach / `didUpdateWidget` |
| `_animationHook` | `Future<void> Function(int)?` | injected by the state to drive animated transitions |

**Operations** (all reject silently when not attached):

- `currentPage` → `int`
- `hasClients` → `bool`
- `jumpTo(int index)` — validates `0 <= index < pageCount`; if valid, updates `_currentPage`, notifies, swaps widget page (no animation)
- `animateTo(int index)` — validates; defers to `_animationHook`
- `next()` — `animateTo(currentPage + 1)` if in range, else no-op
- `previous()` — `animateTo(currentPage - 1)` if in range, else no-op

**State transitions**:

```text
detached ──attach(state, pageCount)──▶ attached
attached ──detach()────────────────▶ detached
attached ──jumpTo(valid)───────────▶ attached (currentPage updated, notify, onPageChanged)
attached ──animateTo(valid)────────▶ attached (hook awaited, then updated, notify, onPageChanged)
attached ──any op with invalid idx─▶ attached (no-op, no notify, no callback)
```

---

## Private types (internal to `lib/src/`)

### `_FlipPageState` (`State<FlipPage> with SingleTickerProviderStateMixin`)

Transient runtime state during a flip.

| Field | Type | Notes |
|---|---|---|
| `_animationController` | `AnimationController` | drives settle animation |
| `_currentIndex` | `int` | index of the page currently shown (or the left slot in landscape) |
| `_progress` | `double` | curl progress, `[0.0, 1.0]`. `0` = idle; `1` = flip fully completed |
| `_direction` | `FlipDirection` | `none` / `forward` / `backward` |
| `_anchor` | `FlipCorner?` | the drag-anchor corner, null when idle |
| `_pointer` | `Offset?` | current pointer position in slot-local coords, null when idle |
| `_foldGeometry` | `FoldGeometry?` | derived from `_anchor` + `_pointer` each frame while dragging |
| `_outgoingSnapshot` | `ui.Image?` | captured at drag-start via `toImageSync`; released when `_progress == 0` |
| `_snapshotKey` | `GlobalKey` | attached to the `RepaintBoundary` wrapping the idle current page |
| `_effectiveController` | `FlipPageController` | `widget.controller ?? _ownedController` |
| `_activeSlot` | `SpreadSlot` | in landscape only: which slot the current drag began in |

**Invariants**:

1. `_progress == 0` ⇔ idle ⇔ `_anchor == null` ⇔ `_pointer == null` ⇔ `_outgoingSnapshot == null`.
2. During a drag: `_progress > 0` AND `_animationController.isAnimating == false`.
3. During settle: `_animationController.isAnimating == true` AND no pointer down.
4. `onPageChanged` fires **exactly once** per settled transition, **after** `_currentIndex` is updated.
5. Single emission site: `_emitSettled(int newIndex)` is the only method that calls `widget.onPageChanged` and `SemanticsService.announce`.

### `FoldGeometry` (internal value object, `@immutable`) — per [research.md R1](./research.md#r1--curl-rendering-strategy)

Inputs:

| Field | Type |
|---|---|
| `slotSize` | `Size` |
| `anchor` | `FlipCorner` |
| `pointer` | `Offset` (slot-local, clamped to the valid half-plane) |

Derived (lazy getters):

| Field | Type | Description |
|---|---|---|
| `anchorPosition` | `Offset` | corner coord in slot-local space |
| `foldLine` | `({Offset a, Offset b})?` | perpendicular bisector of `(anchorPosition, pointer)`, or `null` when pointer equals anchor |
| `reflectionMatrix` | `Matrix4` | 2-D reflection across `foldLine`, embedded in 4×4 |
| `unfoldedRegion` | `Path` | slot rect clipped to the pointer-side half-plane of `foldLine` |
| `foldedPolygon` | `Path` | slot rect clipped to the anchor-side half-plane |
| `reflectedFoldedPolygon` | `Path` | `foldedPolygon` transformed by `reflectionMatrix` |
| `shadowPath` | `Path` | thin band along `foldLine`, clipped to `unfoldedRegion` |
| `progress` | `double` | `(anchorPosition - pointer).distance / slot.diagonal`, clamped `[0, 1]` |

**Invariants**:

1. Identity: `pointer == anchorPosition` ⇒ `foldLine` is null, `unfoldedRegion` = full slot rect, `foldedPolygon` / `reflectedFoldedPolygon` / `shadowPath` are empty.
2. Pointer-clamping is the caller's responsibility; `FoldGeometry` doesn't clamp.
3. `reflectionMatrix` applied to `anchorPosition` equals `pointer` up to floating-point epsilon.
4. `unfoldedRegion ∪ foldedPolygon` equals the slot rect (within tolerance); `∩` has zero area.
5. 100% unit-testable — every field is a pure function of the three inputs.

### `FoldPainter` (internal, `CustomPainter`) — per [research.md R1](./research.md#r1--curl-rendering-strategy) and [R12](./research.md#r12--shadow-and-back-of-paper-treatment)

| Field | Type |
|---|---|
| `snapshot` | `ui.Image` — outgoing page, captured at drag start |
| `geometry` | `FoldGeometry` |
| `backTintColor` | `Color` |
| `shadowColor` | `Color` |
| `shadowSigma` | `double` — blur sigma (default 8) |

`paint(Canvas canvas, Size size)` draws in order: unfolded layer (image rect clipped to `geometry.unfoldedRegion`), peeled layer (image rect transformed by `geometry.reflectionMatrix`, clipped to `geometry.reflectedFoldedPolygon`, tinted via `ColorFilter`), shadow path.

`shouldRepaint` returns `true` iff `geometry` differs from `oldDelegate.geometry` (or any paint option changed).

---

## Enums

```dart
/// Flip direction during a drag / settle.
enum FlipDirection { none, forward, backward }

/// Which corner of the slot is the drag anchor (R11).
enum FlipCorner { topLeft, topRight, bottomRight, bottomLeft }

/// Layout mode decided by SpreadLayout.resolve (R5). Internal-only.
enum SpreadMode { portrait, landscape }

/// In landscape, which slot the current drag began in.
/// Internal to _FlipPageState, used when advancing the spread.
enum SpreadSlot { none, left, right }
```

---

## No persistence / no schema

The library is stateless across app launches. No storage contract. Caller owns `initialPage` persistence if desired.
