import 'package:http/http.dart' as http;

/// Вне браузера (в тестах) используется обычный клиент.
http.Client createHttpClient() => http.Client();
