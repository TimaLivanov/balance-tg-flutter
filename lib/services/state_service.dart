import 'dart:convert';

import 'api_service.dart';
import '../models/app_state.dart';

class StateService {
  StateService(this._api);
  final ApiService _api;

  /// Загружает состояние аккаунта. Возвращает null если данных ещё нет.
  Future<AppState?> load() async {
    final res = await _api.get('/api/data');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Ошибка загрузки: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['exists'] == true && json['data'] is Map) {
      return AppState.fromJson(Map<String, dynamic>.from(json['data'] as Map));
    }
    return null;
  }

  /// Сохраняет состояние.
  Future<void> save(AppState state) async {
    final res = await _api.put('/api/data', {'data': state.toJson()});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Ошибка сохранения: ${res.statusCode} ${res.body}');
    }
  }
}
