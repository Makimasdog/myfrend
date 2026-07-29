import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_session.dart';
import '../theme.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ChatProvider>().loadSessions());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    if (p.sessions.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(30)),
            child: Icon(Icons.chat_bubble_outline,
                size: 48, color: cs.primary.withAlpha(150)),
          ),
          const SizedBox(height: 20),
          Text('还没有聊天记录',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('去创建一个AI朋友开始聊天吧',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () => p.loadSessions(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: p.sessions.length,
        itemBuilder: (_, i) => _SessionTile(
            session: p.sessions[i], onTap: () => _open(p.sessions[i])),
      ),
    );
  }

  void _open(ChatSession s) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
              friendId: s.friendId,
              friendName: s.friendName ?? '未知',
              friendType: s.friendType,
              friendAvatar: s.friendAvatar,
              sessionId: s.id),
        ));
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: cs.primaryContainer,
          child: Text((session.friendName ?? '?')[0],
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ),
        if (session.friendType == 'ai')
          Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2)),
                child:
                    const Icon(Icons.smart_toy, size: 10, color: Colors.white),
              )),
      ]),
      title: Text(session.friendName ?? '未知',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        session.lastMessage ?? '开始聊天',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
      trailing: session.lastMessageAt != null
          ? Text(_formatTime(session.lastMessageAt!),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
          : null,
      onTap: onTap,
    );
  }

  String _formatTime(String dt) {
    try {
      return dt.substring(11, 16);
    } catch (_) {
      return '';
    }
  }
}
