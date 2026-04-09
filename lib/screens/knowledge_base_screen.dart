import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/skill_pack_service.dart';
import 'package:boatman/services/manual_import_service.dart';
import 'package:boatman/services/manual_search_service.dart';
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
  Map<String, int> _categoryCounts = {};
  List<ManualMeta> _manuals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final catCounts = await db.getChunkCountByCategory();
    final manuals = await db.getManualMetas();
    setState(() {
      _totalChunks = chunks;
      _loadedSources = sources;
      _categoryCounts = catCounts;
      _manuals = manuals;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storage,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$_totalChunks chunks | ${_loadedSources.length} packs | ${_manuals.length} manuals',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              if (_categoryCounts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _categoryCounts.entries.map((e) {
                    return Chip(
                      avatar: Icon(_categoryIcon(e.key), size: 14),
                      label: Text('${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Skill Packs', icon: Icon(Icons.auto_fix_high)),
            Tab(text: 'My Manuals', icon: Icon(Icons.description)),
            Tab(text: 'Find Online', icon: Icon(Icons.search)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSkillPacksTab(),
              _buildManualsTab(),
              _buildSearchTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // TAB 1: Skill Packs
  // ═══════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════
  // TAB 2: My Manuals (imported PDFs / text)
  // ═══════════════════════════════════════════════

  Widget _buildManualsTab() {
    return Column(
      children: [
        // Import buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importPdf,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import PDF/TXT'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importPasteText,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste Text'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ),
        ),
        // Manual list
        Expanded(
          child: _manuals.isEmpty
              ? _buildEmptyManualsState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _manuals.length,
                  itemBuilder: (context, index) {
                    final manual = _manuals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(_categoryIcon(manual.category),
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(manual.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${manual.chunkCount} sections | ${manual.category} | ${_formatDate(manual.importedAt)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'view') _viewManualChunks(manual);
                            if (action == 'delete') _deleteManual(manual);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'view', child: Text('View Sections')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => _viewManualChunks(manual),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyManualsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No Manuals Imported Yet',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Import your engine manual, boat manual, or equipment docs.\n'
              'They\'ll be chunked and indexed for offline AI search.\n\n'
              'Supports: PDF (text-based), TXT, Markdown',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TAB 3: Find Online (Shore mode web search)
  // ═══════════════════════════════════════════════

  Widget _buildSearchTab() {
    final appState = context.watch<AppState>();
    final boat = appState.activeBoat;

    if (!appState.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Shore Mode Required',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Switch to Shore mode to search for and download manuals.\n'
                'Downloaded content is stored locally for offline use.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final searchService = ManualSearchService();
    final suggestions = boat != null ? searchService.getSuggestions(boat) : <ManualSearchSuggestion>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Custom search bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search for manuals (e.g., "Yanmar 3GM30F service manual")',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {}, // Will be wired to actual search
            ),
          ),
          onSubmitted: (query) => _webSearch(query),
        ),
        const SizedBox(height: 20),

        // Auto-generated suggestions based on boat profile
        if (suggestions.isNotEmpty) ...[
          Text('Suggested for Your Boat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Based on your boat profile, these manuals might be useful:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_categoryIcon(s.category),
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(s.title),
                  subtitle: Text('Search: "${s.query}"',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.search),
                  onTap: () => _webSearch(s.query),
                ),
              )),
        ],

        if (suggestions.isEmpty) ...[
          const SizedBox(height: 40),
          Icon(Icons.search, size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Search for manuals online.\nResults can be saved to your local knowledge base.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════

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
      MaterialPageRoute(builder: (_) => _ChunkViewScreen(
        title: pack.name,
        category: pack.category,
      )),
    );
  }

  Future<void> _importPdf() async {
    // Ask for category first
    final category = await _pickCategory();
    if (category == null) return;

    final db = context.read<DatabaseService>();
    final importService = ManualImportService();

    final result = await importService.pickAndImport(
      db: db,
      category: category,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      if (result.success) await _loadStats();
    }
  }

  Future<void> _importPasteText() async {
    final result = await showDialog<_PasteResult>(
      context: context,
      builder: (context) => const _PasteTextDialog(),
    );

    if (result == null) return;

    final db = context.read<DatabaseService>();
    final importService = ManualImportService();

    final importResult = await importService.importText(
      db: db,
      text: result.text,
      displayName: result.name,
      category: result.category,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importResult.message),
          backgroundColor: importResult.success ? Colors.green : Colors.red,
        ),
      );
      if (importResult.success) await _loadStats();
    }
  }

  void _viewManualChunks(ManualMeta manual) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ChunkViewScreen(
        title: manual.displayName,
        sourceId: manual.sourceId,
      )),
    );
  }

  Future<void> _deleteManual(ManualMeta manual) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Manual?'),
        content: Text('Remove "${manual.displayName}" and all its indexed content?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = context.read<DatabaseService>();
    final importService = ManualImportService();
    await importService.deleteManual(db, manual.sourceId);
    await _loadStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${manual.displayName}" deleted')),
      );
    }
  }

  Future<void> _webSearch(String query) async {
    final searchService = ManualSearchService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Searching...'),
          ],
        ),
      ),
    );

    final results = await searchService.search(query);

    if (mounted) {
      Navigator.of(context).pop();
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found. Try different search terms.')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SearchResultsScreen(
            query: query,
            results: results,
            onImport: (text, name, category) async {
              final db = context.read<DatabaseService>();
              final importService = ManualImportService();
              final result = await importService.importText(
                db: db,
                text: text,
                displayName: name,
                category: category,
              );
              await _loadStats();
              return result;
            },
          ),
        ),
      );
    }
  }

  Future<String?> _pickCategory() async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('What type of manual?'),
        children: [
          _categoryOption(context, 'diesel', 'Engine Manual'),
          _categoryOption(context, 'electrical', 'Electrical / Electronics'),
          _categoryOption(context, 'plumbing', 'Plumbing / Water System'),
          _categoryOption(context, 'hydraulics', 'Hydraulics / Steering'),
          _categoryOption(context, 'rigging', 'Rigging / Sails'),
          _categoryOption(context, 'fiberglass', 'Hull / Structure'),
          _categoryOption(context, 'general', 'General / Other'),
        ],
      ),
    );
  }

  Widget _categoryOption(BuildContext context, String value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Row(
        children: [
          Icon(_categoryIcon(value), size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'diesel' => Icons.engineering,
      'electrical' => Icons.bolt,
      'plumbing' => Icons.plumbing,
      'seamanship' => Icons.sailing,
      'fiberglass' => Icons.build,
      'rigging' => Icons.settings,
      'safety' => Icons.health_and_safety,
      'diagnostics' => Icons.troubleshoot,
      'hydraulics' => Icons.compress,
      'corrosion' => Icons.shield,
      'general' => Icons.handyman,
      _ => Icons.folder,
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════
// Paste Text Dialog
// ═══════════════════════════════════════════════

class _PasteResult {
  final String text;
  final String name;
  final String category;
  const _PasteResult({required this.text, required this.name, required this.category});
}

class _PasteTextDialog extends StatefulWidget {
  const _PasteTextDialog();

  @override
  State<_PasteTextDialog> createState() => _PasteTextDialogState();
}

class _PasteTextDialogState extends State<_PasteTextDialog> {
  final _nameController = TextEditingController();
  final _textController = TextEditingController();
  String _category = 'general';

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste Manual Content'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Manual Name',
                  hintText: 'e.g., Yanmar 3GM30F Service Manual',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'diesel', child: Text('Engine')),
                  DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                  DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                  DropdownMenuItem(value: 'hydraulics', child: Text('Hydraulics')),
                  DropdownMenuItem(value: 'rigging', child: Text('Rigging')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Paste manual text here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                minLines: 5,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty || _textController.text.isEmpty) return;
            Navigator.pop(context, _PasteResult(
              text: _textController.text,
              name: _nameController.text,
              category: _category,
            ));
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Chunk Viewer (reused for skill packs and manuals)
// ═══════════════════════════════════════════════

class _ChunkViewScreen extends StatefulWidget {
  final String title;
  final String? category;
  final String? sourceId;

  const _ChunkViewScreen({required this.title, this.category, this.sourceId});

  @override
  State<_ChunkViewScreen> createState() => _ChunkViewScreenState();
}

class _ChunkViewScreenState extends State<_ChunkViewScreen> {
  List<KnowledgeChunk> _chunks = [];

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    final db = context.read<DatabaseService>();
    List<KnowledgeChunk> chunks;
    if (widget.sourceId != null) {
      // View by source (specific manual)
      final maps = await db.db.query(
        'knowledge_chunks',
        where: 'source_id = ?',
        whereArgs: [widget.sourceId],
        orderBy: 'chunk_index ASC',
      );
      chunks = maps.map((m) => KnowledgeChunk.fromMap(m)).toList();
    } else if (widget.category != null) {
      chunks = await db.getChunksByCategory(widget.category!);
    } else {
      chunks = [];
    }
    setState(() => _chunks = chunks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_chunks.length} sections',
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
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
                    title: Text(chunk.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (chunk.tags.isNotEmpty) chunk.tags,
                        '${chunk.content.length} chars',
                      ].join(' | '),
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

// ═══════════════════════════════════════════════
// Web Search Results Screen
// ═══════════════════════════════════════════════

class _SearchResultsScreen extends StatelessWidget {
  final String query;
  final List<ManualSearchResult> results;
  final Future<ManualImportResult> Function(String text, String name, String category) onImport;

  const _SearchResultsScreen({
    required this.query,
    required this.results,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results: $query')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final r = results[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                r.isPdf ? Icons.picture_as_pdf : Icons.web,
                color: r.isPdf ? Colors.red : Colors.blue,
              ),
              title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.snippet.isNotEmpty)
                    Text(r.snippet, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  Text(r.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => _fetchAndImport(context, r),
                style: ElevatedButton.styleFrom(minimumSize: const Size(60, 36)),
                child: const Text('Save'),
              ),
              isThreeLine: r.snippet.isNotEmpty,
            ),
          );
        },
      ),
    );
  }

  Future<void> _fetchAndImport(BuildContext context, ManualSearchResult result) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Downloading and indexing...'),
          ],
        ),
      ),
    );

    final searchService = ManualSearchService();
    final text = await searchService.fetchPageText(result.url);

    if (context.mounted) Navigator.of(context).pop();

    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not extract text from this page.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Import the fetched text
    final importResult = await onImport(text, result.title, 'general');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importResult.message),
          backgroundColor: importResult.success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
