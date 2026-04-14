# Quickstart: Using `flip_page` v0.1

**Feature**: 001-core-widget · **Date**: 2026-04-14

Consumer-facing walkthrough. Mirrors what will land in the published `README.md`. Also doubles as the acceptance script for the example app (SC-001).

---

## Install

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  flip_page: ^0.1.0
```

Then `flutter pub get`.

---

## Minimum viable usage (P1 — paper-curl)

```dart
import 'package:flutter/material.dart';
import 'package:flip_page/flip_page.dart';

void main() => runApp(const MaterialApp(home: _Demo()));

class _Demo extends StatelessWidget {
  const _Demo();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlipPage(
        pages: [
          Container(color: Colors.amber,      child: const Center(child: Text('1'))),
          Container(color: Colors.teal,       child: const Center(child: Text('2'))),
          Container(color: Colors.indigo,     child: const Center(child: Text('3'))),
          Container(color: Colors.pink,       child: const Center(child: Text('4'))),
          Container(color: Colors.deepOrange, child: const Center(child: Text('5'))),
        ],
      ),
    );
  }
}
```

**Expected**:
- Drag from any corner of the visible page. The corner peels along a straight fold line following your finger.
- The peeled triangle shows the back of the outgoing page (semi-transparent dark tint).
- A soft shadow appears under the peel.
- The next page is visible underneath where the peeled triangle would otherwise sit.
- Release past ~50% of the page diagonal → the flip completes. Release before → the peel reverts.

---

## With interactive children (P2)

```dart
FlipPage(
  pages: [
    Center(
      child: ElevatedButton(
        onPressed: () => debugPrint('tapped'),
        child: const Text('Tap me'),
      ),
    ),
    ListView(children: List.generate(50, (i) => ListTile(title: Text('Row $i')))),
    const Center(child: Text('Page 3')),
  ],
);
```

**Expected**:
- Tapping the button prints "tapped" — no flip.
- Vertical scrolls on the `ListView` scroll normally — no flip.
- Horizontal drags from an edge still flip.

Tune the edge hit-zone if needed:

```dart
FlipPage(pages: pages, edgeHitZoneFraction: 0.3);  // narrower sensitive zone
```

---

## Programmatic control (P3)

```dart
final controller = FlipPageController(initialPage: 0);

FlipPage(
  controller: controller,
  onPageChanged: (i) => debugPrint('now on page $i'),
  pages: pages,
);

// elsewhere:
await controller.next();        // animate forward
await controller.animateTo(7);  // animate directly to page 7
controller.jumpTo(0);           // no animation
```

Don't forget `controller.dispose()` in your widget's `dispose()`.

---

## Landscape two-page spread (P2)

No API call needed — `FlipPage` auto-detects from incoming constraints. Rotate the device, or resize the window on desktop / web: once the aspect ratio crosses `1.2`, the widget renders a left / right spread. The peel operates per slot — dragging the right page flips forward (advancing the spread by 2), dragging the left page flips backward.

---

## Customizing the paper look

```dart
FlipPage(
  pages: pages,
  backTintColor: const Color(0xAA000000),   // darker paper back
  shadowColor: const Color(0x55000000),     // stronger fold shadow
  flipCornerFraction: 0.7,                  // bias anchor toward bottom corner
);
```

- `backTintColor` is alpha-blended over the reflected snapshot in `srcATop` mode. Use `Color(0x00...)` to disable the tint.
- `flipCornerFraction` splits the slot vertically to decide top-corner vs bottom-corner anchor (0.5 = exact middle).

---

## Performance validation (SC-002)

Run the `example/` app on a 2022-era mid-range Android device (Pixel 6a, Galaxy A54, or equivalent). Flick through pages rapidly. Expected: sustained 60 fps in DevTools performance overlay. Frame times above 16 ms during the settle animation are a regression.

---

## Zero deps check (SC-003)

```bash
dart pub deps --style=compact
```

Expected: only Flutter SDK packages (`flutter`, `sky_engine`, etc.) under `flip_page`. No third-party packages.

---

## Test locally

```bash
flutter analyze          # must be clean (SC-005)
flutter test --coverage  # must be >= 80% (SC-004)
```
