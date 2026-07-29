import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'chat_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _searchCtrl = TextEditingController();
  late final ApiService _api;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final f = await _api.getFriends();
      final r = await _api.getPendingRequests();
      if (mounted) {
        setState(() {
          _friends = _convert(f);
          _requests = _convert(r);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _convert(List<dynamic> list) =>
      list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await _api.searchUsers(q);
      if (mounted) setState(() => _searchResults = _convert(r));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('搜索失败: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await _api.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('好友请求已发送')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _accept(String requestId) async {
    try {
      await _api.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已接受好友请求')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: '搜索用户...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, size: 20),
                onPressed: _search),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onSubmitted: (_) => _search(),
        ),
      ),

      Expanded(
        child: DefaultTabController(
          length: 3,
          child: Column(children: [
            const TabBar(
                tabs: [Tab(text: '发现'), Tab(text: '好友'), Tab(text: '请求')]),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(children: [
                      _SearchTab(results: _searchResults, onAdd: _sendRequest),
                      _FriendTab(
                          friends: _friends, onChat: (f) => _startChat(f)),
                      _RequestTab(requests: _requests, onAccept: _accept),
                    ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _startChat(Map<String, dynamic> friend) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
              friendId: friend['id'] ?? '',
              friendName: friend['nickname'] ?? friend['username'] ?? '',
              friendType: 'human',
              friendAvatar: friend['avatar_url']),
        ));
  }
}

class _SearchTab extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(String) onAdd;
  const _SearchTab({required this.results, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (results.isEmpty) {
      return Center(
          child: Text('搜索找到新朋友', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text((results[i]['nickname'] ?? '?')[0])),
        title: Text(results[i]['nickname'] ?? results[i]['username'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(results[i]['bio'] ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: FilledButton.tonal(
            onPressed: () => onAdd(results[i]['id']), child: const Text('添加')),
      ),
    );
  }
}

class _FriendTab extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final Function(Map<String, dynamic>) onChat;
  const _FriendTab({required this.friends, required this.onChat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (friends.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, size: 48, color: cs.onSurfaceVariant),
        const SizedBox(height: 12),
        Text('还没有好友', style: TextStyle(color: cs.onSurfaceVariant))
      ]));
    }
    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text((friends[i]['nickname'] ?? '?')[0])),
        title: Text(friends[i]['nickname'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chat_bubble_outline),
        onTap: () => onChat(friends[i]),
      ),
    );
  }
}

class _RequestTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(String) onAccept;
  const _RequestTab({required this.requests, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (requests.isEmpty) {
      return Center(
          child: Text('暂无待处理请求', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text((requests[i]['nickname'] ?? '?')[0])),
        title: Text(requests[i]['nickname'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.check_circle, color: AppTheme.success),
              onPressed: () => onAccept(requests[i]['request_id'] ?? '')),
        ]),
      ),
    );
  }
}
