# Implementation Plan: Core FlipPage Widget (v0.1)

**Branch**: `001-core-widget` | **Date**: 2026-04-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-core-widget/spec.md`

## Summary

Deliver the v0.1 public surface of `flip_page`: a `FlipPage` widget plus `FlipPageController`, with a drag-driven **paper-curl** flip (turn.js-style corner peel: fold line, visible back of page, drop shadow, next page revealed underneath), interactive child support, portrait + landscape two-page spread, rubber-band boundaries, and a page-change callback. Pure Flutter, zero third-party runtime deps. MIT-licensed, multi-platform (iOS, Android, Web, macOS, Windows, Linux).

**Technical approach**: during drag, a `ui.Image` snapshot of the outgoing page (captured via `RenderRepaintBoundary.toImageSync` at drag-start) is painted by a `CustomPainter` in three layers — (1) outgoing page clipped to the unfolded half-plane of the fold line, (2) the folded triangle reflected across the fold line and tinted (the paper back), (3) a soft drop shadow along the fold line. The fold line is the perpendicular bisector of `(anchor-corner, pointer)`; the anchor corner is chosen at drag-start from the pointer quadrant (4 corners in portrait). A custom `HorizontalDragGestureRecognizer` subclass handles gesture arbitration with child widgets; an `AnimationController` drives the settle animation on release.

## Technical Context

**Language/Version**: Dart 3.11.4 / Flutter 3.41.6 stable (fvm-managed).
**Primary Dependencies**: Flutter SDK only — `package:flutter/widgets.dart`, `package:flutter/material.dart`, `package:flutter/rendering.dart` (for `RenderRepaintBoundary.toImageSync`), `package:flutter/gestures.dart` (for the custom recognizer), `dart:ui` (for `Image`, `Canvas`, `Path`). No third-party runtime deps.
**Storage**: N/A — stateless widget. Caller owns any persistence of `initialPage`.
**Testing**: `flutter_test` (widget + unit), `test` (pure-Dart unit). No golden tests in v0.1 — curl rendering differs subtly across renderers (Skia / Impeller / CanvasKit / html); goldens gate-flaky across CI.
**Target Platform**: iOS 12+, Android API 21+, Web (canvaskit + html), macOS 10.14+, Windows 10+, Linux (GTK). No platform channels.
**Project Type**: Flutter library package (publishable to pub.dev).
**Performance Goals**: sustained 60 fps during drag + settle on a 2022-era mid-range Android device (Pixel 6a-class); per-frame budget ≤ 16 ms for paint + layout combined. One `toImageSync` per drag (not per frame).
**Constraints**: zero non-SDK runtime deps (enforced in pubspec + CI); passes `flutter analyze` with zero warnings under `strict-casts` / `strict-inference` / `strict-raw-types` and `public_member_api_docs`; ≥ 80% line coverage; pub-points ≥ 130 on publish.
**Scale/Scope**: one public widget (`FlipPage`), one public controller (`FlipPageController`), two public optional callbacks. Estimated v0.1 LOC: ≤ 1.8k in `lib/`, ≤ 2.2k in `test/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The repository's `.specify/memory/constitution.md` is the unmodified scaffold template (no principles ratified). **Status: N/A — no binding gates.** Using accepted pub.dev-library defaults as proxy principles:

- **Library-first**: ✅ scope is a single library package; nothing outside `lib/` except the `example/` app.
- **Test-first (TDD)**: ✅ tasks schedule unit + widget tests before implementation.
- **Simplicity / YAGNI**: ✅ API surface is one widget + one controller + three optional callbacks — no extras.
- **Zero-dep purity**: ✅ locked by FR-012; verified in CI via `dart pub deps`.
- **Platform parity**: ✅ no `defaultTargetPlatform` or `kIsWeb` branches in public paths; verified by FR-013.

**Post-Phase-1 re-check**: no new violations introduced by the Phase 1 design. See bottom of file.

## Project Structure

### Documentation (this feature)

```text
specs/001-core-widget/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output (decisions R1–R12)
├── data-model.md        # Phase 1 output (internal + public types)
├── quickstart.md        # Phase 1 output (consumer usage walkthrough)
├── contracts/
│   └── public-api.md    # Phase 1 output (Dart public API surface)
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
flip_page/
├── lib/
│   ├── flip_page.dart                 # public barrel — exports only FlipPage + FlipPageController
│   └── src/
│       ├── flip_page_widget.dart      # FlipPage (public) + _FlipPageState (private, co-located)
│       ├── flip_page_controller.dart  # FlipPageController (public)
│       ├── gestures/
│       │   └── flip_drag_recognizer.dart   # custom HorizontalDragGestureRecognizer with edge-hit-zone gating
│       ├── rendering/
│       │   ├── flip_corner.dart            # FlipCorner enum + pickFromPointer helper
│       │   ├── fold_geometry.dart          # FoldGeometry value object (replaces obsolete curl_geometry.dart)
│       │   └── fold_painter.dart           # CustomPainter: 3-layer clip+reflect+shadow
│       └── layout/
│           └── spread_layout.dart          # SpreadMode enum + resolve() (portrait vs landscape)
├── test/
│   ├── flip_page_test.dart                 # library smoke
│   ├── unit/
│   │   ├── flip_page_controller_test.dart
│   │   ├── flip_corner_test.dart
│   │   ├── fold_geometry_test.dart
│   │   └── spread_layout_test.dart
│   └── widget/
│       ├── gesture_flip_test.dart
│       ├── curl_render_test.dart
│       ├── interactive_child_test.dart
│       ├── landscape_spread_test.dart
│       ├── controller_test.dart
│       └── boundary_test.dart
└── example/
    ├── lib/main.dart                       # 5-page demo with interactive children
    ├── pubspec.yaml
    └── test/                               # smoke
```

**Structure Decision**: Standard Flutter package layout. Public API lives in `lib/flip_page.dart`; everything else under `lib/src/` (not exported). `src/` is split into three concern groups — gesture, rendering, layout — each under 400 LOC per file. `_FlipPageState` is co-located with its widget in `flip_page_widget.dart` (idiomatic Dart — private `State` co-located with its `StatefulWidget`). The `example/` app is the manual-testing surface referenced in SC-001 / SC-002 / SC-006 and doubles as a golden-path integration-test target.

## Complexity Tracking

No Constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

## Post-Phase-1 Constitution Re-Check

Phase 1 design introduces:

- One public widget + one public controller + two public optional callbacks + one public optional parameter struct (inlined) — stays within "simple" gate.
- Internal split across 7 files under `lib/src/`; each with a single responsibility; no file exceeds 400 LOC target.
- No new dependencies. Zero-dep gate holds.
- Paper-curl algorithm (R1) is pure arithmetic — line reflection + clip paths — shipped inside `fold_geometry.dart`. No external crypto / I/O / async beyond Flutter's own `Ticker`.

**Result**: Post-design gates still pass.
