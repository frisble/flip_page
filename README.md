# flip_page

Realistic page-flip widget for Flutter with a turn.js-style paper-curl animation and full widget interactivity.

## Features

- Paper-curl animation with fold line, visible back of page, and drop shadow.
- 4-corner drag anchor selection — peel from the nearest corner.
- Full widget interactivity inside pages (buttons, inputs, scrollables).
- Edge-hit-zone gesture arbitration — only the outer edges trigger flips.
- Programmatic navigation via `FlipPageController` (`jumpTo`, `animateTo`, `next`, `previous`).
- Page-change callback (`onPageChanged`) for both gesture and controller paths.
- Zero runtime dependencies (pure Flutter).
- Works on iOS, Android, Web, macOS, Windows, Linux.

## Usage

```dart
import 'package:flip_page/flip_page.dart';

FlipPage(
  pages: [
    Container(color: Colors.amber, child: Center(child: Text('1'))),
    Container(color: Colors.teal, child: Center(child: Text('2'))),
    Container(color: Colors.indigo, child: Center(child: Text('3'))),
  ],
)
```

### Interactive children

```dart
FlipPage(
  pages: [
    Center(child: ElevatedButton(onPressed: () {}, child: Text('Tap me'))),
    ListView(children: List.generate(50, (i) => ListTile(title: Text('Row $i')))),
  ],
)
```

### Programmatic control

```dart
final controller = FlipPageController();

FlipPage(
  controller: controller,
  onPageChanged: (i) => print('now on page $i'),
  pages: pages,
);

// Navigate:
await controller.next();
await controller.animateTo(3);
controller.jumpTo(0);

// Don't forget:
controller.dispose();
```

### Customizing the paper look

```dart
FlipPage(
  pages: pages,
  backTintColor: Color(0xAA000000),   // darker paper back
  shadowColor: Color(0x55000000),     // stronger fold shadow
  flipCornerFraction: 0.7,           // bias anchor toward bottom corner
  edgeHitZoneFraction: 0.3,          // narrower sensitive zone
)
```

## License

MIT. See [LICENSE](LICENSE).
