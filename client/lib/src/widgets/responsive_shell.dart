import 'package:flutter/material.dart';
import '../theme.dart';

/// 响应式壳 — 手机用 NavigationBar，平板/桌面用 NavigationRail + 侧边栏
class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationInfo> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.appBar,
  });

  /// 是否宽屏（>= 840px）
  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 840;

  @override
  Widget build(BuildContext context) {
    final wide = isWideScreen(context);

    if (wide) {
      return _WideLayout(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }
    return _NarrowLayout(
      currentIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      body: body,
      floatingActionButton: floatingActionButton,
      appBar: appBar,
    );
  }
}

/// 窄屏 — 底部导航
class _NarrowLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationInfo> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const _NarrowLayout({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations.map((d) => NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: d.label,
        )).toList(),
      ),
    );
  }
}

/// 宽屏 — 左侧导航栏
class _WideLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationInfo> destinations;
  final Widget body;
  final Widget? floatingActionButton;

  const _WideLayout({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          Container(
            width: 88,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(right: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 0.5)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Logo
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(Icons.chat_bubble_rounded, color: cs.primary, size: 28),
                ),
                const SizedBox(height: 32),
                // Nav items
                Expanded(
                  child: NavigationRail(
                    selectedIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations.map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          // 主体内容
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// 导航目标信息
class NavigationDestinationInfo {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavigationDestinationInfo({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
