import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client.dart';

class ApiService {
  ApiService({this.baseUrl = 'https://balance-tg.geniy-2012.workers.dev'});

  final String baseUrl;
  final http.Client _client = createHttpClient();

  Future<http.Response> get(String path) =>
      _client.get(Uri.parse('$baseUrl$path'));

  Future<http.Response> post(String path, [Map<String, dynamic>? body]) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) {
    return _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) {
    return _client.delete(Uri.parse('$baseUrl$path'));
  }

  void dispose() => _client.close();
}
