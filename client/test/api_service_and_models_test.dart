import 'package:flutter_test/flutter_test.dart';
import 'package:myfrends/src/models/ai_friend.dart';
import 'package:myfrends/src/models/chat_message.dart';
import 'package:myfrends/src/services/api_service.dart';

void main() {
  group('ApiService URL configuration', () {
    test('normalizes an API base URL', () {
      final api = ApiService(baseUrl: 'https://api.example.test/');

      expect(api.baseUrl, 'https://api.example.test/api');
      expect(api.serverUri.toString(), 'https://api.example.test');
    });

    test('builds secure WebSocket and upload URLs', () {
      final api = ApiService(baseUrl: 'https://api.example.test/api');

      expect(api.webSocketUri('/ws/chat', queryParameters: {'token': 'abc'}),
          Uri.parse('wss://api.example.test/ws/chat?token=abc'));
      expect(api.resolveServerUrl('/uploads/voice.m4a'),
          'https://api.example.test/uploads/voice.m4a');
    });

    test('rejects a relative API URL', () {
      expect(() => ApiService(baseUrl: '/api'), throwsArgumentError);
    });
  });

  group('API models', () {
    test('parses stored AI friend configuration JSON', () {
      final friend = AiFriend.fromJson({
        'id': 'friend-1',
        'owner_id': 'user-1',
        'name': 'Nova',
        'extra_config': '{"interests":["music"],"tone":"warm"}',
        'is_active': 1,
      });

      expect(friend.extraConfig, {
        'interests': ['music'],
        'tone': 'warm',
      });
      expect(friend.isActive, isTrue);
    });

    test('parses chat message read state from SQLite values', () {
      final message = ChatMessage.fromJson({
        'id': 'message-1',
        'session_id': 'session-1',
        'sender_id': 'user-1',
        'sender_type': 'user',
        'content': 'Hello',
        'is_read': 1,
      });

      expect(message.isUserMessage, isTrue);
      expect(message.isRead, isTrue);
      expect(message.contentType, 'text');
    });
  });
}
