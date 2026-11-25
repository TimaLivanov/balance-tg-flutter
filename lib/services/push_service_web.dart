import 'dart:js_interop';

/// Глобальная функция определена в web/index.html.
@JS('__bbPushSubscribe')
external JSPromise<JSString?> _subscribePush();

Future<String?> subscribePush() async {
  final JSString? raw = await _subscribePush().toDart;
  if (raw == null || raw.toDart.isEmpty) return null;
  return raw.toDart;
}
