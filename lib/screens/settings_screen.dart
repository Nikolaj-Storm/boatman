import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Model section
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.psychology,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('AI Model',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Status'),
                trailing: Chip(
                  label: Text(
                    appState.isModelLoaded ? 'Mock Mode (Dev)' : 'Not Loaded',
                  ),
                  backgroundColor: appState.isModelLoaded
                      ? Colors.orange.shade100
                      : Colors.red.shade100,
                ),
              ),
              ListTile(
                title: const Text('Download Model'),
                subtitle: const Text('Qwen3 1.7B (~1.2 GB) — recommended for most devices'),
                trailing: const Icon(Icons.download),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Model download will be available when connected to internet (Shore mode)'),
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'In development mode, the app uses mock AI responses. '
                  'Download a GGUF model to enable real on-device AI inference.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Appearance
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.palette,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Appearance',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Theme'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {appState.themeMode},
                  onSelectionChanged: (modes) {
                    appState.setThemeMode(modes.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Storage
        _StorageCard(),
        const SizedBox(height: 12),

        // About
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('About',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              const Divider(),
              const ListTile(
                title: Text('Boatman'),
                subtitle: Text('v0.1.0 — Offline AI Handyman for Sailors'),
              ),
              const ListTile(
                title: Text('AI Engine'),
                subtitle: Text('Powered by NobodyWho (on-device inference)'),
              ),
              const ListTile(
                title: Text('License'),
                subtitle: Text('Free and open source'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _StorageCard extends StatefulWidget {
  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> {
  int _chunkCount = 0;
  List<String> _sources = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = context.read<DatabaseService>();
    final count = await db.getChunkCount();
    final sources = await db.getLoadedSources();
    setState(() {
      _chunkCount = count;
      _sources = sources;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.storage,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Storage',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Knowledge Chunks'),
            trailing: Text('$_chunkCount', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('Loaded Sources'),
            trailing: Text('${_sources.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (_sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _sources.map((s) => Chip(
                  label: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
