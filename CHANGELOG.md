## 0.1.3

- Fix: pages now keep their `State` across a flip instead of remounting. Each page is given a stable per-index identity and the outgoing page is kept mounted (offstage) during the drag, so a revert or completed flip no longer rebuilds the page subtree. This removes the visible image reload/flicker on widgets that hold state (e.g. `Image`/`CachedNetworkImage`) when swiping.
- Perf/UX: immediate neighbour pages are pre-mounted offstage while idle, so a flip reveals the incoming page already built and loaded (no first-paint flash on the page being turned to). Neighbours migrate straight into the flip via their stable page key.

## 0.1.2

- Fix: page flips now work in Flutter release builds by making flip drag arena claiming release-safe.
- Fix: snapshot capture no longer depends on debug-only render state.
- Fix: removed the premature `touchSlop` public API change.

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
