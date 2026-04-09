import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/chat_message.dart';
import 'package:boatman/models/knowledge_chunk.dart';

class DatabaseService {
  Database? _db;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'boatman.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
            chunk_index INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_chunks_category ON knowledge_chunks(category)
        ''');

        await db.execute('''
          CREATE INDEX idx_chunks_source ON knowledge_chunks(source_id)
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
      },
    );
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

  Future<List<KnowledgeChunk>> searchChunks(String query) async {
    // Simple keyword search — will be enhanced with embeddings via NobodyWho
    final keywords = query.toLowerCase().split(' ')
        .where((w) => w.length > 2)
        .toList();
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

  Future<int> getChunkCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM knowledge_chunks');
    return Sqflite.firstIntValue(result) ?? 0;
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
