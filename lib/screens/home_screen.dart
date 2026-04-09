import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/screens/chat_screen.dart';
import 'package:boatman/screens/boat_profile_screen.dart';
import 'package:boatman/screens/knowledge_base_screen.dart';
import 'package:boatman/screens/settings_screen.dart';
import 'package:boatman/theme/boatman_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    ChatScreen(),
    BoatProfileScreen(),
    KnowledgeBaseScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sailing, size: 28),
            const SizedBox(width: 8),
            const Text('Boatman'),
            const Spacer(),
            // Shore/Sea mode indicator
            _buildModeChip(appState),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        // Large touch targets for at-sea use
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Ask',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_boat_outlined),
            selectedIcon: Icon(Icons.directions_boat),
            label: 'My Boat',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Knowledge',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(AppState appState) {
    final isShore = appState.mode == AppMode.shore;
    return GestureDetector(
      onTap: () {
        appState.setMode(isShore ? AppMode.sea : AppMode.shore);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isShore ? BoatmanTheme.seafoam : BoatmanTheme.ocean,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isShore ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              isShore ? 'SHORE' : 'SEA',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
