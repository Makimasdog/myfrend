import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/ai_friend_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../theme.dart';
import '../widgets/voice_recorder.dart';
import '../widgets/voice_player.dart';
import '../pages/voice_call_page.dart';
import '../providers/auth_provider.dart';
import '../pages/voice_call_page.dart';
import '../services/api_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendType;
  final String? friendAvatar;
  final String? sessionId;

  const ChatPage({super.key, required this.friendId, required this.friendName, required this.friendType, this.friendAvatar, this.sessionId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _starters = [
    '你今天过得怎么样？',
    '最近有什么好玩的事吗？',
    '周末有什么计划？',
    '推荐一部你最近看的电影吧',
    '你觉得什么是最理想的放松方式？',
    '如果你能去任何地方旅行，会去哪里？',
  ];

  Widget _buildStarters(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('开始聊天吧...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _starters.map((s) => ActionChip(
          label: Text(s, style: TextStyle(fontSize: 13, color: cs.primary)),
          backgroundColor: cs.primaryContainer.withAlpha(80),
          side: BorderSide.none,
          onPressed: () { _msgCtrl.text = s; _send(); },
        )).toList()),
      ]),
    );
  }

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  String? _sid;
  bool _replying = false;
  bool _showScrollBtn = false;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset > 200) {
        if (!_showScrollBtn) setState(() => _showScrollBtn = true);
      } else if (_showScrollBtn) setState(() => _showScrollBtn = false);
    });
  }

  Future<void> _init() async {
    final chat = context.read<ChatProvider>();
    String? sid = widget.sessionId;
    if (sid == null) {
      final s = await chat.getOrCreateSession(widget.friendId, widget.friendType);
      sid = s?.id;
    }
    if (sid != null && mounted) { setState(() => _sid = sid); await chat.loadMessages(sid); _scrollToBottom(); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sid == null) return;
    _msgCtrl.clear();

    final chat = context.read<ChatProvider>();
    await chat.sendMessage(_sid!, text);
    _scrollToBottom();

    if (widget.friendType == 'ai') {
      setState(() => _replying = true);
      _streamAiReply(text);
    }
  }

  Future<void> _streamAiReply(String userMessage) async {
    if (_sid == null) return;
    final chat = context.read<ChatProvider>();
    final api = ApiService();
    final uri = Uri.parse('http://192.168.1.5:3000/api/chat/sessions/$_sid/stream');
    final token = context.read<AuthProvider>().token;

    try {
      final request = http.Request('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'content': userMessage});

      final streamedResp = await request.send();
      final stream = streamedResp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String fullText = '';
      String? tempMsgId;

      await for (final line in stream) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6);
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (data['token'] != null) {
            fullText += data['token'] as String;
            // Update or create the streaming bubble
            if (tempMsgId == null) {
              tempMsgId = 'streaming_${DateTime.now().millisecondsSinceEpoch}';
              chat.addStreamingMessage(_sid!, tempMsgId, fullText);
            } else {
              chat.updateStreamingMessage(_sid!, tempMsgId, fullText);
            }
            _scrollToBottom();
          }
          if (data['done'] == true) {
            if (tempMsgId != null) {
              chat.finalizeStreamingMessage(_sid!, tempMsgId);
            }
            _extractMemoriesAfterStream(api, userMessage, fullText);
          }
          if (data['error'] != null) {
            chat.addStreamingMessage(_sid!, 'error_${DateTime.now().millisecondsSinceEpoch}', '[Error: ${data['error']}]');
          }
        } catch (_) {}
      }
    } catch (e) {
      // Fallback to non-streaming
      await chat.getAiReply(_sid!);
    }

    if (mounted) setState(() => _replying = false);
    _scrollToBottom();
  }

  void _extractMemoriesAfterStream(ApiService api, String userMsg, String aiReply) {
    // Memory extraction happens server-side, nothing needed here
  }

  void _onVoiceDone(Map<String, dynamic> result) {
    final voiceUrl = result['voiceUrl'] as String?;
    if (voiceUrl != null && _sid != null) {
      final chat = context.read<ChatProvider>();
      chat.sendMessage(_sid!, voiceUrl, contentType: 'voice', voiceUrl: voiceUrl);
      _scrollToBottom();
      if (widget.friendType == 'ai') {
        setState(() => _replying = true);
        chat.getAiReply(_sid!).then((_) { if (mounted) { setState(() => _replying = false); _scrollToBottom(); } });
      }
    }
  }

  void _showAdvisor() {
    if (_sid == null) return;
    final afProvider = context.read<AiFriendProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg))),
      builder: (ctx) => _AdvisorSheet(sessionId: _sid!, friends: afProvider.friends),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose(); _scrollCtrl.dispose(); _focusNode.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = _sid != null ? chat.getMessages(_sid!) : <ChatMessage>[];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primaryContainer, cs.primaryContainer.withAlpha(120)]), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.friendName[0], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.primary)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.friendName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.friendType == 'ai' ? (_replying ? '正在输入...' : 'AI 朋友') : '在线', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ])),
        ]),
        actions: [
          if (widget.friendType == 'ai')
            IconButton(icon: const Icon(Icons.call, color: AppTheme.success), tooltip: 'Voice Call', onPressed: () {
              final auth = context.read<AuthProvider>();
              Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallPage(token: auth.token, friendId: widget.friendId, friendName: widget.friendName)));
            }),
          if (widget.friendType == 'human')
            IconButton(icon: Icon(Icons.lightbulb_outline, color: AppTheme.accent), tooltip: 'AI军师', onPressed: _showAdvisor),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _sid == null ? const Center(child: CircularProgressIndicator()) : GestureDetector(
            onTap: () => _focusNode.unfocus(),
            child: Stack(children: [
              messages.isEmpty ? _buildStarters(cs) : ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: messages.length,
                itemBuilder: (_, i) => _Bubble(msg: messages[i], cs: cs, friendName: widget.friendName)),
              if (_showScrollBtn) Positioned(bottom: 8, right: 8, child: FloatingActionButton.small(heroTag: 'scroll_down', onPressed: _scrollToBottom, child: const Icon(Icons.keyboard_arrow_down))),
            ]),
          ),
        ),
        if (_replying) Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Text('对方正在输入...', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))])),
        _InputBar(ctrl: _msgCtrl, focusNode: _focusNode, onSend: _send, onVoiceUploaded: _onVoiceDone, cs: cs),
      ]),
    );
  }
}

String _formatMsgTime(String dt) { try { final t = DateTime.parse(dt); return '${t.hour.toString().padLeft(2,"0")}:${t.minute.toString().padLeft(2,"0")}'; } catch (_) { return ''; } }

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final ColorScheme cs;
  final String friendName;
  const _Bubble({required this.msg, required this.cs, required this.friendName});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isUserMessage;

    // Voice message
    if (msg.contentType == 'voice' && msg.voiceUrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!isMe) ...[CircleAvatar(radius: 15, backgroundColor: cs.primaryContainer, child: Text(friendName[0], style: TextStyle(fontSize: 12, color: cs.primary))), const SizedBox(width: 8)],
          VoicePlayerBubble(voiceUrl: msg.voiceUrl!, isMe: isMe),
          if (isMe) const SizedBox(width: 8),
        ]),
      );
    }

    // Text message
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (!isMe) ...[CircleAvatar(radius: 15, backgroundColor: cs.primaryContainer, child: Text(friendName[0], style: TextStyle(fontSize: 12, color: cs.primary))), const SizedBox(width: 8)],
        Flexible(child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: isMe ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(msg.content, style: TextStyle(fontSize: 15, color: isMe ? cs.onPrimary : cs.onSurface, height: 1.4)), if (msg.createdAt != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_formatMsgTime(msg.createdAt!), style: TextStyle(fontSize: 10, color: isMe ? cs.onPrimary.withAlpha(120) : cs.onSurfaceVariant.withAlpha(160))))]),
        )),
        if (isMe) const SizedBox(width: 8),
      ]),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Function(Map<String, dynamic>) onVoiceUploaded;
  final ColorScheme cs;
  const _InputBar({required this.ctrl, required this.focusNode, required this.onSend, required this.onVoiceUploaded, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(color: cs.surface, boxShadow: AppTheme.shadowSm(cs)),
      child: SafeArea(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          VoiceRecordButton(api: ApiService(), onUploaded: onVoiceUploaded),
          Expanded(child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
            child: TextField(controller: ctrl, focusNode: focusNode, maxLines: null, textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: '输入消息...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onSubmitted: (_) => onSend()),
          )),
          const SizedBox(width: 4),
          Container(width: 42, height: 42, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white), onPressed: onSend)),
        ]),
      ),
    );
  }
}

class _AdvisorSheet extends StatefulWidget {
  final String sessionId;
  final List<dynamic> friends;
  const _AdvisorSheet({required this.sessionId, required this.friends});
  @override
  State<_AdvisorSheet> createState() => _AdvisorSheetState();
}

class _AdvisorSheetState extends State<_AdvisorSheet> {
  String? _selectedId;
  String? _advice;
  bool _loading = false;
  final _ctxCtrl = TextEditingController();

  Future<void> _getAdvice() async {
    if (_selectedId == null) return;
    setState(() => _loading = true);
    try {
      final svc = ApiService();
      final result = await svc.getAdvice(widget.sessionId, _selectedId!, context: _ctxCtrl.text);
      if (mounted) setState(() { _advice = result['advice'] as String?; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _advice = '获取建议失败: $e'; _loading = false; });
    }
  }

  @override
  void dispose() { _ctxCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
      builder: (_, scrollCtrl) => Padding(padding: const EdgeInsets.all(20), child: ListView(controller: scrollCtrl, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16), Text('🧠 AI 军师', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
        Text('选一个AI朋友帮你分析聊天，给出建议', style: TextStyle(color: cs.onSurfaceVariant)), const SizedBox(height: 16),
        if (widget.friends.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('还没有AI朋友，先去创建一个吧')))
        else Wrap(spacing: 8, children: widget.friends.map((f) => ChoiceChip(label: Text(f.name ?? ''), selected: _selectedId == f.id, onSelected: (_) => setState(() => _selectedId = f.id), avatar: CircleAvatar(child: Text(f.name?[0] ?? '?')))).toList()),
        const SizedBox(height: 12),
        TextField(controller: _ctxCtrl, maxLines: 2, decoration: InputDecoration(hintText: '描述一下当前聊天的情况（可选）...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: (_selectedId == null || _loading) ? null : _getAdvice, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('获取建议'))),
        if (_advice != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cs.primaryContainer.withAlpha(80), borderRadius: BorderRadius.circular(AppTheme.radiusMd)), child: Text(_advice!, style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurface)))],
      ])));
  }
}
