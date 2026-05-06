## 0.1.1

- Fix: short flicks on real touch devices now register reliably. Default touch slop lowered to 6.0 (from Flutter's 18.0) so the recognizer claims the arena before the user lifts. Previously, iOS Simulator (mouse pointer, ~1 px slop) worked while real iOS/Android devices appeared unresponsive on short swipes.
- New: `FlipPage.touchSlop` parameter to tune the drag threshold per app.

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
