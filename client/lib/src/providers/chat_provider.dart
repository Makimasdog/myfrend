import 'package:flutter/foundation.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  List<ChatSession> _sessions = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _loading = false;
  String? _error;

  ChatProvider(this._api);

  List<ChatSession> get sessions => _sessions;
  bool get loading => _loading;
  String? get error => _error;

  List<ChatMessage> getMessages(String sessionId) => _messages[sessionId] ?? [];

  Future<void> loadSessions() async {
    _loading = true;
    notifyListeners();

    try {
      final data = await _api.getChatSessions();
      _sessions = data
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }

    _loading = false;
    notifyListeners();
  }

  Future<ChatSession?> getOrCreateSession(
      String friendId, String friendType) async {
    try {
      final data = await _api.createChatSession(friendId, friendType);
      final session = ChatSession.fromJson(data);
      // 检查是否已存在
      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx >= 0) {
        _sessions[idx] = session;
      } else {
        _sessions.insert(0, session);
      }
      notifyListeners();
      return session;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadMessages(String sessionId) async {
    try {
      final data = await _api.getMessages(sessionId);
      _messages[sessionId] = data
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<ChatMessage?> sendMessage(String sessionId, String content,
      {String contentType = 'text', String? voiceUrl}) async {
    try {
      final data = await _api.sendMessage(sessionId, content,
          contentType: contentType, voiceUrl: voiceUrl);
      final userMsg = data['userMessage'] as Map<String, dynamic>?;
      if (userMsg != null) {
        final msg = ChatMessage.fromJson(userMsg);
        _messages.putIfAbsent(sessionId, () => []);
        _messages[sessionId]!.add(msg);
        notifyListeners();
        return msg;
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
    return null;
  }

  Future<ChatMessage?> getAiReply(String sessionId) async {
    try {
      final data = await _api.getAiReply(sessionId);
      final aiMsg = data['aiMessage'] as Map<String, dynamic>?;
      if (aiMsg != null) {
        final msg = ChatMessage.fromJson(aiMsg);
        _messages.putIfAbsent(sessionId, () => []);
        _messages[sessionId]!.add(msg);
        notifyListeners();
        return msg;
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
    return null;
  }

  /// 添加流式消息（正在接收中）
  void addStreamingMessage(String sessionId, String tempId, String text) {
    _messages.putIfAbsent(sessionId, () => []);
    // Remove previous temp message with same ID
    _messages[sessionId]!.removeWhere((m) => m.id == tempId);
    _messages[sessionId]!.add(ChatMessage(
      id: tempId,
      sessionId: sessionId,
      senderId: 'ai',
      senderType: 'ai',
      content: text,
      contentType: 'text',
    ));
    notifyListeners();
  }

  /// 更新流式消息
  void updateStreamingMessage(String sessionId, String tempId, String text) {
    final msgs = _messages[sessionId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == tempId);
    if (idx >= 0) {
      msgs[idx] = ChatMessage(
        id: tempId,
        sessionId: sessionId,
        senderId: 'ai',
        senderType: 'ai',
        content: text,
        contentType: 'text',
      );
      notifyListeners();
    }
  }

  /// 完成流式消息（标记为非临时）
  void finalizeStreamingMessage(String sessionId, String tempId) {
    // Keep the message as-is, no special flag needed
  }

  void replaceStreamingMessage(
      String sessionId, String tempId, ChatMessage message) {
    final messages = _messages[sessionId];
    if (messages == null) {
      _messages[sessionId] = [message];
    } else {
      final index = messages.indexWhere((item) => item.id == tempId);
      if (index >= 0) {
        messages[index] = message;
      } else if (!messages.any((item) => item.id == message.id)) {
        messages.add(message);
      }
    }
    notifyListeners();
  }

  void removeMessage(String sessionId, String id) {
    _messages[sessionId]?.removeWhere((message) => message.id == id);
    notifyListeners();
  }
}
