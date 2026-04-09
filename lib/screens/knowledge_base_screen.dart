import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/skill_pack_service.dart';
import 'package:boatman/models/app_state.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _totalChunks = 0;
  List<String> _loadedSources = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final db = context.read<DatabaseService>();
    final chunks = await db.getChunkCount();
    final sources = await db.getLoadedSources();
    setState(() {
      _totalChunks = chunks;
      _loadedSources = sources;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.storage,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '$_totalChunks knowledge chunks loaded',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                '${_loadedSources.length} sources',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Skill Packs', icon: Icon(Icons.auto_fix_high)),
            Tab(text: 'My Manuals', icon: Icon(Icons.description)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSkillPacksTab(),
              _buildManualsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillPacksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: SkillPackService.availablePacks.map((pack) {
        final isLoaded = _loadedSources.contains(pack.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLoaded
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Icon(
                isLoaded ? Icons.check : Icons.download,
                color: isLoaded ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(pack.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(pack.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: isLoaded
                ? IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _viewSkillPack(pack),
                  )
                : ElevatedButton(
                    onPressed: () => _loadSkillPack(pack),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
                    child: const Text('Load'),
                  ),
            onTap: isLoaded ? () => _viewSkillPack(pack) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManualsTab() {
    final appState = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            appState.isOnline
                ? 'Import Your Manuals'
                : 'Go to Shore Mode to Import',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            appState.isOnline
                ? 'Upload PDF manuals for your specific equipment.\n'
                  'They\'ll be indexed and available offline.'
                : 'Switch to Shore mode to import manuals while you have connectivity.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (appState.isOnline)
            ElevatedButton.icon(
              onPressed: _importManual,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import PDF Manual'),
            ),
        ],
      ),
    );
  }

  Future<void> _loadSkillPack(SkillPack pack) async {
    final db = context.read<DatabaseService>();
    final skillPackService = context.read<SkillPackService>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading skill pack...'),
          ],
        ),
      ),
    );

    await skillPackService.loadSkillPack(pack, db);
    await _loadStats();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pack.name} loaded successfully')),
      );
    }
  }

  void _viewSkillPack(SkillPack pack) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SkillPackViewScreen(pack: pack),
      ),
    );
  }

  void _importManual() {
    // TODO: Implement PDF import with file_picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF import coming soon — use skill packs for now')),
    );
  }
}

class _SkillPackViewScreen extends StatefulWidget {
  final SkillPack pack;

  const _SkillPackViewScreen({required this.pack});

  @override
  State<_SkillPackViewScreen> createState() => _SkillPackViewScreenState();
}

class _SkillPackViewScreenState extends State<_SkillPackViewScreen> {
  List<KnowledgeChunk> _chunks = [];

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    final db = context.read<DatabaseService>();
    final chunks = await db.getChunksByCategory(widget.pack.category);
    setState(() => _chunks = chunks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.name),
      ),
      body: _chunks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chunks.length,
              itemBuilder: (context, index) {
                final chunk = _chunks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      chunk.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${chunk.content.length} chars',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: MarkdownBody(data: chunk.content),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
