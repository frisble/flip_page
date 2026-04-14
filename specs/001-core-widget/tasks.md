---
description: "Task list for Core FlipPage Widget (v0.1)"
---

# Tasks: Core FlipPage Widget (v0.1)

**Input**: Design documents from `specs/001-core-widget/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/public-api.md](./contracts/public-api.md), [quickstart.md](./quickstart.md)

**Tests**: Included. SC-004 mandates ≥80% line coverage with unit + widget tests; tests for each story are written before implementation (TDD, per project coding rules).

**Organization**: Tasks grouped by user story (US1–US4) so each story can be implemented, tested, and demoed independently.

## Status at regeneration time (2026-04-14)

- Phase 1 (Setup) done from the earlier MVP pass.
- Phase 2 (Foundational) done: pure-math primitives and widget skeleton shipped.
- Phase 3 (US1): a flat card-flip MVP shipped and passes behavior tests, but the visual is wrong per user's UX reference GIF. This plan regenerates US1 as **paper-curl** from scratch per the revised [research.md R1](./research.md#r1--curl-rendering-strategy-revised). Existing gesture/animation/settle code is reusable; rendering internals (`CurlGeometry` → `FoldGeometry`, `Transform` → `CustomPaint` + snapshot) are rewritten.
- Existing widget tests for drag behavior (`test/widget/gesture_flip_test.dart`) assert page-change outcomes, not pixels — they continue to pass across the rewrite.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependencies on incomplete tasks).
- **[Story]**: `US1`/`US2`/`US3`/`US4`. Setup, Foundational, and Polish tasks have no story label.
- File paths are relative to the package root.

## Path Conventions

Flutter library package layout (from [plan.md](./plan.md#source-code-repository-root)):

- Public barrel: `lib/flip_page.dart`
- Internals: `lib/src/**`
- Tests: `test/unit/**`, `test/widget/**`, plus the scaffolded `test/flip_page_test.dart`
- Example app: `example/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Lock down lint/analysis, pub metadata, and the `lib/src/` layout before any code lands.

- [X] T001 Enable `strict-casts`, `strict-inference`, `strict-raw-types` in `analysis_options.yaml` (file: `analysis_options.yaml`). `public_member_api_docs` lint deferred to Polish phase T071.
- [X] T002 Add `topics: [widget, book, animation, page-turn]` to `pubspec.yaml`; leave `homepage`/`repository`/`issue_tracker` commented until the GitHub repo URL is known (file: `pubspec.yaml`).
- [X] T003 Trim scaffold `Calculator` from `lib/flip_page.dart`; declare `library;` and add barrel export for `FlipPage` (file: `lib/flip_page.dart`).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Pure-math primitives, layout resolver, widget skeleton. Every user story depends on these.

**⚠️ CRITICAL**: No user story work can begin until Phase 2 is complete.

- [X] T004 [P] `FlipDirection` enum (`none` / `forward` / `backward`) lives in `lib/src/rendering/curl_geometry.dart`. It will migrate to `lib/src/rendering/fold_geometry.dart` as part of T022. Any consumer must continue to import it from the library barrel once re-exported.
- [X] T005 [P] `SpreadLayout.resolve(BoxConstraints)` returning `SpreadMode` in `lib/src/layout/spread_layout.dart`, plus 6 unit tests in `test/unit/spread_layout_test.dart` (portrait below 1.2, landscape ≥ 1.2, unbounded/zero height, custom threshold).
- [X] T006 Public `FlipPage` widget in `lib/src/flip_page_widget.dart` with constructor: `pages`, `onPageChanged`, `initialPage`, `animationDuration`, `animationCurve`. `_FlipPageState` co-located (leading underscore, private).
- [X] T007 `_FlipPageState` lifecycle: `initState` clamps `initialPage`; `didUpdateWidget` re-clamps on `pages.length` change; `dispose` tears down the controller.
- [X] T008 `AnimationController` + settle-to-0/1 pipeline in `_FlipPageState`: distance threshold `0.5`, velocity threshold `600 px/s` (fling). `_settleComplete` updates index + fires `onPageChanged`; `_settleRevert` resets.
- [X] T009 `flutter analyze` clean; `test/flip_page_test.dart` smoke (render initial page; empty pages render without throwing) passes.

**Checkpoint**: Foundation ready. Widget renders a live `pages[currentIndex]` at idle; gesture → settle → page-change loop works end-to-end with a placeholder (card-flip) rendering.

---

## Phase 3: User Story 1 — Drag-to-flip with paper-curl animation (Priority: P1) 🎯 MVP

**Goal**: deliver the turn.js-style corner-peel flip: 4-corner drag anchor, fold-line clip + reflected peel showing the back of the page, drop shadow, next page revealed underneath. End users can flip forward and backward between two adjacent pages; releasing past threshold completes, below threshold reverts.

**Independent Test**: Launch example app with 5 solid-color pages. Drag from any of the 4 corners of the visible page. The corner peels, the fold line moves with the finger, a darker back is visible on the peeled triangle, a soft shadow sits under the peel, and the next/previous page shows through the peeled region. Release past 50% of diagonal → page changes. Release before → reverts.

### Tests for User Story 1 ⚠️

> **Write these tests FIRST, ensure they FAIL before implementation.**

- [X] T010 [P] [US1] Unit test: `FlipCorner.pickFromPointer` — 4 quadrants + centre default + custom cornerFraction + opposite + position + isRightSide — file: `test/unit/flip_corner_test.dart` (10 assertions)
- [X] T011 [P] [US1] Unit test: `FoldGeometry` identity case — foldLine null, unfoldedRegion = full rect — file: `test/unit/fold_geometry_test.dart`
- [X] T012 [P] [US1] Unit test: reflectionMatrix maps anchorPosition to pointer; reflection is involution — same file
- [X] T013 [P] [US1] Unit test: unfolded + folded bounds cover slot; folded contains anchor; unfolded contains opposite — same file
- [X] T014 [P] [US1] Unit test: progress monotonic in distance + clamped [0,1] — same file
- [X] T015 [P] [US1] Widget test: CustomPaint present during partial drag; base layer (pages[nextIndex]) findable underneath — file: `test/widget/curl_render_test.dart`
- [X] T016 [P] [US1] Widget test: right-edge drag past threshold flips forward — file: `test/widget/gesture_flip_test.dart` (already landed against card-flip; behavior must survive the curl rewrite)
- [X] T017 [P] [US1] Widget test: left-edge drag past threshold flips backward (already landed)
- [X] T018 [P] [US1] Widget test: below-threshold drag reverts (already landed)
- [X] T019 [P] [US1] Widget test: fling completes despite short distance (already landed)
- [X] T020 [P] [US1] Widget test: forward drag at last page does not change page (already landed)

### Implementation for User Story 1

- [X] T021 [US1] `FlipCorner` enum + `pickFromPointer` + `position` + `opposite` + `isRightSide` in `lib/src/rendering/flip_corner.dart`
- [X] T022 [US1] `FoldGeometry` value object in `lib/src/rendering/fold_geometry.dart` — `FlipDirection` enum moved here; `curl_geometry.dart` deleted. Sutherland-Hodgman single-plane clipping for unfoldedRegion / foldedPolygon; 2-D reflection matrix; shadow path; progress.
- [X] T023 [US1] Barrel export in `lib/flip_page.dart` unchanged — `FlipDirection` / `FlipCorner` stay internal as planned.
- [X] T024 [US1] Deleted `test/unit/curl_geometry_test.dart` (superseded).
- [X] T025 [US1] `FoldPainter extends CustomPainter` in `lib/src/rendering/fold_painter.dart` — draws 3 layers + shadow; `shouldRepaint` based on snapshot/geometry/color identity.
- [X] T026 [US1] `RepaintBoundary(key: _snapshotKey)` wraps idle `pages[_currentIndex]` in `lib/src/flip_page_widget.dart`.
- [X] T027 [US1] `_captureSnapshot()` in `_onDragStart` via `toImageSync(pixelRatio:)`; `FlipCorner.pickFromPointer` selects anchor.
- [X] T028 [US1] `_buildContent` replaces old `_buildPortrait` — `Stack([pages[peekIndex], CustomPaint(FoldPainter(...))])` during drag; `RepaintBoundary(pages[currentIndex])` at idle.
- [X] T029 [US1] `Offset.lerp(anchorPos, oppositePos, _progress)` computes pointer along diagonal; `FoldGeometry` constructed per frame.
- [X] T030 [US1] `_resetDragState()` disposes `ui.Image` snapshot; called from `_settleComplete` / `_settleRevert` / `didUpdateWidget` / `dispose`.
- [X] T031 [US1] `backTintColor`, `shadowColor`, `flipCornerFraction` added to `FlipPage` constructor. `contracts/public-api.md` already reflects these in the regenerated plan.
- [X] T032 [US1] `flutter test` — 35/35 passing (10 flip-corner + 9 fold-geometry + 6 spread-layout + 5 gesture + 1 curl-render + 2 smoke + 2 baseline).
- [X] T033 [US1] `flutter analyze` — zero issues.

**Checkpoint**: paper-curl flip is visible. The reference UX is reproduced. US1 is demoable end-to-end (once `example/` is scaffolded in Polish).

---

## Phase 4: User Story 2 — Interactive page content (Priority: P2)

**Goal**: Interactive widgets inside pages (buttons, scrollables, form inputs) receive their own taps and scrolls. Flip gestures activate only on an intentional horizontal drag from an edge hit-zone.

**Independent Test**: Place an `ElevatedButton` on page 0 and a vertical `ListView` on page 1. Tap button → fires `onPressed`, no flip. Vertical scroll on list → list scrolls, no flip. Horizontal drag on either page → flip starts, child tap does not fire. Horizontal drag in the central non-hit-zone → no flip.

### Tests for User Story 2 ⚠️

- [ ] T034 [P] [US2] Widget test: `ElevatedButton` on a page fires `onPressed` on a direct tap; no page change — file: `test/widget/interactive_child_test.dart`
- [ ] T035 [P] [US2] Widget test in same file: vertical drag on a child `ListView` scrolls the list; no page change
- [ ] T036 [P] [US2] Widget test in same file: horizontal drag starting on top of a button fires no button tap but does trigger a flip (past threshold)
- [ ] T037 [P] [US2] Widget test in same file: horizontal drag starting in the central non-hit-zone (center 20% of slot width) does NOT start a flip

### Implementation for User Story 2

- [ ] T038 [US2] Implement `FlipDragRecognizer extends HorizontalDragGestureRecognizer` in `lib/src/gestures/flip_drag_recognizer.dart`: keeps the default `kTouchSlop` deferral (already in base class) and adds an `edgeHitZoneFraction` gate on `isPointerAllowed` — only accepts the pointer if `localOffset` is within the outer `edgeHitZoneFraction` of the slot half facing the spine. (per [research.md R2](./research.md#r2--gesture-recognition--arbitration))
- [ ] T039 [US2] Swap `GestureDetector` → `RawGestureDetector` in `lib/src/flip_page_widget.dart`, registering `FlipDragRecognizer` via a `GestureRecognizerFactoryWithHandlers` bound to `_onDragStart` / `_onDragUpdate` / `_onDragEnd`.
- [ ] T040 [US2] Add `double? edgeHitZoneFraction` public parameter (default `0.4`) to `FlipPage`; thread to the recognizer factory. Document in [contracts/public-api.md](./contracts/public-api.md).
- [ ] T041 [US2] Verify idle state renders `pages[_currentIndex]` as a live `Widget` (already the case — regression guard via T034).
- [ ] T042 [US2] Run Phase 4 tests — all pass.

**Checkpoint**: live taps and scrolls inside pages work. Edge-drag still flips.

---

## Phase 5: User Story 3 — Portrait and landscape layouts (Priority: P2)

**Goal**: When the available aspect ratio ≥ 1.2, render two pages side-by-side as a book spread; otherwise portrait single page.

**Independent Test**: Run example. Phone portrait → one page visible. Landscape / wide desktop → pages N and N+1 side by side. Flipping the right page advances the spread to pages N+2/N+3. Flipping the left page reveals N-2/N-1.

### Tests for User Story 3 ⚠️

- [ ] T043 [P] [US3] Widget test: with `maxWidth:800, maxHeight:400` and `currentPage=2`, both `pages[2]` and `pages[3]` render — file: `test/widget/landscape_spread_test.dart`
- [ ] T044 [P] [US3] Widget test in same file: with `maxWidth:400, maxHeight:800`, only `pages[currentPage]` renders
- [ ] T045 [P] [US3] Widget test in same file: completing a drag on the right page advances the spread to pages N+2/N+3
- [ ] T046 [P] [US3] Widget test in same file: paper-curl fold math operates in slot-local coordinates (not widget-global) in landscape

### Implementation for User Story 3

- [ ] T047 [US3] Wrap `_buildPortrait` logic in a `LayoutBuilder` and call `SpreadLayout.resolve(constraints)` to pick mode — file: `lib/src/flip_page_widget.dart`
- [ ] T048 [US3] Implement landscape render path: split the area into two slots, render `pages[currentPage]` and `pages[currentPage + 1]`; per-slot `RepaintBoundary` + snapshot on drag start in that slot. Track `_activeSlot ∈ {left, right}` in state.
- [ ] T049 [US3] In landscape, advance `_currentIndex` by **2** on forward-settle (by **2** on backward-settle) so the spread pair moves together. Document this in [data-model.md](./data-model.md).
- [ ] T050 [US3] Pointer and anchor coordinates must be slot-local before they reach `FoldGeometry` — adapt the gesture callbacks (already receive `DragStartDetails.localPosition` but we need to translate to the active slot's local origin).
- [ ] T051 [US3] Run Phase 5 tests — all pass.

**Checkpoint**: landscape spread renders correctly. Paper-curl works in both slots.

---

## Phase 6: User Story 4 — Programmatic control and change notification (Priority: P3)

**Goal**: Developers can drive navigation via `FlipPageController` (`jumpTo` / `animateTo` / `next` / `previous`) and receive `onPageChanged` after any settled transition, whether gesture-driven or controller-driven.

**Independent Test**: Create a `FlipPageController`, attach to `FlipPage`. Call `controller.animateTo(5)` → curl animation plays, page 5 visible. Register `onPageChanged` — fires exactly once per settled transition, from both paths.

### Tests for User Story 4 ⚠️

- [ ] T052 [P] [US4] Unit test: `FlipPageController.jumpTo(validIndex)` updates `currentPage` and notifies listeners once; `jumpTo(outOfRange)` is a silent no-op — file: `test/unit/flip_page_controller_test.dart`
- [ ] T053 [P] [US4] Unit test in same file: `hasClients` is false before attach, true after; nav calls while detached are silent no-ops
- [ ] T054 [P] [US4] Widget test: `controller.animateTo(3)` plays the curl animation; `onPageChanged(3)` fires exactly once after settle — file: `test/widget/controller_test.dart`
- [ ] T055 [P] [US4] Widget test in same file: a gesture-driven flip also fires `onPageChanged` exactly once after settle
- [ ] T056 [P] [US4] Widget test in same file: `controller.previous()` at page 0 is a no-op; `onPageChanged` not called

### Implementation for User Story 4

- [ ] T057 [US4] Implement `class FlipPageController extends ChangeNotifier` in `lib/src/flip_page_controller.dart` per [contracts/public-api.md](./contracts/public-api.md#class-flippagecontroller-extends-changenotifier): `currentPage`, `hasClients`, `jumpTo`, `animateTo`, `next`, `previous`
- [ ] T058 [US4] Attach / detach lifecycle in `_FlipPageState.initState` / `dispose` / `didUpdateWidget`: own an internal controller when `widget.controller == null`, otherwise bind to the supplied one
- [ ] T059 [US4] Inject an animation hook on attach so `controller.animateTo` delegates to `_FlipPageState`'s settle pipeline
- [ ] T060 [US4] Refactor the current `_settleComplete` into a single "emit settled page change" method invoked from both gesture-settle and controller-animate paths; ensure `widget.onPageChanged` fires exactly once per settled change (guard against double-fire)
- [ ] T061 [US4] Add `controller` and `onPageChanged` to `FlipPage` if not already present; add `export 'src/flip_page_controller.dart' show FlipPageController;` to `lib/flip_page.dart`
- [ ] T062 [US4] Run Phase 6 tests — all pass

**Checkpoint**: controller-driven nav works; callback semantics consistent across both paths.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Boundary behavior, a11y, example app, docs, release gates.

- [ ] T063 [P] Widget test: rubber-band on drag past last page — drag on `pages.last` past threshold settles back to 0 progress; `pages.last` still current; `onPageChanged` not called — file: `test/widget/boundary_test.dart`
- [ ] T064 [P] Widget test in same file: rubber-band on drag before page 0; `FlipPage(pages: [])` ignores gestures; `FlipPage(pages: [single])` drag is a no-op
- [ ] T065 [P] Implement rubber-band dampening (factor `0.3`, cubic falloff) in drag-update when a flip would move past the first or last page — file: `lib/src/flip_page_widget.dart` (per [research.md R6](./research.md#r6--boundary-behavior-first--last-page))
- [ ] T066 [P] Implement basic `Semantics` wrapping per [contracts/public-api.md semantics contract](./contracts/public-api.md#semantics-contract-a11y): `Semantics(label: "Page N of M", liveRegion: true)` on visible page(s), `ExcludeSemantics` on non-visible pages, `SemanticsService.announce` on settled change — file: `lib/src/flip_page_widget.dart`
- [ ] T067 [P] Honor `MediaQuery.disableAnimations`: controller transitions complete with `Duration.zero` when true; drag tracking still updates `_progress` in real time — file: `lib/src/flip_page_widget.dart`
- [ ] T068 [P] Scaffold `example/` app: 5 colored pages, one page with an `ElevatedButton`, one page with a scrollable `ListView` — file: `example/lib/main.dart`
- [ ] T069 Fill in `example/pubspec.yaml` (depend on `flip_page` via `path: ../`); verify `cd example && flutter build apk --debug` succeeds
- [ ] T070 [P] Write dartdoc for every public symbol in `lib/src/flip_page_widget.dart`, `lib/src/flip_page_controller.dart`
- [ ] T071 [P] Enable `public_member_api_docs` lint in `analysis_options.yaml`; fix remaining violations
- [ ] T072 [P] Replace `README.md` pre-alpha notes with usage snippets from [quickstart.md](./quickstart.md) — file: `README.md`
- [ ] T073 [P] Append `## 0.1.0` entry in `CHANGELOG.md` listing the four user-story deliverables — file: `CHANGELOG.md`
- [ ] T074 Bump `pubspec.yaml` `version: 0.1.0` (from `0.0.1`) — file: `pubspec.yaml`
- [ ] T075 Run `flutter analyze` at package root — zero issues (release gate)
- [ ] T076 Run `flutter test --coverage` and verify `lcov --summary coverage/lcov.info` reports ≥ 80% (release gate)
- [ ] T077 Manually execute every section of [quickstart.md](./quickstart.md) against the `example/` app on one mobile simulator and one desktop — record results in the PR description
- [ ] T078 Run `dart pub deps --style=compact` at package root; confirm no non-SDK dependencies (release gate — SC-003)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: already done; no deps.
- **Phase 2 (Foundational)**: already done; blocks all user-story phases.
- **Phase 3 (US1 — Paper-curl)**: after Phase 2. Depends on `FoldGeometry` + `FlipCorner` + `FoldPainter`.
- **Phase 4 (US2)**: after Phase 2. Independent of Phase 3 in principle, but `test/widget/interactive_child_test.dart` relies on the drag-flip pipeline from Phase 3, so ship Phase 3 first.
- **Phase 5 (US3)**: after Phase 3. Landscape reuses the `FoldGeometry` rendering path in per-slot local coords.
- **Phase 6 (US4)**: after Phase 2. The `onPageChanged`-after-gesture assertion needs Phase 3's settle pipeline in place.
- **Phase 7 (Polish)**: after all US phases complete. T075 / T076 / T078 are release-blocking gates.

### User Story Dependencies

- **US1 (P1)**: pure infrastructure from Phase 2 + the new curl-render primitives. MVP target.
- **US2 (P2)**: layered on US1's drag/animation pipeline.
- **US3 (P2)**: layered on US1's render path (per-slot).
- **US4 (P3)**: controller logic independent; gesture-side callback assertion needs US1.

### Within Each Phase

- Tests before implementation (TDD — tests must fail first, then turn green).
- Pure-math / value objects before the widgets / painters that consume them.
- `_FlipPageState` edits inside the same file must serialize.

### Parallel Opportunities

- **Within US1**: tests T010–T015 are all `[P]` — write in parallel. Implementation tasks T021 (`FlipCorner`) and T022 (`FoldGeometry`) are `[P]` if split across two files. T025 (`FoldPainter`) depends on T022. T026–T030 serialize inside `flip_page_widget.dart`.
- **Within US2**: all 4 tests are `[P]`. Implementation serializes on the recognizer + widget file.
- **Within US3**: 4 tests `[P]`. Implementation serializes on `flip_page_widget.dart`.
- **Within US4**: 5 tests `[P]`. Implementation: `flip_page_controller.dart` (T057) and `flip_page_widget.dart` attach wiring (T058–T061) can proceed together.
- **Within Polish**: T063 / T064 tests `[P]`; T065–T067 serialize on `flip_page_widget.dart`; T068 `[P]` (new file); T070 / T071 / T072 / T073 `[P]` (different files); T074–T078 serialize (release gates).
- **Across US phases**: with multiple developers, US2 / US3 / US4 can proceed in parallel once US1 lands.

---

## Parallel Example: User Story 1

```bash
# All US1 tests first (write-first, before touching FoldGeometry):
Task: "Unit test FlipCorner.pickFromPointer — test/unit/flip_corner_test.dart"
Task: "Unit test FoldGeometry identity / reflection / partition / progress — test/unit/fold_geometry_test.dart"
Task: "Widget test paper-curl visibility — test/widget/curl_render_test.dart"

# Then implementation in parallel across separate files:
Task: "Implement FlipCorner — lib/src/rendering/flip_corner.dart"
Task: "Implement FoldGeometry — lib/src/rendering/fold_geometry.dart"

# Then serial inside flip_page_widget.dart:
Task: "Wrap pages[currentIndex] in RepaintBoundary + GlobalKey"
Task: "Snapshot on drag start + FoldGeometry.pointer mapping"
Task: "Replace _buildPortrait render path with CustomPaint(FoldPainter)"
```

---

## Implementation Strategy

### MVP First (US1 only, paper-curl)

1. Phases 1 & 2 — already done.
2. Phase 3 — write US1 tests first (T010–T015). Implement T021–T033.
3. Stop. Validate against the reference GIF visually; confirm SC-002 (60 fps) on a real device once Polish Phase 7 scaffolds the example app.
4. Optional tag `v0.1.0-mvp` internally.

### Incremental Delivery

1. Ship MVP (after Phase 3).
2. Add US2 → `v0.1.0-alpha.2`.
3. Add US3 → `v0.1.0-alpha.3`.
4. Add US4 → `v0.1.0-alpha.4`.
5. Polish (Phase 7) → publish `v0.1.0` to pub.dev.

### Parallel Team Strategy

Solo in practice. Run phases serially; within a phase, batch the `[P]` tasks.

---

## Notes

- `[P]` means different files, no in-flight dependencies — safe to parallelize.
- Each user story ends at a checkpoint that is independently runnable on the `example/` app once scaffolded in T068.
- **Goldens excluded from v0.1** ([research.md R9](./research.md#r9--testing-strategy)) — curl rendering differs subtly across renderers (Skia / Impeller / CanvasKit / html). Add in v0.2 behind a single-platform CI filter.
- Commit after each `[US*]` phase and at every checkpoint.
- Release gates: T075 (analyze), T076 (coverage), T078 (zero deps) are blocking.
