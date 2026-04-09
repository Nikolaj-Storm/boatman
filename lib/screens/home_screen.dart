import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/screens/chat_screen.dart';
import 'package:boatman/screens/boat_profile_screen.dart';
import 'package:boatman/screens/knowledge_base_screen.dart';
import 'package:boatman/screens/settings_screen.dart';
import 'package:boatman/screens/onboarding_screen.dart';
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
        // Restart button (top-left, for testing)
        leading: IconButton(
          icon: const Icon(Icons.restart_alt, size: 22),
          tooltip: 'Restart onboarding (testing)',
          onPressed: () => _confirmRestart(context, appState),
        ),
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

  void _confirmRestart(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Setup?'),
        content: const Text(
          'This will reset the app and take you back to the onboarding screen. '
          'Your data (manuals, skill packs) will be preserved, but you\'ll '
          're-enter your boat details.\n\n'
          'This is a testing feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doRestart(appState);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _doRestart(AppState appState) {
    appState.resetOnboarding();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
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
