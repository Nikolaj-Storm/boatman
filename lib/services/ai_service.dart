import 'dart:async';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';

/// AI service wrapping NobodyWho for on-device inference.
///
/// In the simulator/dev environment, this uses a mock implementation.
/// On real devices, it initializes NobodyWho with a GGUF model.
class AiService {
  bool _isInitialized = false;
  bool _useMock = true; // Will be false when NobodyWho model is available

  bool get isInitialized => _isInitialized;

  /// Initialize the AI engine with a GGUF model file
  Future<void> initialize({
    required String modelPath,
    Function(double)? onProgress,
  }) async {
    // TODO: Initialize NobodyWho when model is available
    // final chat = Chat(modelPath);
    //
    // For now, use mock mode for simulator development
    _useMock = true;
    _isInitialized = true;
  }

  /// Initialize in mock mode (no model needed — for development)
  void initializeMock() {
    _useMock = true;
    _isInitialized = true;
  }

  /// Generate a response using RAG (retrieval-augmented generation)
  ///
  /// 1. Searches the knowledge base for relevant chunks
  /// 2. Builds a prompt with boat context + relevant knowledge
  /// 3. Sends to the LLM for response generation
  Future<String> chat({
    required String userMessage,
    required BoatProfile boat,
    required DatabaseService db,
    List<String>? conversationHistory,
  }) async {
    // Step 1: Retrieve relevant knowledge chunks
    final relevantChunks = await db.searchChunks(userMessage);

    // Step 2: Build the prompt with context
    // When NobodyWho is integrated, this prompt goes to the on-device LLM
    final _ = _buildPrompt(
      userMessage: userMessage,
      boat: boat,
      chunks: relevantChunks,
      history: conversationHistory,
    );

    // Step 3: Generate response
    if (_useMock) {
      return _mockResponse(userMessage, relevantChunks, boat);
    }

    // TODO: Real NobodyWho inference (requires Dart >=3.8 / Flutter >=3.41.6)
    // final response = await _chat!.ask(prompt).completed();
    // return response;
    return 'AI model not loaded. Please download a GGUF model in Settings.';
  }

  /// Stream a response token by token
  Stream<String> chatStream({
    required String userMessage,
    required BoatProfile boat,
    required DatabaseService db,
    List<String>? conversationHistory,
  }) async* {
    final response = await chat(
      userMessage: userMessage,
      boat: boat,
      db: db,
      conversationHistory: conversationHistory,
    );

    // Simulate streaming by yielding word by word
    final words = response.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield '${words[i]} ';
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  String _buildPrompt({
    required String userMessage,
    required BoatProfile boat,
    required List<KnowledgeChunk> chunks,
    List<String>? history,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are Boatman, an expert marine mechanic and sailing advisor.');
    buffer.writeln('You help sailors diagnose problems, perform repairs, and maintain their vessels.');
    buffer.writeln('Always prioritize safety. If a repair could be dangerous, warn the user clearly.');
    buffer.writeln('Be practical and step-by-step in your guidance.');
    buffer.writeln();
    buffer.writeln('=== VESSEL INFORMATION ===');
    buffer.writeln(boat.toAiContext());
    buffer.writeln();

    if (chunks.isNotEmpty) {
      buffer.writeln('=== RELEVANT TECHNICAL KNOWLEDGE ===');
      for (final chunk in chunks) {
        buffer.writeln('--- ${chunk.title} (${chunk.sourceId}) ---');
        buffer.writeln(chunk.content);
        buffer.writeln();
      }
    }

    if (history != null && history.isNotEmpty) {
      buffer.writeln('=== CONVERSATION HISTORY ===');
      for (final msg in history) {
        buffer.writeln(msg);
      }
      buffer.writeln();
    }

    buffer.writeln('=== USER QUESTION ===');
    buffer.writeln(userMessage);

    return buffer.toString();
  }

  /// Mock response for simulator development
  String _mockResponse(
    String query,
    List<KnowledgeChunk> chunks,
    BoatProfile boat,
  ) {
    final q = query.toLowerCase();
    final boatCtx = boat.engineMake != null
        ? 'Based on your ${boat.engineSummary}:\n\n'
        : '';

    if (chunks.isNotEmpty) {
      final sourceNames = chunks.map((c) => c.title).toSet().take(3).join(', ');
      return '${boatCtx}I found relevant information in: **$sourceNames**\n\n'
          '${chunks.first.content.substring(0, chunks.first.content.length.clamp(0, 500))}...\n\n'
          '_[Mock mode — install a GGUF model for real AI responses]_';
    }

    if (q.contains('overheat') || q.contains('hot') || q.contains('temperature')) {
      return '$boatCtx**Engine Overheating — Diagnostic Steps:**\n\n'
          '1. **Check raw water intake** — Is the seacock fully open? Any weed or debris blocking the strainer?\n'
          '2. **Inspect the impeller** — This is the #1 cause. Remove the pump cover and check for missing or damaged vanes.\n'
          '3. **Check coolant level** — CAUTION: Do not open the cap while hot. Wait for the engine to cool.\n'
          '4. **Inspect heat exchanger** — Look for zinc anode condition and blockage.\n'
          '5. **Check the exhaust elbow** — Feel for temperature differences that indicate blockage.\n\n'
          '**SAFETY:** Shut down the engine if temperature exceeds the red zone. Running an overheated diesel can cause head gasket failure or seizure.\n\n'
          '_[Mock mode — install a GGUF model for real AI responses]_';
    }

    if (q.contains('battery') || q.contains('voltage') || q.contains('charge')) {
      return '$boatCtx**Battery Troubleshooting:**\n\n'
          '1. Check voltage with a multimeter — fully charged 12V battery should read 12.6-12.8V\n'
          '2. Below 12.4V means the battery needs charging\n'
          '3. Below 12.0V indicates a significantly discharged battery\n'
          '4. Check all terminal connections for corrosion (white/green buildup)\n'
          '5. Clean terminals with a wire brush and apply petroleum jelly\n\n'
          '_[Mock mode — install a GGUF model for real AI responses]_';
    }

    return '${boatCtx}I can help you with that! In full mode (with a downloaded AI model), I would:\n\n'
        '1. Search your vessel-specific manuals and skill packs\n'
        '2. Find relevant troubleshooting steps for your specific equipment\n'
        '3. Provide step-by-step repair guidance with part numbers and specs\n\n'
        'For now in mock mode, try asking about:\n'
        '- Engine overheating\n'
        '- Battery problems\n'
        '- Or any topic covered by loaded skill packs\n\n'
        '_[Mock mode — install a GGUF model for real AI responses]_';
  }
}
