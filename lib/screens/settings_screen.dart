import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:boatman/models/app_state.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/ai_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aiService = context.read<AiService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Model section
        _ModelCard(appState: appState, aiService: aiService),
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
                subtitle: Text('Powered by NobodyWho (on-device LLM inference via llama.cpp)'),
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

// ═══════════════════════════════════════════════
// Model Management Card
// ═══════════════════════════════════════════════

class _ModelCard extends StatefulWidget {
  final AppState appState;
  final AiService aiService;

  const _ModelCard({required this.appState, required this.aiService});

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _isLoading = false;
  String _status = '';
  List<_ModelFile> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _scanForModels();
  }

  Future<void> _scanForModels() async {
    final dir = await AiService.getModelsDirectory();
    final modelsDir = Directory(dir);
    if (!await modelsDir.exists()) {
      setState(() => _availableModels = []);
      return;
    }

    final files = await modelsDir
        .list()
        .where((f) => f.path.endsWith('.gguf'))
        .toList();

    final models = <_ModelFile>[];
    for (final f in files) {
      final stat = await f.stat();
      models.add(_ModelFile(
        path: f.path,
        name: p.basename(f.path),
        sizeBytes: stat.size,
      ));
    }
    models.sort((a, b) => a.name.compareTo(b.name));
    setState(() => _availableModels = models);
  }

  Future<void> _importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path;
    if (sourcePath == null) return;

    if (!sourcePath.endsWith('.gguf')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .gguf model file'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Copying model file...';
    });

    final dir = await AiService.getModelsDirectory();
    final destPath = p.join(dir, p.basename(sourcePath));
    await File(sourcePath).copy(destPath);

    await _scanForModels();
    setState(() {
      _isLoading = false;
      _status = 'Model imported: ${p.basename(sourcePath)}';
    });
  }

  Future<void> _loadModel(_ModelFile model) async {
    setState(() {
      _isLoading = true;
      _status = 'Loading ${model.name}...';
    });

    try {
      await widget.aiService.loadChatModel(
        modelPath: model.path,
        onStatus: (s) => setState(() => _status = s),
      );
      widget.appState.setModelLoaded(true);
      setState(() {
        _isLoading = false;
        _status = '${model.name} loaded and ready';
      });
    } catch (e) {
      widget.appState.setModelError(e.toString());
      setState(() {
        _isLoading = false;
        _status = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasModel = widget.aiService.hasModel;

    return Card(
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
                Text('AI Model', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(),

          // Status
          ListTile(
            title: const Text('Status'),
            trailing: Chip(
              label: Text(hasModel ? 'Active' : 'No Model'),
              backgroundColor: hasModel ? Colors.green.shade100 : Colors.orange.shade100,
            ),
          ),

          if (widget.aiService.chatModelPath != null)
            ListTile(
              title: const Text('Loaded Model'),
              subtitle: Text(p.basename(widget.aiService.chatModelPath!)),
              leading: const Icon(Icons.check_circle, color: Colors.green),
            ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),

          if (_status.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_status, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),

          const Divider(),

          // Available models on device
          if (_availableModels.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Models on Device', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._availableModels.map((m) {
              final isLoaded = widget.aiService.chatModelPath == m.path;
              return ListTile(
                leading: Icon(
                  isLoaded ? Icons.check_circle : Icons.circle_outlined,
                  color: isLoaded ? Colors.green : Colors.grey,
                ),
                title: Text(m.name),
                subtitle: Text('${(m.sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB'),
                trailing: isLoaded
                    ? const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    : ElevatedButton(
                        onPressed: _isLoading ? null : () => _loadModel(m),
                        child: const Text('Load'),
                      ),
              );
            }),
            const Divider(),
          ],

          // Import button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importModel,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Import GGUF Model'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Import a GGUF model file from your device.\n'
                  'Recommended: Qwen3-1.7B-Q4_K_M.gguf (~1.2 GB)\n'
                  'Download from HuggingFace before departure.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Storage Card
// ═══════════════════════════════════════════════

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

class _ModelFile {
  final String path;
  final String name;
  final int sizeBytes;

  const _ModelFile({required this.path, required this.name, required this.sizeBytes});
}
