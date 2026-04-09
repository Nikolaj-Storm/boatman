import 'dart:async';
import 'dart:io';
import 'package:nobodywho/nobodywho.dart' as nw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/query_router.dart';

/// AI service using NobodyWho for on-device LLM inference.
///
/// Supports:
/// - Chat with a GGUF language model (Qwen3, etc.)
/// - RAG via CrossEncoder reranking of knowledge chunks
/// - Vision via multimodal models (Qwen3-VL + mmproj)
/// - Tool calling for structured operations
/// - Falls back to mock mode if no model is loaded
class AiService {
  bool _isInitialized = false;
  bool _useMock = false;
  final QueryRouter _router = QueryRouter();

  nw.Model? _chatModel;
  nw.Chat? _chat;
  nw.CrossEncoder? _crossEncoder;
  String? _chatModelPath;

  bool get isInitialized => _isInitialized;
  bool get hasModel => _chatModel != null;
  bool get hasCrossEncoder => _crossEncoder != null;
  String? get chatModelPath => _chatModelPath;

  /// Initialize NobodyWho runtime (must be called once at app start)
  static Future<void> initRuntime() async {
    await nw.NobodyWho.init();
  }

  /// Load the chat model from a GGUF file path
  Future<void> loadChatModel({
    required String modelPath,
    Function(String)? onStatus,
  }) async {
    onStatus?.call('Loading model...');

    _chatModel = await nw.Model.load(
      modelPath: modelPath,
      useGpu: true,
    );
    _chatModelPath = modelPath;

    _chat = nw.Chat(
      model: _chatModel!,
      systemPrompt: _systemPrompt,
      contextSize: 4096,
      allowThinking: false,
    );

    _isInitialized = true;
    _useMock = false;
    onStatus?.call('Model loaded');
  }

  /// Load a cross-encoder model for RAG reranking
  Future<void> loadCrossEncoder({required String modelPath}) async {
    _crossEncoder = await nw.CrossEncoder.fromPath(modelPath: modelPath);
  }

  /// Initialize in mock mode (no model needed — for development/testing)
  void initializeMock() {
    _useMock = true;
    _isInitialized = true;
  }

  /// Dispose models and free resources
  void dispose() {
    if (_chatModel != null && !_chatModel!.isDisposed) {
      _chatModel!.dispose();
    }
    if (_crossEncoder != null && !_crossEncoder!.isDisposed) {
      _crossEncoder!.dispose();
    }
    _chatModel = null;
    _chat = null;
    _crossEncoder = null;
    _isInitialized = false;
  }

  /// Generate a response using routed RAG + NobodyWho inference
  Future<String> chat({
    required String userMessage,
    required BoatProfile boat,
    required DatabaseService db,
    List<String>? conversationHistory,
  }) async {
    // Step 1: Route the query
    final routedCategories = _router.route(userMessage);

    // Step 2: Retrieve knowledge chunks
    final rankedChunks = await db.routedSearch(userMessage, routedCategories);

    // Step 3: Rerank with CrossEncoder if available
    List<RankedChunk> finalChunks;
    if (_crossEncoder != null && rankedChunks.isNotEmpty) {
      finalChunks = await _rerankWithCrossEncoder(userMessage, rankedChunks);
    } else {
      finalChunks = rankedChunks;
    }

    // Step 4: Generate response
    if (_useMock || _chat == null) {
      return _mockResponse(userMessage, finalChunks, routedCategories, boat);
    }

    // Build prompt with RAG context and send to NobodyWho
    final queryTags = _router.extractTags(userMessage);
    final chunks = finalChunks.map((r) => r.chunk).toList();
    final prompt = _buildRagPrompt(
      userMessage: userMessage,
      boat: boat,
      chunks: chunks,
      routedCategories: routedCategories,
      queryTags: queryTags,
      history: conversationHistory,
    );

    // Reset context with updated system prompt including RAG context
    await _chat!.resetContext(
      systemPrompt: prompt,
      tools: [],
    );

    // Ask the model
    final response = await _chat!.ask(userMessage).completed();
    return _stripThinkingTags(response);
  }

  /// Stream a response token by token
  Stream<String> chatStream({
    required String userMessage,
    required BoatProfile boat,
    required DatabaseService db,
    List<String>? conversationHistory,
  }) async* {
    if (_useMock || _chat == null) {
      // Mock streaming
      final response = await chat(
        userMessage: userMessage,
        boat: boat,
        db: db,
        conversationHistory: conversationHistory,
      );
      final words = response.split(' ');
      for (int i = 0; i < words.length; i++) {
        yield '${words[i]} ';
        await Future.delayed(const Duration(milliseconds: 20));
      }
      return;
    }

    // Real NobodyWho streaming
    final routedCategories = _router.route(userMessage);
    final rankedChunks = await db.routedSearch(userMessage, routedCategories);

    List<RankedChunk> finalChunks;
    if (_crossEncoder != null && rankedChunks.isNotEmpty) {
      finalChunks = await _rerankWithCrossEncoder(userMessage, rankedChunks);
    } else {
      finalChunks = rankedChunks;
    }

    final queryTags = _router.extractTags(userMessage);
    final chunks = finalChunks.map((r) => r.chunk).toList();
    final prompt = _buildRagPrompt(
      userMessage: userMessage,
      boat: boat,
      chunks: chunks,
      routedCategories: routedCategories,
      queryTags: queryTags,
      history: conversationHistory,
    );

    await _chat!.resetContext(systemPrompt: prompt, tools: []);

    final stream = _chat!.ask(userMessage);
    bool inThinking = false;
    await for (final token in stream) {
      // Filter out <think>...</think> tags from streaming output
      if (token.contains('<think>')) {
        inThinking = true;
        continue;
      }
      if (token.contains('</think>')) {
        inThinking = false;
        continue;
      }
      if (!inThinking) {
        yield token;
      }
    }
  }

  /// Ask a question about a photo using a vision model
  Future<String> askAboutPhoto({
    required String imagePath,
    required String question,
    required String visionModelPath,
    required String mmprojPath,
  }) async {
    final model = await nw.Model.load(
      modelPath: visionModelPath,
      imageIngestion: mmprojPath,
      useGpu: true,
    );

    final chat = nw.Chat(
      model: model,
      systemPrompt: 'You are a marine equipment visual inspector. Identify the component, '
          'assess its condition (good/worn/damaged/failed), describe any visible problems '
          '(corrosion, cracks, leaks, wear), and suggest what system it belongs to. '
          'Be specific and practical.',
      contextSize: 4096,
    );

    final response = await chat.askWithPrompt(nw.Prompt([
      nw.TextPart(question.isEmpty ? 'What do you see? Identify the part and any problems.' : question),
      nw.ImagePart(imagePath),
    ])).completed();

    model.dispose();
    return _stripThinkingTags(response);
  }

  /// Rerank chunks using the CrossEncoder for better relevance
  Future<List<RankedChunk>> _rerankWithCrossEncoder(
    String query,
    List<RankedChunk> chunks,
  ) async {
    if (_crossEncoder == null || chunks.isEmpty) return chunks;

    final documents = chunks.map((c) => c.chunk.content).toList();
    final ranked = await _crossEncoder!.rankAndSort(
      query: query,
      documents: documents,
    );

    // Map back to RankedChunks with cross-encoder scores
    final result = <RankedChunk>[];
    for (final (doc, score) in ranked.take(8)) {
      final original = chunks.firstWhere((c) => c.chunk.content == doc);
      result.add(RankedChunk(chunk: original.chunk, score: score));
    }
    return result;
  }

  /// Build RAG-augmented system prompt
  String _buildRagPrompt({
    required String userMessage,
    required BoatProfile boat,
    required List<KnowledgeChunk> chunks,
    required List<ScoredCategory> routedCategories,
    required List<String> queryTags,
    List<String>? history,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_systemPrompt);
    buffer.writeln();

    buffer.writeln('=== VESSEL INFORMATION ===');
    buffer.writeln(boat.toAiContext());
    buffer.writeln();

    if (chunks.isNotEmpty) {
      buffer.writeln('=== RELEVANT TECHNICAL KNOWLEDGE (ranked by relevance) ===');
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        buffer.writeln('--- [${i + 1}] ${chunk.title} (${chunk.category}/${chunk.sourceId}) ---');
        if (chunk.tags.isNotEmpty) {
          buffer.writeln('Tags: ${chunk.tags}');
        }
        buffer.writeln(chunk.content);
        buffer.writeln();
      }
    }

    if (history != null && history.isNotEmpty) {
      buffer.writeln('=== CONVERSATION HISTORY ===');
      for (final msg in history.take(10)) {
        buffer.writeln(msg);
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Strip <think>...</think> tags from model output
  String _stripThinkingTags(String text) {
    return text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
  }

  /// Core system prompt
  static const _systemPrompt = '''You are Boatman, an expert marine mechanic and sailing advisor.
You help sailors diagnose problems, perform repairs, and maintain their vessels.

RESPONSE RULES:
1. SAFETY FIRST: Start every repair answer with relevant safety warnings (isolation, PPE, risks).
2. DIAGNOSE BEFORE FIXING: If the user describes a symptom, ask clarifying questions or walk through a diagnostic sequence before jumping to a fix.
3. STEP-BY-STEP: Always provide numbered step-by-step instructions. Each step should be one clear action.
4. SPECIFIC TO THEIR BOAT: Reference the vessel information below. Use their specific engine make/model, equipment, etc. when available.
5. PARTS AND SPECS: If the knowledge base contains part numbers, torque specs, fluid types, or tool sizes for their equipment, include them.
6. WHEN TO STOP: If the repair is beyond a DIY sailor's ability, say so clearly and explain why.
7. TEMPORARY vs PERMANENT: If at sea, offer a safe temporary fix first, then explain the proper permanent repair for when they reach port.
8. TOOL LIST: At the start of any repair procedure, list the tools and materials needed.
9. VERIFICATION: End repair procedures with how to verify the fix worked.
10. USE THE KNOWLEDGE BASE: Your answers must be grounded in the technical knowledge provided below. Do not invent specs or procedures.
11. PHOTOS: When the user attaches a photo, analyze what they describe seeing. Guide them to look for specific visual clues.''';

  /// Mock response for when no model is loaded
  String _mockResponse(
    String query,
    List<RankedChunk> rankedChunks,
    List<ScoredCategory> categories,
    BoatProfile boat,
  ) {
    final boatCtx = boat.engineMake != null
        ? 'Based on your **${boat.engineSummary}**:\n\n'
        : '';

    final primaryCat = categories.isNotEmpty ? categories.first.category : 'general';
    final catLabel = _categoryLabels[primaryCat] ?? 'General';
    final hasPhoto = query.contains('[USER ATTACHED PHOTO]') || query.contains('[photo attached]');

    if (hasPhoto && rankedChunks.isEmpty) {
      return '$boatCtx**Photo Received**\n\n'
          'I can see you\'ve attached a photo. To help you best, please tell me:\n\n'
          '1. **What part/component** is shown in the photo?\n'
          '2. **What does the problem look like?** (leak, crack, corrosion, discoloration, missing part)\n'
          '3. **What color** is any fluid, residue, or buildup you see?\n'
          '   - Green/white crusty = electrical corrosion\n'
          '   - Pink/salmon metal = dezincification (brass)\n'
          '   - Dark oily = oil/fuel leak\n'
          '   - White milky = water in oil (head gasket)\n'
          '   - Rust orange = steel corrosion\n'
          '4. **Where on the boat** is this located?\n\n'
          'With a GGUF vision model installed (Qwen3-VL), I can analyze photos directly.\n\n'
          '_[Mock mode — describe what you see for guided diagnosis]_';
    }

    if (rankedChunks.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.write(boatCtx);

      final topChunks = rankedChunks.take(3).toList();
      for (int i = 0; i < topChunks.length; i++) {
        final rc = topChunks[i];
        final chunk = rc.chunk;
        buffer.writeln('### ${chunk.title}');
        buffer.writeln('_From: ${chunk.sourceId.replaceAll("_", " ")} · ${chunk.category}_\n');
        buffer.writeln(chunk.content);
        buffer.writeln();
        buffer.writeln('[REF:${chunk.sourceId}:${chunk.chunkIndex}:Read full section in context →]\n');
      }

      if (rankedChunks.length > 3) {
        buffer.writeln('---');
        buffer.writeln('**Related sections:**\n');
        for (final rc in rankedChunks.skip(3).take(5)) {
          buffer.writeln('- [REF:${rc.chunk.sourceId}:${rc.chunk.chunkIndex}:${rc.chunk.title}] _(${rc.chunk.sourceId.replaceAll("_", " ")})_');
        }
        buffer.writeln();
      }

      buffer.writeln('_[Mock mode — routing & retrieval active, install GGUF model for AI-synthesized answers]_');
      return buffer.toString();
    }

    return '$boatCtx**$catLabel**\n\n'
        'I searched the knowledge base but didn\'t find a strong match for your question. '
        'This might be because:\n\n'
        '1. The relevant skill pack isn\'t loaded yet — check the **Knowledge** tab\n'
        '2. Try rephrasing with more specific terms (e.g., "impeller replacement" instead of "pump broken")\n'
        '3. Import your equipment\'s manual (PDF) for vessel-specific information\n\n'
        '_[Mock mode — install a GGUF model for real AI responses]_';
  }

  static const _categoryLabels = <String, String>{
    'diesel': 'Engine & Propulsion',
    'electrical': 'Electrical Systems',
    'plumbing': 'Plumbing & Water',
    'seamanship': 'Seamanship & Emergency',
    'fiberglass': 'Hull & Fiberglass',
    'rigging': 'Rigging & Sails',
    'safety': 'Safety & Triage',
    'diagnostics': 'Diagnostics',
    'hydraulics': 'Hydraulics & Steering',
    'corrosion': 'Corrosion & Fasteners',
    'general': 'General Maintenance',
  };

  /// Get the path where models should be stored
  static Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Check if a model file exists at the expected path
  static Future<bool> modelExists(String filename) async {
    final dir = await getModelsDirectory();
    return File(p.join(dir, filename)).exists();
  }
}
