import 'package:http/http.dart' as http;

import 'api_service.dart';

class AuthService {
  AuthService(this._api);
  final ApiService _api;

  Future<http.Response> login(String email, String password) {
    return _api.post('/api/auth/login', {'email': email, 'password': password});
  }

  Future<http.Response> register(String email, String password) {
    return _api.post('/api/auth/register', {'email': email, 'password': password});
  }

  Future<http.Response> me() => _api.get('/api/auth/me');

  Future<http.Response> logout() => _api.post('/api/auth/logout');
}
