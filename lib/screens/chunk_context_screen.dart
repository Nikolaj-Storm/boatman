import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';

/// Displays a knowledge chunk in context — shows the referenced section
/// highlighted, plus adjacent chunks from the same source in reading order.
/// This lets the user read through a manual section by section.
class ChunkContextScreen extends StatefulWidget {
  final String sourceId;
  final int focusChunkIndex;

  const ChunkContextScreen({
    super.key,
    required this.sourceId,
    required this.focusChunkIndex,
  });

  @override
  State<ChunkContextScreen> createState() => _ChunkContextScreenState();
}

class _ChunkContextScreenState extends State<ChunkContextScreen> {
  List<KnowledgeChunk> _chunks = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChunks() async {
    final db = context.read<DatabaseService>();
    // Load all chunks from this source in order
    final maps = await db.db.query(
      'knowledge_chunks',
      where: 'source_id = ?',
      whereArgs: [widget.sourceId],
      orderBy: 'chunk_index ASC',
    );
    final chunks = maps.map((m) => KnowledgeChunk.fromMap(m)).toList();
    setState(() => _chunks = chunks);

    // Scroll to the focused chunk after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFocused();
    });
  }

  void _scrollToFocused() {
    // Find the focused chunk's position in the list
    final focusIdx = _chunks.indexWhere((c) => c.chunkIndex == widget.focusChunkIndex);
    if (focusIdx < 0 || !_scrollController.hasClients) return;

    // Estimate scroll position (each card ~200px + margins)
    final estimatedOffset = focusIdx * 250.0;
    _scrollController.animateTo(
      estimatedOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceName = widget.sourceId.replaceAll('_', ' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(sourceName),
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _chunks.length,
              itemBuilder: (context, index) {
                final chunk = _chunks[index];
                final isFocused = chunk.chunkIndex == widget.focusChunkIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: isFocused
                      ? BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Card(
                    elevation: isFocused ? 4 : 1,
                    color: isFocused
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header
                          Row(
                            children: [
                              if (isFocused)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('REFERENCED',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              Expanded(
                                child: Text(
                                  chunk.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isFocused ? 18 : 16,
                                    color: isFocused
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (chunk.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(chunk.tags,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ),
                          const SizedBox(height: 12),
                          // Full content
                          MarkdownBody(data: chunk.content),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
