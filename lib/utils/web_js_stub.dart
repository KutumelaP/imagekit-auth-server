// Stub for non-web platforms to avoid importing dart:js
class _StubContext {
  bool hasProperty(String name) => false;
  dynamic callMethod(String name, [List<dynamic>? args]) => null;
}

final context = _StubContext();

T allowInterop<T>(T f) => f;

class JsObject {
  JsObject.fromBrowserObject(Object o);
  static JsObject jsify(Object? o) => JsObject.fromBrowserObject(Object());
  dynamic callMethod(String name, [List<dynamic>? args]) => null;
}



