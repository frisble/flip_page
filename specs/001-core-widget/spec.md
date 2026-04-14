# Feature Specification: Core FlipPage Widget (v0.1)

**Feature Branch**: `001-core-widget`
**Created**: 2026-04-14
**Status**: Draft
**Input**: User description: "v0.1 core FlipPage widget: drag-to-flip page widget with curl animation, interactive children, portrait/landscape layout, pure Flutter no deps"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag-to-flip with curl animation (Priority: P1)

A Flutter developer building a digital book or magazine reader wraps an ordered list of page widgets inside `FlipPage`. The end user drags horizontally on a page; the page follows the finger with a realistic curl (perspective + shadow). Releasing past a mid-threshold completes the flip to the next/previous page; releasing before the threshold reverts the curl back to flat.

**Why this priority**: This is the entire point of the widget. Without it, the package has no value. Delivering this alone is a usable MVP — a developer can already build a page-flip book.

**Independent Test**: Run the example app with 5 static page widgets. Drag from right edge leftward; page must curl following the pointer. Release past 50% of page width; next page is shown. Release before 50%; original page returns. No other features required.

**Acceptance Scenarios**:

1. **Given** a `FlipPage` with pages [A, B, C] showing page A, **When** the user drags from the right edge toward the left past the flip threshold and releases, **Then** page B becomes the current page and a visible curl animation plays during the drag.
2. **Given** page B is current, **When** the user drags from the left edge rightward past the threshold and releases, **Then** page A becomes the current page.
3. **Given** a drag in progress at 30% of page width, **When** the user releases, **Then** the curl animates back to flat and the original page remains current.
4. **Given** a drag in progress, **When** the user is still dragging, **Then** the curl position continuously tracks the pointer without visible stutter.

---

### User Story 2 - Interactive page content (Priority: P2)

Page children contain interactive widgets (buttons, links, form inputs). Tapping these widgets triggers their `onTap`/`onPressed` callbacks normally, without being intercepted by the flip gesture. Only an intentional drag initiates a flip.

**Why this priority**: Without this, pages are inert images. Real books have links, tappable illustrations, forms. P2 because MVP can technically ship with non-interactive content for testing, but real adoption requires this.

**Independent Test**: Place a `FlipPage` with a page containing an `ElevatedButton`. Tap the button — its `onPressed` fires, no flip occurs. Drag across the button — a flip starts, the button's `onPressed` does not fire.

**Acceptance Scenarios**:

1. **Given** a page containing a button, **When** the user taps the button without dragging, **Then** the button's tap handler runs and no flip occurs.
2. **Given** a page containing a scrollable list, **When** the user drags vertically on the list, **Then** the list scrolls and no flip occurs.
3. **Given** a page containing a button, **When** the user drags horizontally past the gesture slop starting on the button, **Then** a flip starts and the button does not register a tap.

---

### User Story 3 - Portrait and landscape layouts (Priority: P2)

The widget adapts to the device orientation. In portrait, one page fills the viewport. In landscape, two pages are displayed side-by-side (left/right spread) to match the feel of a physical open book.

**Why this priority**: Landscape two-page spread is a defining feature of book readers and a clear differentiator. P2 because portrait-only is shippable as a first cut, but the gap would be immediately noticed.

**Independent Test**: Run example app. Rotate device to portrait → single page visible, flip animates across full width. Rotate to landscape → two pages visible; flipping the right page reveals the next pair; flipping the left page reveals the previous pair.

**Acceptance Scenarios**:

1. **Given** portrait orientation and current page index 2, **When** the widget renders, **Then** only page 2 is visible filling the available area.
2. **Given** landscape orientation and current page index 2, **When** the widget renders, **Then** pages 2 and 3 are visible side by side.
3. **Given** landscape orientation with the right page being flipped forward past threshold, **When** the drag completes, **Then** the new spread shows pages 4 and 5.

---

### User Story 4 - Programmatic control and change notification (Priority: P3)

A developer can control the current page index from code (jump to page, next, previous) via a controller, and receive a callback when the page changes (whether by gesture or code).

**Why this priority**: Enables integration with app state, deep-linking, table-of-contents navigation. Not required for the minimal demo but needed for real apps.

**Independent Test**: Create a `FlipPageController`, attach to `FlipPage`, call `controller.jumpTo(3)` — page 3 is shown without animation. Call `controller.animateTo(5)` — a flip animation plays through to page 5. Register `onPageChanged`; both gesture-driven and programmatic changes invoke it exactly once per settled page.

**Acceptance Scenarios**:

1. **Given** a controller attached to `FlipPage`, **When** `controller.animateToNext()` is called, **Then** a curl animation plays and the next page becomes current.
2. **Given** an `onPageChanged` callback registered, **When** a user completes a drag flip, **Then** the callback fires once with the new page index after the animation settles.
3. **Given** the widget is showing page 0, **When** `controller.previous()` is called, **Then** no change occurs (already at first page) and `onPageChanged` does not fire.

---

### Edge Cases

- Zero pages: widget renders an empty placeholder area, no gestures active.
- Single page: no flip possible; drag gesture is a no-op or rubber-bands back.
- Drag forward from the last page / backward from the first page: rubber-band resistance, returns to flat on release (no page change).
- Release exactly at the threshold (50%): deterministic behavior (treat as "completed") must be consistent across devices.
- Drag interrupted by another pointer (multi-touch): first pointer wins; additional pointers are ignored until gesture ends.
- Very fast swipe below the distance threshold: velocity above a minimum triggers completion (fling semantics).
- Pages of unequal sizes: each page is constrained to the widget's layout slot; oversized children clip.
- Widget size changes mid-animation (orientation rotation, window resize): in-flight drag cancels, page settles to nearest valid state.
- Text direction RTL: out of scope for v0.1 (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The widget MUST accept an ordered list of child widgets, each representing one page.
- **FR-002**: The widget MUST render the current page filling its layout slot (portrait) or the current pair side-by-side (landscape).
- **FR-003**: A horizontal drag gesture on a page MUST produce a curl animation that visually tracks the pointer position continuously.
- **FR-004**: Releasing a drag past a completion threshold (distance or velocity) MUST advance (or reverse) the current page by one; releasing below the threshold MUST revert to the original page.
- **FR-005**: Drag direction MUST determine flip direction (leftward drag on right edge → next; rightward drag on left edge → previous).
- **FR-006**: Interactive descendants (buttons, form fields, scrollables) MUST receive their own tap and scroll gestures when the pointer movement does not exceed the horizontal drag slop.
- **FR-007**: The widget MUST expose a controller for programmatic navigation: jump (no animation), animate to a given index, next, previous.
- **FR-008**: The widget MUST expose a change-notification callback invoked once per settled page transition, regardless of whether the transition was driven by gesture or controller.
- **FR-009**: The widget MUST support both portrait (single page) and landscape (two-page spread) layouts, switching automatically based on available aspect ratio.
- **FR-010**: The widget MUST rubber-band and stay on the current page when a flip would move past the first or last page.
- **FR-011**: The widget MUST render without stutter at 60 frames per second during drag and animation on a mid-range mobile device (reference: 2022-era Android phone).
- **FR-012**: The package MUST have zero runtime dependencies outside the Flutter SDK.
- **FR-013**: The package MUST work on iOS, Android, Web, macOS, Windows, and Linux without platform-specific code paths in the public API.
- **FR-014**: The widget MUST expose basic semantics for screen readers: the current page's content is reachable; page-change events are announced.

### Key Entities

- **FlipPage (widget)**: The public widget. Holds the list of pages, the optional controller, the optional page-changed callback, and presentation options (e.g., spine side, shadow intensity — concrete options deferred to design).
- **FlipPageController**: Controls navigation imperatively. Exposes current index, jump/animate/next/previous operations. Notifies the widget of requested changes.
- **Page**: Any `Widget` supplied as a child. No required interface; the library treats children as opaque.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can build a working 5-page flip demo by writing a single widget call (`FlipPage(pages: [...])`) plus a `MaterialApp`, in under 5 minutes from reading the README.
- **SC-002**: Page-flip drag and animation run at a sustained 60 frames per second on a 2022-era mid-range Android device under the example app workload.
- **SC-003**: The published package declares zero non-SDK runtime dependencies in its pubspec.
- **SC-004**: Automated tests cover at least 80% of package lines and include unit tests for controller logic and widget tests for gesture-to-page-change flows.
- **SC-005**: The package passes `flutter analyze` with zero warnings and achieves at least 130 pub points on first publish to pub.dev.
- **SC-006**: In user testing on the example app (5 testers, 3 flips each), at least 90% of flip attempts resolve to the user-intended page (no accidental flips or missed flips).
- **SC-007**: An interactive widget inside a page (e.g., button) fires its tap handler on 100% of direct taps in automated widget tests.

## Assumptions

- Primary use case is a digital book / magazine / picture-book reader. Carousel-style use is acceptable but not the focus.
- Right-to-left text and spine-on-right variants are out of scope for v0.1 (spine is always on the left / flip direction follows LTR convention). RTL support is a planned follow-up.
- PDF rendering is out of scope; a separate companion package (`flip_page_pdf`) will handle that in a later release.
- Advanced accessibility (reduced-motion preference, detailed spoken page announcements, custom focus order across the spread) is a v0.2 concern. v0.1 provides basic reachable semantics only.
- The example application scaffolded alongside the package counts as the primary manual-testing surface for SC-001, SC-002, SC-006.
- Target minimum Flutter SDK version is whatever the scaffold was generated against (currently 3.41.6 stable); no attempt is made to support older channels.
- Bookmarks, animation timing customization beyond a small set of exposed options, and custom curl shapes (peel, fold) are explicitly out of scope for v0.1.
