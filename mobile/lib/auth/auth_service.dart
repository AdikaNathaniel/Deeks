import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  Future<void> bootstrap() async {
    final token = await ApiClient.instance.getToken();
    _isAuthenticated = token != null;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    final res = await ApiClient.instance.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
    await ApiClient.instance.saveToken(res.data['accessToken']);
    _email = res.data['user']['email'];
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await ApiClient.instance.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await ApiClient.instance.saveToken(res.data['accessToken']);
    _email = res.data['user']['email'];
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.clearToken();
    _isAuthenticated = false;
    _email = null;
    notifyListeners();
  }
}
