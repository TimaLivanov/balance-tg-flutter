import 'dart:convert';
import 'dart:js_interop';

import 'telegram_info.dart';

/// Глобальная функция определена в web/index.html после загрузки
/// telegram-web-app.js.
@JS('__bbTgInfo')
external JSFunction? get _tgInfo;

TelegramInfo? readTelegramInfo() {
  final fn = _tgInfo;
  if (fn == null) return null;
  final JSAny? value = fn.callAsFunction();
  final String raw;
  if (value case final JSString s) {
    raw = s.toDart;
  } else {
    return null;
  }
  if (raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final initData = map['initData']?.toString() ?? '';
    if (initData.isEmpty) return null;
    final user = map['user'] is Map ? map['user'] as Map : null;
    return TelegramInfo(
      initData: initData,
      username: user?['username']?.toString(),
      platform: map['platform']?.toString() ?? '',
    );
  } catch (_) {
    return null;
  }
}
