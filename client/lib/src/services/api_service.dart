import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 默认后端地址
  // 模拟器用 10.0.2.2:3000，真机改为你PC的局域网IP
  // 当前配置: 192.168.1.5 是你的 PC WiFi IP (若连以太网则用 192.168.5.2)
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const Duration _requestTimeout = Duration(seconds: 20);

  final String baseUrl;
  String? _token;

  ApiService({String? baseUrl})
      : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultBaseUrl);

  static String get defaultBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://127.0.0.1:3000/api';
  }

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
          value, 'baseUrl', 'API base URL must be an absolute URL');
    }
    return normalized.endsWith('/api') ? normalized : '$normalized/api';
  }

  Uri get serverUri {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/api$'), ''));
  }

  Uri webSocketUri(String path, {Map<String, String>? queryParameters}) {
    final server = serverUri;
    return server.replace(
      scheme: server.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: queryParameters,
    );
  }

  String resolveServerUrl(String path) {
    final absolute = Uri.tryParse(path);
    if (absolute != null && absolute.hasScheme) return absolute.toString();
    return serverUri.resolve(path.startsWith('/') ? path : '/$path').toString();
  }

  // ===================== Token 管理 =====================

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isLoggedIn => _token != null;
  String get token => _token ?? '';

  // ===================== HTTP 封装 =====================

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// 通用响应处理 — 支持 Map 和 List
  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode >= 400) {
      final msg = decoded is Map ? decoded['error'] : '请求失败';
      throw ApiException(msg?.toString() ?? '请求失败 (${response.statusCode})');
    }
    return decoded;
  }

  Future<dynamic> _get(String path) async {
    final resp = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(_requestTimeout);
    return _handleResponse(resp);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _handleResponse(resp);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final resp = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _handleResponse(resp);
  }

  Future<dynamic> _delete(String path) async {
    final resp = await http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(_requestTimeout);
    return _handleResponse(resp);
  }

  // ===================== 认证 API =====================

  Future<Map<String, dynamic>> register(
      String username, String password, String? nickname) async {
    final result = await _post('/auth/register', {
      'username': username,
      'password': password,
      'nickname': nickname ?? username,
    }) as Map<String, dynamic>;
    if (result['token'] != null) {
      await saveToken(result['token'] as String);
    }
    return result;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final result = await _post('/auth/login', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    if (result['token'] != null) {
      await saveToken(result['token'] as String);
    }
    return result;
  }

  Future<Map<String, dynamic>> getProfile() async =>
      await _get('/auth/me') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProfile(
          Map<String, dynamic> fields) async =>
      await _put('/auth/profile', fields) as Map<String, dynamic>;

  // ===================== AI 朋友 API =====================

  Future<List<dynamic>> getAiFriends() async =>
      await _get('/ai-friends') as List<dynamic>;

  Future<Map<String, dynamic>> createAiFriend(
          Map<String, dynamic> data) async =>
      await _post('/ai-friends', data) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getAiFriendDetail(String id) async =>
      await _get('/ai-friends/$id') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateAiFriend(
          String id, Map<String, dynamic> data) async =>
      await _put('/ai-friends/$id', data) as Map<String, dynamic>;

  Future<void> deleteAiFriend(String id) async {
    await _delete('/ai-friends/$id');
  }

  // ===================== 聊天 API =====================

  Future<List<dynamic>> getChatSessions() async =>
      await _get('/chat/sessions') as List<dynamic>;

  Future<Map<String, dynamic>> createChatSession(
          String friendId, String friendType) async =>
      await _post('/chat/sessions', {
        'friendId': friendId,
        'friendType': friendType
      }) as Map<String, dynamic>;

  Future<List<dynamic>> getMessages(String sessionId,
          {int limit = 50, int offset = 0}) async =>
      await _get(
              '/chat/sessions/$sessionId/messages?limit=$limit&offset=$offset')
          as List<dynamic>;

  Future<Map<String, dynamic>> sendMessage(String sessionId, String content,
          {String contentType = 'text', String? voiceUrl}) async =>
      await _post('/chat/sessions/$sessionId/messages', {
        'content': content,
        'contentType': contentType,
        'voiceUrl': voiceUrl,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getAiReply(String sessionId) async =>
      await _post('/chat/sessions/$sessionId/ai-reply', {})
          as Map<String, dynamic>;

  Stream<Map<String, dynamic>> streamAiReply(String sessionId) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/chat/sessions/$sessionId/stream'),
    )
      ..headers.addAll(_headers)
      ..body = '{}';
    final response = await request.send().timeout(_requestTimeout);

    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
      final message = decoded is Map ? decoded['error'] : null;
      throw ApiException(message?.toString() ?? 'Unable to start AI reply');
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk.replaceAll('\r\n', '\n');
      final events = buffer.split('\n\n');
      buffer = events.removeLast();
      for (final event in events) {
        final payload = event
            .split('\n')
            .where((line) => line.startsWith('data:'))
            .map((line) => line.substring(5).trim())
            .join('\n');
        if (payload.isEmpty) continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            yield Map<String, dynamic>.from(decoded);
          }
        } on FormatException {
          throw ApiException('Received an invalid streaming response');
        }
      }
    }
  }

  // ===================== 社交 API =====================

  Future<List<dynamic>> searchUsers(String query) async =>
      await _get('/social/search?q=${Uri.encodeComponent(query)}')
          as List<dynamic>;

  Future<List<dynamic>> getFriends() async =>
      await _get('/social/friends') as List<dynamic>;

  Future<Map<String, dynamic>> sendFriendRequest(String friendId) async =>
      await _post('/social/friends/request', {'friendId': friendId})
          as Map<String, dynamic>;

  Future<List<dynamic>> getPendingRequests() async =>
      await _get('/social/friends/requests') as List<dynamic>;

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async =>
      await _post('/social/friends/accept/$requestId', {})
          as Map<String, dynamic>;

  // ===================== AI 军师 API =====================

  Future<Map<String, dynamic>> getAdvice(String sessionId, String aiFriendId,
          {String? context}) async =>
      await _post('/advisor/advice', {
        'sessionId': sessionId,
        'aiFriendId': aiFriendId,
        if (context != null) 'context': context,
      }) as Map<String, dynamic>;

  // ===================== LLM 配置 API =====================

  Future<Map<String, dynamic>> getLlmConfig() async =>
      await _get('/llm/config') as Map<String, dynamic>;

  Future<void> updateLlmConfig(Map<String, dynamic> config) async {
    await _put('/llm/config', config);
  }

  // ===================== 语音上传 =====================

  /// 上传语音文件，返回 {voiceUrl, filename, size, duration}
  Future<Map<String, dynamic>> uploadVoice(String filePath,
      {String? duration}) async {
    final uri = Uri.parse('$baseUrl/upload/voice');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${_token ?? ''}';
    request.files.add(await http.MultipartFile.fromPath('audio', filePath));
    if (duration != null) {
      request.fields['duration'] = duration;
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(body['error'] as String? ?? '上传失败');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
