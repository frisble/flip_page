# Release Flip Fix Design

Date: 2026-05-16

## Context

`FlipPage` works in debug mode on emulator and physical devices, but page turns do not work when the app is started with a Flutter `--release` build. The investigation and fix must happen in the `flip_page` package, not in the consuming Palio app.

The package already contains a small `example/` app, so release-mode reproduction should use that app before testing the larger consuming app.

## Current Suspects

Two package internals are likely involved:

- `FlipDragRecognizer`, because release mode may not claim the gesture arena the same way the current custom `HorizontalDragGestureRecognizer` path does in debug.
- `_captureSnapshotFrom()`, because it uses `RenderRepaintBoundary.debugNeedsPaint` in runtime logic. That is a debug-only signal and should not control release behavior.

## Decisions

- Keep the public `FlipPage` API stable unless the investigation proves a new parameter is required.
- Remove the previous `0.1.1` touch-slop change because it did not fix the release issue and likely added unnecessary API surface.
- Use the package `example/` app as the release/profile reproduction harness.
- Keep the consuming app out of the first fix loop. It should only be updated after the package fix is verified.

## Rollback Scope

Revert the changes introduced by commit `4621490 fix: reliable touch input on real devices via lower drag slop`:

- Remove the `0.1.1` changelog entry.
- Restore the package version before the premature fix.
- Remove the public `FlipPage.touchSlop` parameter.
- Remove `kFlipPageDefaultTouchSlop`.
- Remove the `DeviceGestureSettings(touchSlop: ...)` customization from `FlipDragRecognizer`.

This rollback should be surgical. Do not revert unrelated later changes.

## Proposed Fix

### Gesture Arena

Keep `FlipDragRecognizer` as the package boundary for flip-specific pointer handling. Make its arena behavior explicit and testable instead of relying on the prior touch-slop workaround.

The recognizer should:

- Accept pointer-down events only inside the configured edge hit zones.
- Claim horizontal drags reliably in profile and release.
- Continue to reject central drags so interactive child widgets remain usable.
- Continue to allow vertical child gestures, such as `ListView` scrolling.

If the current subclass of `HorizontalDragGestureRecognizer` cannot satisfy those requirements reliably in release, replace only the recognizer implementation while preserving the external `FlipPage` widget API.

### Snapshot Capture

Remove runtime dependency on `debugNeedsPaint`.

`_captureSnapshotFrom()` should:

- Return `null` only when the boundary is unavailable or capture fails.
- Attempt `toImageSync()` inside the existing guarded path.
- Treat missing snapshots as a visual fallback, not as a reason the page cannot settle.

If a snapshot is unavailable at drag start, the flip interaction should still update state and complete or revert correctly.

## Testing

Automated verification:

- Run `fvm flutter test`.
- Run `fvm flutter analyze`.
- Add or update focused tests for:
  - edge-zone drag flips;
  - central drag does not flip;
  - vertical child drag still scrolls;
  - snapshot failure does not prevent drag state from settling.

Manual release verification:

- Run the package example on a physical device with `fvm flutter run --release` from `example/`.
- Confirm dragging from the album/page edge turns pages.
- Confirm buttons and scrollable content still behave correctly.

## Acceptance Criteria

- Pages flip in a Flutter `--release` build using the package example app.
- Existing debug/widget-test behavior remains intact.
- No unnecessary `touchSlop` public API remains.
- No runtime logic depends on `debugNeedsPaint`.
- The fix is isolated to the package and does not require changes inside the consuming app.
