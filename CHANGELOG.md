## Unreleased

- Fix: page flips now work in Flutter release builds by making flip drag arena claiming release-safe.
- Fix: snapshot capture no longer depends on debug-only render state.
- Fix: removed the premature `touchSlop` public API change from the unreleased package state.

## 0.1.0

- Paper-curl page-flip animation with fold line, reflected back-of-page tint, and drop shadow.
- 4-corner drag anchor selection based on pointer quadrant at drag start.
- Interactive child support: buttons, scrollables, and form inputs work inside pages.
- Edge-hit-zone gesture arbitration via custom `HorizontalDragGestureRecognizer`.
- `FlipPageController` for programmatic navigation (`jumpTo`, `animateTo`, `next`, `previous`).
- `onPageChanged` callback fires exactly once per settled transition.
- Basic accessibility: `Semantics` wrapping, `SemanticsService.sendAnnouncement` on page change.
- Zero runtime dependencies; works on iOS, Android, Web, macOS, Windows, Linux.

## 0.0.1

- Initial scaffold.
