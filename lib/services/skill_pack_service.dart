import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';

class SkillPackService {
  static const _uuid = Uuid();

  static final List<SkillPack> availablePacks = [
    SkillPack(
      id: 'marine_diesel_engines',
      name: 'Marine Diesel Engines',
      description: 'Troubleshooting, maintenance, and repair of marine diesel engines. '
          'Covers cooling systems, fuel systems, electrical starting, and common failures.',
      category: 'diesel',
      filename: 'marine_diesel_engines.md',
    ),
    SkillPack(
      id: 'marine_electrical_systems',
      name: 'Marine Electrical Systems',
      description: 'DC electrical systems, batteries, wiring, alternators, and '
          'troubleshooting with a multimeter. Includes shore power and charging.',
      category: 'electrical',
      filename: 'marine_electrical_systems.md',
    ),
    SkillPack(
      id: 'marine_plumbing_water_systems',
      name: 'Marine Plumbing & Water Systems',
      description: 'Through-hulls, seacocks, head maintenance, fresh water systems, '
          'bilge pumps, and emergency leak repair procedures.',
      category: 'plumbing',
      filename: 'marine_plumbing_water_systems.md',
    ),
  ];

  /// Load a skill pack from assets, chunk it, and save to database
  Future<int> loadSkillPack(SkillPack pack, DatabaseService db) async {
    // Check if already loaded
    final loadedSources = await db.getLoadedSources();
    if (loadedSources.contains(pack.id)) {
      return 0; // Already loaded
    }

    // Load markdown from assets
    final markdown = await rootBundle.loadString('assets/skill_packs/${pack.filename}');

    // Chunk the markdown by sections
    final chunks = _chunkMarkdown(markdown, pack);

    // Save to database
    await db.saveChunks(chunks);

    return chunks.length;
  }

  /// Load all available skill packs
  Future<Map<String, int>> loadAllSkillPacks(DatabaseService db) async {
    final results = <String, int>{};
    for (final pack in availablePacks) {
      final count = await loadSkillPack(pack, db);
      results[pack.id] = count;
    }
    return results;
  }

  /// Chunk a markdown document by headings (## and ###)
  List<KnowledgeChunk> _chunkMarkdown(String markdown, SkillPack pack) {
    final chunks = <KnowledgeChunk>[];
    final lines = markdown.split('\n');

    String currentTitle = pack.name;
    final currentContent = StringBuffer();
    int chunkIndex = 0;

    for (final line in lines) {
      if (line.startsWith('## ') || line.startsWith('### ')) {
        // Save previous chunk if it has content
        if (currentContent.toString().trim().isNotEmpty) {
          chunks.add(KnowledgeChunk(
            id: _uuid.v4(),
            sourceId: pack.id,
            sourceType: 'skill_pack',
            category: pack.category,
            title: currentTitle,
            content: currentContent.toString().trim(),
            chunkIndex: chunkIndex++,
          ));
        }
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
        currentContent.clear();
      } else {
        currentContent.writeln(line);
      }
    }

    // Save final chunk
    if (currentContent.toString().trim().isNotEmpty) {
      chunks.add(KnowledgeChunk(
        id: _uuid.v4(),
        sourceId: pack.id,
        sourceType: 'skill_pack',
        category: pack.category,
        title: currentTitle,
        content: currentContent.toString().trim(),
        chunkIndex: chunkIndex,
      ));
    }

    // If chunks are too large (>1000 chars), split them further
    final refinedChunks = <KnowledgeChunk>[];
    int finalIndex = 0;
    for (final chunk in chunks) {
      if (chunk.content.length > 1500) {
        final subChunks = _splitLargeChunk(chunk, pack, finalIndex);
        refinedChunks.addAll(subChunks);
        finalIndex += subChunks.length;
      } else {
        refinedChunks.add(KnowledgeChunk(
          id: chunk.id,
          sourceId: chunk.sourceId,
          sourceType: chunk.sourceType,
          category: chunk.category,
          title: chunk.title,
          content: chunk.content,
          chunkIndex: finalIndex++,
        ));
      }
    }

    return refinedChunks;
  }

  /// Split a large chunk into smaller pieces at paragraph boundaries
  List<KnowledgeChunk> _splitLargeChunk(
    KnowledgeChunk chunk,
    SkillPack pack,
    int startIndex,
  ) {
    final paragraphs = chunk.content.split('\n\n');
    final subChunks = <KnowledgeChunk>[];
    final buffer = StringBuffer();
    int partNum = 1;

    for (final para in paragraphs) {
      if (buffer.length + para.length > 1200 && buffer.isNotEmpty) {
        subChunks.add(KnowledgeChunk(
          id: _uuid.v4(),
          sourceId: pack.id,
          sourceType: 'skill_pack',
          category: pack.category,
          title: '${chunk.title} (Part $partNum)',
          content: buffer.toString().trim(),
          chunkIndex: startIndex + subChunks.length,
        ));
        buffer.clear();
        partNum++;
      }
      buffer.writeln(para);
      buffer.writeln();
    }

    if (buffer.toString().trim().isNotEmpty) {
      subChunks.add(KnowledgeChunk(
        id: _uuid.v4(),
        sourceId: pack.id,
        sourceType: 'skill_pack',
        category: pack.category,
        title: '${chunk.title} (Part $partNum)',
        content: buffer.toString().trim(),
        chunkIndex: startIndex + subChunks.length,
      ));
    }

    return subChunks;
  }
}
