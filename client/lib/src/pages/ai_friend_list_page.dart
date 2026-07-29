import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_friend_provider.dart';
import '../models/ai_friend.dart';
import '../theme.dart';
import 'create_ai_friend_page.dart';
import 'chat_page.dart';

class AiFriendListPage extends StatefulWidget {
  const AiFriendListPage({super.key});

  static void navigateToCreate(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreateAiFriendPage()));
  }

  @override
  State<AiFriendListPage> createState() => _AiFriendListPageState();
}

class _AiFriendListPageState extends State<AiFriendListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiFriendProvider>().loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiFriendProvider>();
    final cs = Theme.of(context).colorScheme;

    if (provider.loading && provider.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.friends.isEmpty) {
      return _EmptyState(cs: cs);
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadFriends(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: provider.friends.length,
        itemBuilder: (_, i) => _FriendTile(
          friend: provider.friends[i],
          onTap: () => _startChat(provider.friends[i]),
          onLongPress: () => _showActions(provider.friends[i], provider),
        ),
      ),
    );
  }

  void _startChat(AiFriend friend) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
              friendId: friend.id,
              friendName: friend.name,
              friendType: 'ai',
              friendAvatar: friend.avatarUrl),
        ));
  }

  void _showActions(AiFriend friend, AiFriendProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateAiFriendPage(friend: friend),
                ),
              );
            },
          ),
          if (friend.id.isEmpty)
            ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑资料'),
                onTap: () {
                  Navigator.pop(context);
                }),
          ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('开始聊天'),
              onTap: () {
                Navigator.pop(context);
                _startChat(friend);
              }),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              provider.deleteFriend(friend.id);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final AiFriend friend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FriendTile(
      {required this.friend, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final genderIcon = friend.gender == 'male'
        ? Icons.male
        : friend.gender == 'female'
            ? Icons.female
            : Icons.person;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer,
                      cs.primaryContainer.withAlpha(120)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Text(friend.name[0],
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(friend.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16))),
                        const SizedBox(width: 6),
                        Icon(genderIcon, size: 16, color: cs.onSurfaceVariant),
                        if (friend.ageRange != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(friend.ageRange!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSecondaryContainer)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        friend.personality ?? '一个有趣的AI朋友',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ]),
              ),
              Icon(Icons.chevron_right,
                  color: cs.onSurfaceVariant.withAlpha(100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyState({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(30)),
          child: Icon(Icons.person_add_alt,
              size: 48, color: cs.primary.withAlpha(150)),
        ),
        const SizedBox(height: 20),
        Text('还没有AI朋友',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        const SizedBox(height: 8),
        Text('点击下方按钮，创建你的第一个AI朋友吧',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
