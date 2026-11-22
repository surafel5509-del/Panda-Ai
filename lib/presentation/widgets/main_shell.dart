import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/voice_studio_screen.dart';

/// App shell with a floating monochrome bottom navigation bar.
/// Tabs: Home · Voice Studio · AI Chat · Library · Settings.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _Tab(icon: Icons.graphic_eq_outlined, activeIcon: Icons.graphic_eq_rounded, label: 'Studio'),
    _Tab(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
    _Tab(icon: Icons.folder_open_outlined, activeIcon: Icons.folder_open_rounded, label: 'Library'),
    _Tab(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  void goToTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            HomeScreen(onNavigate: goToTab),
            const VoiceStudioScreen(),
            const ChatScreen(),
            const LibraryScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: p.inverseBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: p.textPrimary.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(child: _NavItem(tab: _tabs[i], selected: i == _index, onTap: () => goToTab(i))),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.4, end: 0, duration: 400.ms),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({required this.icon, required this.activeIcon, required this.label});
}

class _NavItem extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color fg = selected ? p.inverseText : p.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: 220.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? p.inverseText.withOpacity(0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(selected ? tab.activeIcon : tab.icon, size: 22, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
