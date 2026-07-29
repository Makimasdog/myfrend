import 'package:flutter/foundation.dart';
import '../models/ai_friend.dart';
import '../services/api_service.dart';

class AiFriendProvider extends ChangeNotifier {
  final ApiService _api;
  List<AiFriend> _friends = [];
  bool _loading = false;
  String? _error;

  AiFriendProvider(this._api);

  List<AiFriend> get friends => _friends;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadFriends() async {
    _loading = true;
    notifyListeners();

    try {
      final data = await _api.getAiFriends();
      _friends = data
          .map((e) => AiFriend.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }

    _loading = false;
    notifyListeners();
  }

  Future<AiFriend?> createFriend(Map<String, dynamic> data) async {
    try {
      final result = await _api.createAiFriend(data);
      final friend = AiFriend.fromJson(result);
      _friends.insert(0, friend);
      notifyListeners();
      return friend;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<AiFriend?> updateFriend(String id, Map<String, dynamic> data) async {
    try {
      final result = await _api.updateAiFriend(id, data);
      final friend = AiFriend.fromJson(result);
      final index = _friends.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _friends[index] = friend;
      } else {
        _friends.insert(0, friend);
      }
      _error = null;
      notifyListeners();
      return friend;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteFriend(String id) async {
    try {
      await _api.deleteAiFriend(id);
      _friends.removeWhere((f) => f.id == id);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  AiFriend? getFriendById(String id) {
    try {
      return _friends.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
