import 'package:flutter/foundation.dart';

/// Controls a [FlipPage] widget programmatically.
///
/// Provides [jumpTo], [animateTo], [next], and [previous] methods plus a
/// [currentPage] getter. The controller notifies its listeners and fires
/// the widget's `onPageChanged` callback on every settled page change.
///
/// Must be [dispose]d when no longer needed.
class FlipPageController extends ChangeNotifier {
  /// Creates a [FlipPageController].
  ///
  /// [initialPage] defaults to `0`. The value is used only when no live
  /// [FlipPage] is attached; once attached the widget may override it
  /// based on its own `initialPage`.
  FlipPageController({int initialPage = 0}) : _currentPage = initialPage;

  int _currentPage;
  int _pageCount = 0;
  bool _attached = false;

  // Injected by _FlipPageState.attach so controller-driven animations
  // funnel through the widget's AnimationController.
  Future<void> Function(int)? _animateHook;
  void Function(int)? _jumpHook;

  /// The index of the currently-visible page.
  int get currentPage => _currentPage;

  /// `true` when a live [FlipPage] widget is currently attached.
  bool get hasClients => _attached;

  /// Jumps to [index] without animation.
  ///
  /// Fires `onPageChanged` and notifies listeners on success.
  /// Silent no-op when detached or when [index] is out of range.
  void jumpTo(int index) {
    if (!_attached) return;
    if (index < 0 || index >= _pageCount) return;
    if (index == _currentPage) return;
    _jumpHook?.call(index);
  }

  /// Animates to [index] using the settle animation.
  ///
  /// Returns a [Future] that resolves when the animation completes.
  /// Silent no-op when detached, out-of-range, or same-page.
  Future<void> animateTo(int index) async {
    if (!_attached) return;
    if (index < 0 || index >= _pageCount) return;
    if (index == _currentPage) return;
    await _animateHook?.call(index);
  }

  /// Shorthand for `animateTo(currentPage + 1)`.
  Future<void> next() => animateTo(_currentPage + 1);

  /// Shorthand for `animateTo(currentPage - 1)`.
  Future<void> previous() => animateTo(_currentPage - 1);

  // --- Package-private attachment API used by _FlipPageState ---

  /// Attaches the controller to a live widget state.
  void attach({
    required int pageCount,
    required int currentPage,
    required Future<void> Function(int) animateHook,
    required void Function(int) jumpHook,
  }) {
    _attached = true;
    _pageCount = pageCount;
    _currentPage = currentPage;
    _animateHook = animateHook;
    _jumpHook = jumpHook;
  }

  /// Detaches the controller from its widget.
  void detach() {
    _attached = false;
    _animateHook = null;
    _jumpHook = null;
  }

  /// Updates internal bookkeeping when the widget's page list changes.
  void updatePageCount(int count) {
    _pageCount = count;
  }

  /// Called by the widget state to keep the controller in sync after a
  /// settled page change (either gesture-driven or controller-driven).
  void syncCurrentPage(int page) {
    if (_currentPage == page) return;
    _currentPage = page;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
