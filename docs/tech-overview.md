# Boatman - Technology & Language Overview

## Languages Used

| Language | Files | Where |
|----------|------:|-------|
| **Dart** | 21 | `lib/` (screens, services, models, theme), `test/` |
| **Kotlin** | 1 | `android/app/src/main/kotlin/` (MainActivity) |
| **Swift** | 2 | `ios/Runner/AppDelegate.swift`, `ios/RunnerTests/` |
| **Objective-C** | 1 | `ios/Runner/Runner-Bridging-Header.h` (bridging header) |
| **Markdown** | 13 | `README.md`, `BRAINSTORM.md`, 10 skill packs in `assets/skill_packs/` |
| **Mermaid** | 1 | `docs/system-diagram.mmd` |
| **XML** | 7 | Android manifests, resources, styles, drawables |
| **YAML** | 2 | `pubspec.yaml`, `analysis_options.yaml` |
| **JSON** | 2 | iOS asset catalog configs |
| **Kotlin DSL** | 3 | `build.gradle.kts` (root, app, settings) |
| **Storyboard (XIB)** | 2 | iOS launch screen and main storyboard |

---

## Technologies & Frameworks

### Core Platform

| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | 3.29.3+ | Cross-platform UI framework (Android + iOS) |
| **Dart** | >= 3.7.2 | Primary programming language |
| **Material Design 3** | — | UI component system |
| **Cupertino** | — | iOS-native widget support |

### State Management

| Technology | Version | Purpose |
|------------|---------|---------|
| **Provider** | 6.1.2 | Reactive state management via `ChangeNotifier` |

### Data & Storage

| Technology | Version | Purpose |
|------------|---------|---------|
| **SQLite (sqflite)** | 2.3.3 | On-device relational database (`boatman.db`) |
| **shared_preferences** | 2.3.4 | Key-value storage for user settings |
| **path_provider** | 2.1.4 | Platform-aware file system paths |
| **path** | 1.9.0 | File path manipulation |

### Networking & I/O

| Technology | Version | Purpose |
|------------|---------|---------|
| **http** | 1.2.2 | HTTP client for shore-mode web requests |
| **file_picker** | 8.1.6 | Native file picker for manual import (PDF/TXT/MD) |
| **image_picker** | 1.1.2 | Camera capture & gallery photo selection |
| **url_launcher** | 6.3.1 | Open external URLs |

### UI & Rendering

| Technology | Version | Purpose |
|------------|---------|---------|
| **flutter_markdown** | 0.7.4 | Render markdown in chat and knowledge views |
| **cupertino_icons** | 1.0.8 | iOS-style icon set |

### Utilities

| Technology | Version | Purpose |
|------------|---------|---------|
| **uuid** | 4.5.1 | Generate unique IDs for entities |

### Build Systems

| Tool | Version | Platform |
|------|---------|----------|
| **Gradle** | 8.10.2 | Android build (Kotlin DSL) |
| **Xcode** | — | iOS build (xcworkspace + xcodeproj) |
| **Flutter CLI** | — | Cross-platform build orchestration |

### Development & Quality

| Tool | Version | Purpose |
|------|---------|---------|
| **flutter_test** | SDK | Widget & unit testing |
| **flutter_lints** | 5.0.0 | Static analysis & linting rules |

---

## NobodyWho Integration

[NobodyWho](https://github.com/nobodywho-ooo/nobodywho) is an on-device LLM inference engine with a Flutter package. It is the planned AI backbone of Boatman — but is **currently commented out** pending Flutter SDK >= 3.41.6 / Dart >= 3.8.

### Current Status

```yaml
# pubspec.yaml (line 13-14)
# NobodyWho will be added when using Flutter SDK >=3.41.6 (Dart >=3.8)
# nobodywho: ^0.5.2
```

The app runs in **mock mode** — it constructs answers from retrieved knowledge chunks without actual LLM inference.

### Where NobodyWho Is Referenced (24 references across 7 files)

#### 1. `lib/services/ai_service.dart` — Main integration point (8 refs)

This is where NobodyWho will be wired in. The RAG pipeline is fully built; only the final inference call is mocked.

| Line | Context |
|------|---------|
| 7 | `/// AI service wrapping NobodyWho for on-device inference.` |
| 24 | `// TODO: Initialize NobodyWho when model is available` |
| 25 | `// await NobodyWho.init();` |
| 61 | `// Real LLM path: build prompt with context and send to NobodyWho` |
| 73 | `// TODO: Wire up NobodyWho (requires Dart >=3.8 / Flutter >=3.41.6)` |

**What it will do:** Accept the fully assembled RAG prompt (system instructions + boat context + ranked knowledge chunks + conversation history + user question) and stream tokens back to the UI.

#### 2. `lib/services/photo_service.dart` — Vision model support (2 refs)

| Line | Context |
|------|---------|
| 10 | `/// visual description. When NobodyWho vision models are available, will use` |
| 68 | `/// With NobodyWho vision: will use on-device multimodal model (Qwen3-VL + mmproj).` |

**What it will do:** Use a multimodal GGUF model (Qwen3-VL) to analyze photos of boat components, corrosion, wiring, etc. and feed detected observations into the RAG pipeline for targeted repair advice.

#### 3. `lib/services/query_router.dart` — Semantic routing upgrade (1 ref)

| Line | Context |
|------|---------|
| 4 | `/// chunks from the right categories. When NobodyWho is integrated, this can` |

**What it will do:** Replace keyword-based category routing with embedding-based semantic search, using NobodyWho's built-in embedding support for more accurate knowledge retrieval.

#### 4. `lib/screens/settings_screen.dart` — UI acknowledgment (1 ref)

| Line | Context |
|------|---------|
| 135 | `subtitle: Text('Powered by NobodyWho (on-device inference)'),` |

The Settings screen already displays NobodyWho as the AI engine. This is where model download progress and status will surface.

#### 5. `BRAINSTORM.md` — Architecture planning (13 refs)

Extensive planning documentation covering:
- Technology selection rationale (why NobodyWho over alternatives)
- Planned model: **Qwen3 1.7B** (~1.2 GB GGUF) for text, **Qwen3-VL** for vision
- Flutter package integration path (`flutter pub add nobodywho`)
- NobodyWho's native RAG pipeline as alternative to custom embedding search
- Platform compatibility confirmation (Android + iOS)
- Links to official docs, pub.dev package, GitHub, and starter examples

#### 6. `README.md` — Project documentation (5 refs)

Lists NobodyWho in the tech stack, prerequisites, and setup instructions.

#### 7. `docs/system-diagram.mmd` — Architecture diagram (2 refs)

Shows NobodyWho as a future external service and labels AiService as `(Mock / NobodyWho)`.

### Integration Roadmap

```
Current State                          Future State
─────────────                          ────────────
User message                           User message
     │                                      │
QueryRouter (keyword)                  QueryRouter (embeddings via NobodyWho)
     │                                      │
DatabaseService (keyword search)       DatabaseService (vector similarity)
     │                                      │
Prompt assembly                        Prompt assembly
     │                                      │
Mock response (chunk concatenation)    NobodyWho LLM inference (Qwen3 1.7B)
     │                                      │
Simulated streaming (20ms/word)        Real token streaming
     │                                      │
ChatScreen                             ChatScreen
                                            │
                                       PhotoService + Qwen3-VL vision
```

### Planned Models

| Model | Size | Purpose |
|-------|------|---------|
| **Qwen3 1.7B** | ~1.2 GB | Text inference (chat, repair guidance) |
| **Qwen3-VL** | TBD | Vision (photo analysis of boat components) |

### Activation Steps (from README)

1. Uncomment `nobodywho: ^0.5.2` in `pubspec.yaml`
2. Run `flutter pub get`
3. Download a GGUF model file
4. Update `AiService.initialize()` to call `NobodyWho.init()`
5. Replace mock response generation with real inference calls
