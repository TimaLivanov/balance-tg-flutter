import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../models/user_data.dart';

class DataService {
  DataService(this._api);
  final ApiService _api;

  Future<UserData> get() async {
    final res = await _api.get('/api/data');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final dataJson = json['data'] as Map<String, dynamic>? ?? {};
      return UserData.fromJson(dataJson);
    }
    if (res.statusCode == 404) {
      throw Exception('404: Эндпоинт /api/data не найден. Проверьте URL worker и деплой.');
    }
    if (res.statusCode == 401) {
      throw Exception('401: Не авторизован. Войдите снова.');
    }
    throw Exception('Ошибка ${res.statusCode}: ${res.body}');
  }

  Future<http.Response> save(Map<String, dynamic> data) {
    return _api.put('/api/data', {'data': data});
  }
}
