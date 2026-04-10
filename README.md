# Boatman – Offline AI Handyman for Sailors

Boatman is an **offline AI handyman app for sailors** that runs entirely on your device and helps you diagnose problems, perform repairs, and maintain your vessel — even with zero internet at sea. It is also a reusable template for building any offline, on‑device AI assistant using Flutter, RAG, and local LLMs.

---

## How It Works

1. **Shore Mode (Online)**  
   Before departure, tell Boatman about your boat — make, model, engine, and equipment. The app loads relevant skill packs and can (soon) import your specific equipment manuals into a local knowledge base.

2. **Sea Mode (Offline)**  
   At sea with no internet, you ask Boatman anything. The app uses an on‑device language model with retrieval‑augmented generation (RAG) over your boat profile, manuals, and skill packs to provide step‑by‑step repair guidance tailored to your vessel.

---

## Features

- Boat profiling (vessel, engine, electrical, plumbing, electronics)
- On‑device AI chat with contextual, boat‑specific answers
- Pre‑loaded skill packs (diesel engines, electrical systems, plumbing)
- Knowledge base browser with expandable sections
- Additional skill packs for safety triage, diagnostics, hydraulics, corrosion
- Shore/Sea mode toggle for a clear mental model
- Maritime‑optimized UI (large touch targets, high contrast)
- Dark mode support

Planned:

- PDF manual import and automatic chunking into the knowledge base

---

## Tech Stack

- **Framework:** Flutter (Android + iOS)
- **Language:** Dart
- **AI Engine:** [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) for on‑device LLM inference using GGUF models
- **Recommended Model:** Qwen3 1.7B (~1.2 GB) for a good quality/speed trade‑off
- **Database:** SQLite for boat profiles, knowledge chunks, and chat history
- **Pattern:** Retrieval‑Augmented Generation (RAG) over local markdown/manuals + on‑device LLM

The repository contains a complete mobile app: navigation, state management, theming, persistence, and AI services are all wired up so you can fork this as a starting point for your own offline AI assistant.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.29.3 (mock mode only)
- Flutter SDK ≥ 3.41.6 (for NobodyWho / real AI inference)
- Android Studio or Xcode for simulators/emulators

### Run in Simulator (Mock Mode)

```bash
flutter pub get
flutter run
```

By default, Boatman runs in **mock mode** — no AI model download needed. Mock mode returns realistic responses for common marine scenarios (engine overheating, battery issues, freshwater pump problems, etc.) so you can test the full UX quickly.

### Enable Real On‑Device AI (Flutter ≥ 3.41.6)

1. Uncomment `nobodywho: ^0.5.2` in `pubspec.yaml`.  
2. Download a GGUF model (for example, Qwen3 1.7B) to your device.  
3. Wire up `AiService.initialize()` with the local model path.  
4. Build and run on a physical device that meets the minimum specs below.

---

## Project Structure

```text
lib/
  main.dart                 # App entry point

  models/
    app_state.dart          # Global state management
    boat_profile.dart       # Boat/vessel data model
    chat_message.dart       # Chat & session models
    knowledge_chunk.dart    # RAG knowledge chunks

  screens/
    home_screen.dart        # Main tabbed interface
    onboarding_screen.dart  # First-launch boat setup
    chat_screen.dart        # AI chat interface
    boat_profile_screen.dart# Boat details & editing
    knowledge_base_screen.dart # Browse skill packs & manuals
    settings_screen.dart    # Model, theme, storage settings

  services/
    ai_service.dart         # AI inference (mock + NobodyWho)
    database_service.dart   # SQLite operations
    skill_pack_service.dart # Markdown chunking & loading

  theme/
    boatman_theme.dart      # Maritime color palette & typography

widgets/

assets/
  skill_packs/
    marine_diesel_engines.md
    marine_electrical_systems.md
    marine_plumbing_water_systems.md
    safety_triage.md
    diagnostics.md
    hydraulics.md
    corrosion.md

docs/
  ... system architecture diagrams, Mermaid overview, notes
```

---

## Minimum Device Requirements

| Platform | Device Class                | Recommended RAM |
|---------|-----------------------------|-----------------|
| Android | Snapdragon 855+ (2019 or +) | 6 GB+           |
| iOS     | iPhone 11+ (A13 Bionic)     | 4 GB+           |

Lower‑end devices may still run the app, but inference performance will be slower.

---

## Use This as a Template

You can use Boatman as a reference implementation for any offline AI assistant:

- Replace the marine skill packs with your own domain content (field service, industrial maintenance, remote inspections, etc.).
- Swap the boat profile model for your own asset/equipment model.
- Keep the on‑device LLM + RAG pipeline and mobile UI as a foundation.

If you build something cool on top of this, please open an issue or pull request and add a link in a “Built with Boatman” section.

---

## License and Attribution

Boatman is free and open source. You may use, modify, and build commercial or non‑commercial apps based on this project **as long as you provide attribution**:

> “This project is based on Boatman – Offline AI Handyman for Sailors: https://github.com/Nikolaj-Storm/boatman”

If you redistribute the code or binaries, keep a visible link to this repository in your README, documentation, or app “About” screen.
