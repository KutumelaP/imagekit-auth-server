// Stub for non-web platforms to avoid importing dart:js
class _StubContext {
  bool hasProperty(String name) => false;
  dynamic callMethod(String name, [List<dynamic>? args]) => null;
  dynamic operator [](Object? name) => null;
}

final context = _StubContext();

T allowInterop<T>(T f) => f;

class JsObject {
  // Default constructor mimicking dart:js JsObject(ctor, args)
  JsObject([Object? ctor, List<dynamic>? args]);

  // fromBrowserObject factory
  JsObject.fromBrowserObject(Object o);

  // jsify helper
  static JsObject jsify(Object? o) => JsObject.fromBrowserObject(Object());

  // Call a method on the underlying JS object
  dynamic callMethod(String name, [List<dynamic>? args]) => null;

  // Property access operators
  dynamic operator [](String name) => null;
  void operator []=(String name, dynamic value) {}
}



