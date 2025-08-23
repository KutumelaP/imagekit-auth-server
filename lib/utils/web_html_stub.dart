// Stub for non-web to avoid importing dart:html
class _StubCssStyle {
  void setProperty(String name, String value) {}
}

class _StubElement {
  final _StubCssStyle style = _StubCssStyle();
}

class _StubDoc {
  final _StubElement documentElement = _StubElement();
  _StubElement? body = _StubElement();
  void addEventListener(String type, Function handler, [bool? opt]) {}
  dynamic querySelector(String selector) => null;
  // Add missing visibilityState property
  String get visibilityState => 'visible';
}

class _StubWindow {
  final _StubNavigator navigator = _StubNavigator();
  final dynamic visualViewport = null;
  int? get innerHeight => null;
  void addEventListener(String type, Function handler) {}
}

class _StubNavigator {
  dynamic get serviceWorker => null;
  String get userAgent => '';
}

final _StubWindow window = _StubWindow();
final _StubDoc document = _StubDoc();

class TouchEvent {
  List<dynamic>? touches;
  void preventDefault() {}
}


