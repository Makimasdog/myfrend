import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api);

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  String get token => _api.token;
  bool get isLoggedIn => _api.isLoggedIn && _user != null;

  Future<void> init() async {
    await _api.loadToken();
    if (_api.isLoggedIn) {
      try {
        final data = await _api.getProfile();
        _user = User.fromJson(data);
      } catch (_) {
        await _api.clearToken();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.login(username, password);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password, String nickname) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.register(username, password, nickname);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final data = await _api.updateProfile(fields);
    _user = User.fromJson(data);
    notifyListeners();
  }
}
