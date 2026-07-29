import 'package:flutter/material.dart';
import '../widgets/responsive_shell.dart';
import 'ai_friend_list_page.dart';
import 'chat_list_page.dart';
import 'community_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _destinations = [
    NavigationDestinationInfo(
        icon: Icons.people_outline, selectedIcon: Icons.people, label: 'AI朋友'),
    NavigationDestinationInfo(
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: '消息'),
    NavigationDestinationInfo(
        icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: '社区'),
    NavigationDestinationInfo(
        icon: Icons.person_outline, selectedIcon: Icons.person, label: '我的'),
  ];

  static const _pages = [
    AiFriendListPage(),
    ChatListPage(),
    CommunityPage(),
    ProfilePage(),
  ];

  static const _titles = ['AI朋友', '消息', '社区', '我的'];

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      currentIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: _destinations,
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'create_ai',
              onPressed: () => AiFriendListPage.navigateToCreate(context),
              icon: const Icon(Icons.add),
              label: const Text('创建AI朋友'),
            )
          : null,
    );
  }
}
