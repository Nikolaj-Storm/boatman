import 'dart:async';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/query_router.dart';

/// AI service wrapping NobodyWho for on-device inference.
///
/// Uses QueryRouter to classify queries and route them to the right
/// knowledge categories before retrieval. In mock mode, generates
/// realistic responses from the retrieved chunks.
class AiService {
  bool _isInitialized = false;
  bool _useMock = true;
  final QueryRouter _router = QueryRouter();

  bool get isInitialized => _isInitialized;

  /// Initialize the AI engine with a GGUF model file
  Future<void> initialize({
    required String modelPath,
    Function(double)? onProgress,
  }) async {
    // TODO: Initialize NobodyWho when model is available
    // await NobodyWho.init();
    // _model = await Model.load(modelPath: modelPath);
    // _chat = Chat(model: _model, systemPrompt: _systemPrompt);
    _useMock = true;
    _isInitialized = true;
  }

  /// Initialize in mock mode (no model needed — for development)
  void initializeMock() {
    _useMock = true;
    _isInitialized = true;
  }

  /// Generate a response using routed RAG
  ///
  /// 1. Routes the query to relevant categories via QueryRouter
  /// 2. Searches the knowledge base with category-weighted scoring
  /// 3. Builds a prompt with boat context + ranked knowledge
  /// 4. Generates a response (mock or real LLM)
  Future<String> chat({
    required String userMessage,
    required BoatProfile boat,
    required DatabaseService db,
    List<String>? conversationHistory,
  }) async {
    // Step 1: Route the query to relevant knowledge categories
    final routedCategories = _router.route(userMessage);

    // Step 2: Retrieve and rank knowledge chunks using routed categories
    final rankedChunks = await db.routedSearch(userMessage, routedCategories);

    // Step 3: Generate response (mock or real LLM)
    if (_useMock) {
      return _mockResponse(userMessage, rankedChunks, routedCategories, boat);
    }

    // Real LLM path: build prompt with context and send to NobodyWho
    final queryTags = _router.extractTags(userMessage);
    final chunks = rankedChunks.map((r) => r.chunk).toList();
    final prompt = _buildPrompt(
      userMessage: userMessage,
      boat: boat,
      chunks: chunks,
      routedCategories: routedCategories,
      queryTags: queryTags,
      history: conversationHistory,
    );

    // TODO: Wire up NobodyWho (requires Dart >=3.8 / Flutter >=3.41.6)
    // final response = await _chat!.ask(prompt).completed();
    // return response;
    return prompt.isNotEmpty
        ? 'AI model not loaded. Please download a GGUF model in Settings.'
        : '';
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
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  String _buildPrompt({
    required String userMessage,
    required BoatProfile boat,
    required List<KnowledgeChunk> chunks,
    required List<ScoredCategory> routedCategories,
    required List<String> queryTags,
    List<String>? history,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are Boatman, an expert marine mechanic and sailing advisor.');
    buffer.writeln('You help sailors diagnose problems, perform repairs, and maintain their vessels.');
    buffer.writeln();
    buffer.writeln('RESPONSE RULES:');
    buffer.writeln('1. SAFETY FIRST: Start every repair answer with relevant safety warnings (isolation, PPE, risks).');
    buffer.writeln('2. DIAGNOSE BEFORE FIXING: If the user describes a symptom, ask clarifying questions or walk through a diagnostic sequence before jumping to a fix.');
    buffer.writeln('3. STEP-BY-STEP: Always provide numbered step-by-step instructions. Each step should be one clear action.');
    buffer.writeln('4. SPECIFIC TO THEIR BOAT: Reference the vessel information below. Use their specific engine make/model, equipment, etc. when available.');
    buffer.writeln('5. PARTS AND SPECS: If the knowledge base contains part numbers, torque specs, fluid types, or tool sizes for their equipment, include them.');
    buffer.writeln('6. WHEN TO STOP: If the repair is beyond a DIY sailor\'s ability, say so clearly and explain why.');
    buffer.writeln('7. TEMPORARY vs PERMANENT: If at sea, offer a safe temporary fix first, then explain the proper permanent repair for when they reach port.');
    buffer.writeln('8. TOOL LIST: At the start of any repair procedure, list the tools and materials needed.');
    buffer.writeln('9. VERIFICATION: End repair procedures with how to verify the fix worked.');
    buffer.writeln('10. USE THE KNOWLEDGE BASE: Your answers must be grounded in the technical knowledge provided below. Do not invent specs or procedures.');
    buffer.writeln();

    // Routing context — tells the LLM what domains are relevant
    buffer.writeln('=== QUERY ROUTING ===');
    buffer.writeln('Detected domains: ${routedCategories.map((c) => '${c.category}(${c.weight.toStringAsFixed(1)})').join(', ')}');
    if (queryTags.isNotEmpty) {
      buffer.writeln('Sub-topics: ${queryTags.join(', ')}');
    }
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
      for (final msg in history) {
        buffer.writeln(msg);
      }
      buffer.writeln();
    }

    buffer.writeln('=== USER QUESTION ===');
    buffer.writeln(userMessage);

    return buffer.toString();
  }

  /// Mock response that uses routed chunks to generate realistic answers
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

    // If we found relevant chunks, build a response from them
    if (rankedChunks.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.write(boatCtx);

      // Show routing info
      final catSummary = categories
          .where((c) => c.weight > 0.5)
          .map((c) => _categoryLabels[c.category] ?? c.category)
          .take(3)
          .join(', ');
      buffer.writeln('**Domain:** $catSummary\n');

      // Show the most relevant chunks as the "answer"
      final topChunks = rankedChunks.take(3).toList();
      for (int i = 0; i < topChunks.length; i++) {
        final rc = topChunks[i];
        final relevance = rc.score > 8
            ? 'highly relevant'
            : rc.score > 4
                ? 'relevant'
                : 'supplementary';
        buffer.writeln('### ${rc.chunk.title}');
        if (rc.chunk.tags.isNotEmpty) {
          buffer.writeln('_Tags: ${rc.chunk.tags} | Relevance: $relevance (${rc.score.toStringAsFixed(1)})_\n');
        }

        // Show a useful portion of the chunk content
        final content = rc.chunk.content;
        final maxLen = i == 0 ? 800 : 400; // More from the top result
        if (content.length > maxLen) {
          // Try to break at a paragraph boundary
          final cutoff = content.indexOf('\n\n', maxLen ~/ 2);
          buffer.writeln(content.substring(0, cutoff > 0 ? cutoff : maxLen));
          buffer.writeln('\n_...continued in knowledge base_\n');
        } else {
          buffer.writeln(content);
          buffer.writeln();
        }
      }

      if (rankedChunks.length > 3) {
        buffer.writeln('---');
        buffer.writeln('_${rankedChunks.length - 3} additional relevant sections found. '
            'Check the **Knowledge** tab for full details._');
      }

      buffer.writeln('\n_[Mock mode — routing & retrieval active, install GGUF model for AI-synthesized answers]_');
      return buffer.toString();
    }

    // Fallback: no chunks found — give a helpful category-aware message
    return '$boatCtx**$catLabel**\n\n'
        'I searched the knowledge base but didn\'t find a strong match for your question. '
        'This might be because:\n\n'
        '1. The relevant skill pack isn\'t loaded yet — check the **Knowledge** tab\n'
        '2. Try rephrasing with more specific terms (e.g., "impeller replacement" instead of "pump broken")\n'
        '3. Import your equipment\'s manual (PDF) for vessel-specific information\n\n'
        'I routed your query to: ${categories.map((c) => "${c.category}(${c.weight.toStringAsFixed(1)})").join(", ")}\n\n'
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
}
