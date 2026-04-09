# Boatman

**Offline AI handyman for sailors.** An on-device AI assistant that helps sailors diagnose problems, perform repairs, and maintain their vessels — with zero internet required at sea.

## How It Works

1. **Shore Mode (Online):** Before departure, tell Boatman about your boat — make, model, engine, equipment. The app loads relevant knowledge packs and can import your specific equipment manuals.

2. **Sea Mode (Offline):** At sea with no internet, ask Boatman anything. It uses an on-device language model with RAG (Retrieval-Augmented Generation) to search your boat-specific knowledge base and provide step-by-step repair guidance.

## Features

- Boat profiling (vessel, engine, electrical, plumbing, electronics)
- On-device AI chat with contextual boat-specific answers
- Pre-loaded skill packs (diesel engines, electrical systems, plumbing)
- Knowledge base browser with expandable sections
- PDF manual import (coming soon)
- Shore/Sea mode toggle
- Maritime-optimized UI (large touch targets, high contrast)
- Dark mode support

## Tech Stack

- **Framework:** Flutter (Android + iOS)
- **AI Engine:** [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) (on-device LLM inference, GGUF models)
- **Database:** SQLite (boat profiles, knowledge chunks, chat history)
- **Model:** Qwen3 1.7B recommended (~1.2 GB)

## Getting Started

### Prerequisites
- Flutter SDK >= 3.29.3 (for mock mode)
- Flutter SDK >= 3.41.6 (for NobodyWho / real AI inference)
- Android Studio or Xcode for simulators

### Run in Simulator

```bash
flutter pub get
flutter run
```

The app runs in **mock mode** by default — no AI model download needed. Mock mode provides simulated responses for common marine scenarios (engine overheating, battery issues, etc.) so you can develop and test the full UI flow.

### Enable Real AI (requires Flutter >= 3.41.6)

1. Uncomment `nobodywho: ^0.5.2` in `pubspec.yaml`
2. Download a GGUF model (e.g., Qwen3 1.7B)
3. Wire up `AiService.initialize()` with the model path

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   ├── app_state.dart     # Global state management
│   ├── boat_profile.dart  # Boat/vessel data model
│   ├── chat_message.dart  # Chat & session models
│   └── knowledge_chunk.dart # RAG knowledge chunks
├── screens/
│   ├── home_screen.dart       # Main tabbed interface
│   ├── onboarding_screen.dart # First-launch boat setup
│   ├── chat_screen.dart       # AI chat interface
│   ├── boat_profile_screen.dart # Boat details & edit
│   ├── knowledge_base_screen.dart # Browse skill packs & manuals
│   └── settings_screen.dart   # Model, theme, storage settings
├── services/
│   ├── ai_service.dart        # AI inference (mock + NobodyWho)
│   ├── database_service.dart  # SQLite operations
│   └── skill_pack_service.dart # Markdown chunking & loading
├── theme/
│   └── boatman_theme.dart     # Maritime color palette & typography
└── widgets/

assets/
└── skill_packs/
    ├── marine_diesel_engines.md
    ├── marine_electrical_systems.md
    └── marine_plumbing_water_systems.md
```

## Minimum Device Requirements

| Platform | Device | RAM |
|----------|--------|-----|
| Android | Snapdragon 855+ (2019+) | 6 GB+ |
| iOS | iPhone 11+ (A13 Bionic) | 4 GB+ |

## License

Free and open source.
