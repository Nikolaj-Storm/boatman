import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/chat_message.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/manual_import_service.dart';
import 'package:boatman/services/query_router.dart';

class DatabaseService {
  Database? _db;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'boatman.db');

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE knowledge_chunks ADD COLUMN tags TEXT DEFAULT ""');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_chunks_tags ON knowledge_chunks(tags)');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS manual_meta (
              source_id TEXT PRIMARY KEY,
              file_name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              category TEXT NOT NULL,
              chunk_count INTEGER NOT NULL,
              imported_at TEXT NOT NULL,
              file_path TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE boat_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        boat_type TEXT,
        make TEXT,
        model TEXT,
        year TEXT,
        hull_material TEXT,
        length_ft TEXT,
        engine_make TEXT,
        engine_model TEXT,
        engine_year TEXT,
        engine_hp TEXT,
        engine_type TEXT,
        fuel_type TEXT,
        battery_type TEXT,
        battery_bank_ah TEXT,
        shore_voltage TEXT,
        has_inverter INTEGER DEFAULT 0,
        has_solar_panels INTEGER DEFAULT 0,
        has_wind_generator INTEGER DEFAULT 0,
        autopilot_make TEXT,
        autopilot_model TEXT,
        chartplotter_make TEXT,
        chartplotter_model TEXT,
        vhf_make TEXT,
        vhf_model TEXT,
        radar_make TEXT,
        head_type TEXT,
        watermaker_make TEXT,
        fresh_water_capacity_gal INTEGER DEFAULT 0,
        fuel_capacity_gal INTEGER DEFAULT 0,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_chunks (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        source_type TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        tags TEXT DEFAULT ""
      )
    ''');

    await db.execute('CREATE INDEX idx_chunks_category ON knowledge_chunks(category)');
    await db.execute('CREATE INDEX idx_chunks_source ON knowledge_chunks(source_id)');
    await db.execute('CREATE INDEX idx_chunks_tags ON knowledge_chunks(tags)');

    await db.execute('''
      CREATE TABLE manual_meta (
        source_id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        category TEXT NOT NULL,
        chunk_count INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        file_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        boat_profile_id TEXT NOT NULL,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_message_at TEXT NOT NULL,
        FOREIGN KEY (boat_profile_id) REFERENCES boat_profiles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
      )
    ''');
  }

  Database get db {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  // Boat profiles
  Future<void> saveBoatProfile(BoatProfile profile) async {
    await db.insert(
      'boat_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BoatProfile>> getBoatProfiles() async {
    final maps = await db.query('boat_profiles');
    return maps.map((m) => BoatProfile.fromMap(m)).toList();
  }

  Future<void> deleteBoatProfile(String id) async {
    await db.delete('boat_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // Knowledge chunks
  Future<void> saveChunks(List<KnowledgeChunk> chunks) async {
    final batch = db.batch();
    for (final chunk in chunks) {
      batch.insert(
        'knowledge_chunks',
        chunk.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<KnowledgeChunk>> getChunksByCategory(String category) async {
    final maps = await db.query(
      'knowledge_chunks',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'chunk_index ASC',
    );
    return maps.map((m) => KnowledgeChunk.fromMap(m)).toList();
  }

  /// Routed search: uses QueryRouter to find the right categories,
  /// then keyword-matches within those categories with weighted scoring.
  Future<List<RankedChunk>> routedSearch(
    String query,
    List<ScoredCategory> routedCategories,
  ) async {
    final keywords = _extractKeywords(query);
    if (keywords.isEmpty && routedCategories.isEmpty) return [];

    final results = <RankedChunk>[];

    // For each routed category, search with boosted relevance
    for (final scored in routedCategories) {
      final categoryChunks = await _searchInCategory(
        scored.category,
        keywords,
        scored.matchedTags,
      );

      for (final chunk in categoryChunks) {
        // Calculate relevance score
        double score = 0;

        // Category weight from router
        score += scored.weight * 2.0;

        // Keyword match density
        final contentLower = chunk.content.toLowerCase();
        for (final kw in keywords) {
          // Count occurrences
          int count = 0;
          int idx = 0;
          while (true) {
            idx = contentLower.indexOf(kw, idx);
            if (idx == -1) break;
            count++;
            idx += kw.length;
          }
          score += count * (kw.length > 5 ? 1.5 : 0.8);
        }

        // Tag match bonus
        if (scored.matchedTags.isNotEmpty && chunk.tags.isNotEmpty) {
          for (final tag in scored.matchedTags) {
            if (chunk.hasTag(tag)) {
              score += 3.0; // Strong bonus for tag match
            }
          }
        }

        // Title match bonus
        final titleLower = chunk.title.toLowerCase();
        for (final kw in keywords) {
          if (titleLower.contains(kw)) {
            score += 2.0; // Title matches are very relevant
          }
        }

        results.add(RankedChunk(chunk: chunk, score: score));
      }
    }

    // Deduplicate by chunk ID, keeping highest score
    final deduped = <String, RankedChunk>{};
    for (final r in results) {
      final existing = deduped[r.chunk.id];
      if (existing == null || r.score > existing.score) {
        deduped[r.chunk.id] = r;
      }
    }

    // Sort by score descending
    final sorted = deduped.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Return top results
    return sorted.take(8).toList();
  }

  /// Simple keyword search fallback (no routing)
  Future<List<KnowledgeChunk>> searchChunks(String query) async {
    final keywords = _extractKeywords(query);
    if (keywords.isEmpty) return [];

    final conditions = keywords
        .map((_) => 'LOWER(content) LIKE ?')
        .join(' OR ');
    final args = keywords.map((k) => '%$k%').toList();

    final maps = await db.query(
      'knowledge_chunks',
      where: conditions,
      whereArgs: args,
      limit: 10,
    );
    return maps.map((m) => KnowledgeChunk.fromMap(m)).toList();
  }

  /// Search within a specific category, optionally filtered by tags
  Future<List<KnowledgeChunk>> _searchInCategory(
    String category,
    List<String> keywords,
    List<String> tags,
  ) async {
    // Build query
    final conditions = <String>['category = ?'];
    final args = <dynamic>[category];

    // Add keyword conditions
    if (keywords.isNotEmpty) {
      final kwConditions = keywords
          .map((_) => '(LOWER(content) LIKE ? OR LOWER(title) LIKE ?)')
          .join(' OR ');
      conditions.add('($kwConditions)');
      for (final kw in keywords) {
        args.add('%$kw%');
        args.add('%$kw%');
      }
    }

    final maps = await db.query(
      'knowledge_chunks',
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 15,
    );
    return maps.map((m) => KnowledgeChunk.fromMap(m)).toList();
  }

  /// Extract meaningful keywords from a query
  List<String> _extractKeywords(String query) {
    // Common stop words to filter out
    const stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'can', 'shall', 'must', 'need',
      'not', 'no', 'nor', 'and', 'but', 'or', 'so', 'yet', 'for',
      'at', 'by', 'in', 'of', 'on', 'to', 'up', 'out', 'off',
      'from', 'into', 'with', 'about', 'after', 'before', 'between',
      'that', 'this', 'these', 'those', 'it', 'its', 'i', 'me', 'my',
      'we', 'our', 'you', 'your', 'he', 'she', 'they', 'them',
      'what', 'which', 'who', 'whom', 'how', 'when', 'where', 'why',
      'all', 'each', 'every', 'both', 'few', 'more', 'most', 'some',
      'any', 'very', 'just', 'also', 'only', 'than', 'too',
      'help', 'problem', 'issue', 'work', 'working', 'broken',
    };

    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ') // keep hyphens for through-hull etc.
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
  }

  Future<int> getChunkCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM knowledge_chunks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getChunkCountByCategory() async {
    final result = await db.rawQuery(
      'SELECT category, COUNT(*) as count FROM knowledge_chunks GROUP BY category',
    );
    final map = <String, int>{};
    for (final row in result) {
      map[row['category'] as String] = row['count'] as int;
    }
    return map;
  }

  Future<List<String>> getLoadedSources() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT source_id FROM knowledge_chunks',
    );
    return result.map((r) => r['source_id'] as String).toList();
  }

  Future<void> deleteChunksBySource(String sourceId) async {
    await db.delete('knowledge_chunks', where: 'source_id = ?', whereArgs: [sourceId]);
  }

  // Manual metadata
  Future<void> saveManualMeta(ManualMeta meta) async {
    await db.insert('manual_meta', meta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ManualMeta>> getManualMetas() async {
    final maps = await db.query('manual_meta', orderBy: 'imported_at DESC');
    return maps.map((m) => ManualMeta.fromMap(m)).toList();
  }

  Future<ManualMeta?> getManualMeta(String sourceId) async {
    final maps = await db.query('manual_meta',
        where: 'source_id = ?', whereArgs: [sourceId]);
    if (maps.isEmpty) return null;
    return ManualMeta.fromMap(maps.first);
  }

  Future<void> deleteManualMeta(String sourceId) async {
    await db.delete('manual_meta', where: 'source_id = ?', whereArgs: [sourceId]);
  }

  /// Wipe all user data — boat profiles, knowledge, manuals, chats.
  /// Used by the restart/reset feature.
  Future<void> wipeAllData() async {
    await db.delete('chat_messages');
    await db.delete('chat_sessions');
    await db.delete('knowledge_chunks');
    await db.delete('manual_meta');
    await db.delete('boat_profiles');
  }

  // Chat sessions
  Future<void> saveChatSession(ChatSession session) async {
    await db.insert(
      'chat_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveChatMessage(String sessionId, ChatMessage message) async {
    await db.insert('chat_messages', {
      ...message.toMap(),
      'session_id': sessionId,
    });
    await db.update(
      'chat_sessions',
      {'last_message_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<ChatSession>> getChatSessions(String boatProfileId) async {
    final maps = await db.query(
      'chat_sessions',
      where: 'boat_profile_id = ?',
      whereArgs: [boatProfileId],
      orderBy: 'last_message_at DESC',
    );
    return maps.map((m) => ChatSession.fromMap(m)).toList();
  }

  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    final maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }
}

/// A knowledge chunk with a relevance score from the search
class RankedChunk {
  final KnowledgeChunk chunk;
  final double score;

  const RankedChunk({required this.chunk, required this.score});
}
