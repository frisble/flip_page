# flip_page

Realistic page-flip widget for Flutter with physics-based curl animation and full widget interactivity.

> Status: **pre-alpha**. API unstable. Not yet published to pub.dev.

## Features (planned)

- Physics-based page-curl animation with shadow.
- Full widget interactivity inside pages (taps, inputs, gestures).
- Smart gesture arbitration between page flips and child widgets.
- Portrait and landscape layouts.
- Zero runtime dependencies (pure Flutter).

## Usage

```dart
import 'package:flip_page/flip_page.dart';

FlipPage(
  children: [
    PageOne(),
    PageTwo(),
    PageThree(),
  ],
)
```

## License

MIT. See [LICENSE](LICENSE).
