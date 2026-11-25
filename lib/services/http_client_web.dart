import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// В браузере отправляем cookie с запросами (SameSite=None).
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
