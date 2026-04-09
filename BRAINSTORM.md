# Boatman - Offline Handyman AI for Sailors

## Vision

An offline-capable mobile app that acts as an on-board technical advisor for sailors on small boats. Before departure (while online), the app gathers and stores all relevant technical documentation for the user's specific vessel setup. At sea (offline), sailors can query the app to get guidance on repairs, maintenance, troubleshooting, and general seamanship — powered by a small language model running entirely on-device.

---

## Core Concept: Two Modes of Operation

### 1. Shore Mode (Online - Pre-Departure)
- User profiles their boat (make, model, year, engine, equipment)
- App fetches and indexes relevant technical manuals, service bulletins, parts diagrams
- Content is processed into embeddings and stored in a local vector database
- User can review and curate their knowledge base
- Handyman skill packs are downloaded/updated

### 2. Sea Mode (Offline - At Sea)
- Full functionality with zero internet dependency
- User describes their problem in natural language
- Local LLM queries the on-device vector database (RAG)
- Returns step-by-step guidance, referencing stored manuals
- Combines technical docs with general handyman/mechanical skills

---

## Technology Stack

### Inference Engine: NobodyWho
- **What**: Open-source on-device LLM inference engine (Copenhagen startup, EUPL-licensed)
- **Built on**: llama.cpp
- **Model format**: GGUF
- **GPU acceleration**: Vulkan (Android), Metal (iOS/macOS)
- **Key features**: Text generation, embeddings, RAG, tool calling, conversation-aware context shifting
- **Integrations**: Flutter (pub package), Python, Godot
- **Platforms**: Android (stable), iOS (supported via Flutter — iPhone 11+ with 4GB+ RAM)
- **Language**: Written in Rust, wraps llama.cpp
- **Recommended models**: Qwen3 4B (capable) or Qwen3 0.6B (fast/lightweight)
- **Mobile RAM rule**: Device needs ~2x the model file size in available RAM
- **No CUDA** — Vulkan and Metal only (fine for mobile)

### App Framework: Flutter
- **Why Flutter**:
  - NobodyWho has official Flutter package (`flutter pub add nobodywho`)
  - Cross-platform: Android + iOS from single codebase
  - Strong ecosystem for local storage (SQLite, Hive, Isar)
  - Good offline-first patterns
  - Mature UI toolkit suitable for usability under stress (big buttons, clear text)

### Local Database / Vector Store
- **SQLite** for structured data (boat profiles, equipment registry, maintenance logs)
- **SQLite with vector extensions** or NobodyWho's built-in embedding/RAG for semantic search
- **Options to evaluate**:
  - NobodyWho's native RAG pipeline
  - ObjectBox with vector search
  - SQLite + manual cosine similarity on embeddings

### Recommended Models (GGUF)
| Model | Size | Use Case | Trade-off |
|-------|------|----------|-----------|
| Qwen3 0.6B | ~400MB | Fast responses, low-end devices | Less nuanced answers |
| Qwen3 1.7B | ~1.2GB | Good balance | Mid-range phones |
| Qwen3 4B | ~2.8GB | Best quality | Needs modern phone, slower |
| Embedding model | ~200MB | Document indexing/RAG | Required alongside chat model |

---

## User Data Model: "My Boat" Profile

### Vessel Information
- **Hull**
  - Boat name
  - Make / manufacturer (e.g., Hallberg-Rassy, Beneteau, Jeanneau)
  - Model (e.g., HR 352, Oceanis 38.1)
  - Year built
  - Hull material (fiberglass, wood, steel, aluminum)
  - LOA (length overall), beam, draft
  - Keel type (fin, full, bilge, swing)
  - Displacement

- **Rigging** (if sailboat)
  - Rig type (sloop, cutter, ketch, yawl)
  - Mast material (aluminum, carbon)
  - Standing rigging type/age
  - Furling systems (brand/model)

### Engine / Propulsion
- Engine make (Volvo Penta, Yanmar, Beta Marine, etc.)
- Engine model + serial number
- Horsepower / kW
- Fuel type (diesel, gasoline)
- Transmission type / model
- Propeller type (fixed, folding, feathering)
- Saildrive vs. shaft drive
- Engine hours (current)
- Last service date
- Coolant system type (raw water, freshwater closed)
- Impeller model/size
- Oil type and capacity
- Fuel filter model
- Belt sizes

### Electrical System
- Battery bank configuration (house, start, bow thruster)
- Battery type (AGM, lithium, lead-acid)
- Battery capacity (Ah)
- Charging system (alternator, solar, wind, shore power)
- Shore power voltage (110V/220V)
- Inverter make/model
- Battery charger make/model
- Solar panel wattage/type
- Charge controller type

### Plumbing / Water Systems
- Freshwater tank capacity
- Water pump make/model
- Water heater make/model
- Holding tank capacity
- Head type (manual, electric) + make/model
- Bilge pump(s) - make/model, manual vs. automatic
- Watermaker (if equipped) - make/model

### Navigation & Electronics
- Chartplotter make/model
- VHF radio make/model + MMSI
- AIS (class A/B) make/model
- Radar make/model
- Autopilot make/model
- Wind instruments make/model
- Depth sounder make/model
- GPS antenna

### Safety Equipment
- Life raft (capacity, last service date)
- EPIRB make/model (battery expiry)
- Flares (expiry date)
- Fire extinguishers (count, type, expiry)
- MOB equipment
- First aid kit (last updated)

### Deck Hardware & Sails
- Winch brands/models
- Anchor type/weight + chain length/diameter
- Windlass make/model
- Sail inventory (main, genoa, jib, spinnaker — sailmaker, age)

### Custom Equipment
- User-defined entries for anything else (watermaker, generator, davits, dinghy outboard, etc.)

---

## Handyman Skill Packs (Pre-loaded Knowledge)

Curated knowledge bases that ship with the app (not fetched per-user):

### 1. Marine Diesel Engine Fundamentals
- How diesel engines work (4-stroke cycle)
- Bleeding fuel systems
- Impeller replacement (generic + common brands)
- Oil change procedures
- Coolant system maintenance
- Troubleshooting: won't start, overheating, smoke colors, unusual noises
- Winterization / de-winterization

### 2. Marine Electrical Systems
- 12V/24V DC systems basics
- Battery maintenance and troubleshooting
- Wiring diagnosis (multimeter usage)
- Fuse/breaker troubleshooting
- Alternator basics
- Solar system troubleshooting
- Shore power and galvanic isolation

### 3. Plumbing & Water Systems
- Head maintenance and rebuild
- Bilge pump troubleshooting
- Hose clamp inspection and replacement
- Through-hull valve maintenance
- Freshwater pump troubleshooting
- Water tank sanitization

### 4. Fiberglass & Hull Repair
- Gelcoat repair (chips, cracks, blisters)
- Epoxy basics
- Emergency hull patching
- Rudder bearing inspection
- Keel bolt inspection
- Antifouling basics

### 5. Rigging & Sail Repair
- Emergency sail repair (sail tape, sewing)
- Standing rigging inspection
- Running rigging troubleshooting
- Furler troubleshooting
- Winch service basics
- Turnbuckle and toggle inspection

### 6. Safety & Emergency Procedures
- MOB procedures
- Flooding/sinking response
- Jury rig / dismasting response
- Fire aboard
- Grounding response
- Towing procedures
- Emergency steering
- Distress calling (VHF procedure, DSC)
- First aid basics (marine context)

### 7. Seamanship & Weather
- Anchoring techniques
- Docking under power / sail
- Heavy weather tactics
- Basic weather pattern reading
- Navigation rules (COLREGs basics)
- Tidal considerations

### 8. General Handyman Skills
- Knots and splicing
- Sealant/adhesive selection guide
- Fastener identification (marine grade)
- Corrosion identification and treatment
- Lubrication guide
- Tool usage basics

---

## Content Fetching Strategy (Shore Mode)

### What to Fetch Per User Setup
1. **Engine service manual** (PDF) — specific to make/model
2. **Engine parts list** with diagrams
3. **Equipment user manuals** (autopilot, chartplotter, VHF, etc.)
4. **Service bulletins / known issues** for their specific equipment
5. **Wiring diagrams** (if available for their boat model)
6. **Owner's manual** for the boat model (if available)

### Fetching Sources (prioritized)
1. Manufacturer websites (Volvo Penta, Yanmar, Raymarine, B&G, etc.)
2. Owner forums / community wikis (SailboatOwners.com, CruisersForum, etc.)
3. Archive.org for older manuals
4. Marine equipment databases

### Processing Pipeline
1. Fetch document (PDF, HTML, etc.)
2. Extract text (OCR if needed for scanned PDFs)
3. Chunk into semantic segments (~500 token chunks with overlap)
4. Generate embeddings via on-device embedding model
5. Store chunks + embeddings + metadata in local database
6. Index by equipment type, topic, and relevance

### Storage Budget Estimation
| Content Type | Estimated Size (per boat) |
|---|---|
| Engine manual (chunked text + embeddings) | 50-150 MB |
| Equipment manuals (5-10 devices) | 100-300 MB |
| Boat model specific info | 20-50 MB |
| Skill packs (all 8) | 100-200 MB |
| LLM model (Qwen3 1.7B) | ~1.2 GB |
| Embedding model | ~200 MB |
| **Total estimated** | **~1.7 - 2.1 GB** |

---

## Query Flow (Sea Mode - Offline)

```
User: "My engine is overheating and I see steam from the heat exchanger"

1. Intent classification (LLM)
   → Category: Engine / Cooling System / Overheating

2. Context retrieval (RAG)
   → Pull from: User's engine manual chunks (Volvo Penta D2-40)
   → Pull from: Skill pack "Marine Diesel Fundamentals" → Overheating section
   → Pull from: Any stored service bulletins for their engine

3. Response generation (LLM with retrieved context)
   → Step-by-step diagnosis:
     a) Check raw water intake (seacock open? weed?)
     b) Check impeller (likely culprit if not checked recently)
     c) Check heat exchanger zinc
     d) Check coolant level
   → References specific parts for THEIR engine
   → Includes torque specs, part numbers from their stored manual
   → Warns about safety (hot coolant, burns)

4. Follow-up capability
   → "How do I replace the impeller on my engine?"
   → Pulls step-by-step from their Volvo Penta D2-40 manual
   → Includes tool list, part numbers, diagram references
```

---

## MVP Scope (v0.1)

### In Scope
- [ ] Flutter app (Android + iOS — both supported by NobodyWho Flutter package)
- [ ] Boat profile setup (vessel, engine, key equipment)
- [ ] Pre-loaded skill packs (start with 2-3: diesel engine, electrical, plumbing)
- [ ] On-device LLM chat interface (NobodyWho + Qwen3)
- [ ] Basic RAG pipeline: skill packs embedded and queryable
- [ ] Offline-first architecture
- [ ] Simple, high-contrast UI (usable in cockpit, wet hands, bright sun)

### Out of Scope for MVP
- [ ] Automated web fetching of manuals (manual PDF import instead)
- [ ] Image recognition (photo of broken part → diagnosis)
- [ ] Community knowledge sharing
- [ ] Maintenance scheduling / reminders
- [ ] Parts ordering integration
- [ ] Multi-language support

---

## Feature Roadmap

### v0.1 - "Proof of Concept"
- Basic boat profiling
- 2-3 pre-loaded skill packs
- On-device LLM chat with RAG over skill packs
- Manual PDF import + indexing
- Android + iOS (both supported via NobodyWho Flutter)

### v0.2 - "Shore Prep"
- Automated manual fetching by equipment make/model
- Full boat profile (all categories)
- All 8 skill packs
- Improved RAG with user-specific document retrieval
- Search/browse indexed documents

### v0.3 - "Sea Ready"
- Maintenance log / journal
- Offline parts cross-reference database
- Conversation history with bookmarking
- Emergency procedures quick-access (no chat needed)
- UI polish: large touch targets, night mode (red), high contrast

### v0.4 - "Crew Ready"
- Multi-boat profiles
- Export/share boat knowledge base
- Image attachment to queries (for future vision model support)
- Community skill pack contributions
- Maintenance scheduling with notifications

### v1.0 - "Ship It"
- Stable iOS + Android
- Full automated content pipeline
- Proven RAG accuracy across common boat setups
- App Store / Play Store release
- Offline-first with optional cloud sync for backup

---

## Key Technical Risks & Considerations

### 1. Model Quality vs. Device Constraints
- **Risk**: Small models (0.6B-4B) may give inaccurate technical advice
- **Mitigation**: Heavy RAG reliance (model retrieves, not invents); skill packs are curated by marine professionals; add confidence indicators; always include "consult a professional" disclaimers for safety-critical repairs

### 2. iOS Constraints
- **Risk**: iOS is supported but iPhone 11+ required (4GB+ RAM); older iPhones may be too slow
- **Mitigation**: Clear minimum device requirements in App Store listing; graceful fallback for low-RAM devices (smaller model auto-selection)

### 3. Storage on Mobile Devices
- **Risk**: ~2GB base + user content may be significant on budget phones
- **Mitigation**: Offer model size tiers; allow selective skill pack downloads; efficient embedding storage; clear storage management UI

### 4. RAG Quality for Technical Content
- **Risk**: Chunking technical manuals (with diagrams, tables, part numbers) is error-prone
- **Mitigation**: Custom chunking strategies for manuals; metadata-rich chunks (section headers, equipment tags); user feedback loop to flag bad answers

### 5. Legal / Copyright on Manuals
- **Risk**: Fetching and storing manufacturer manuals may have copyright implications
- **Mitigation**: User-initiated downloads only (they own the equipment); link to official sources; support manual PDF upload; don't redistribute content

### 6. Safety-Critical Advice
- **Risk**: Wrong repair advice at sea could be dangerous
- **Mitigation**: Prominent disclaimers; confidence scoring; always suggest professional help when possible; emergency procedures are curated (not LLM-generated); separate "emergency" section with verified procedures

### 7. Inference Speed on Mobile
- **Risk**: LLM responses could be slow on older/budget devices
- **Mitigation**: Streaming responses; smaller model option; pre-computed common Q&A; optimize prompt lengths

---

## UX Considerations for Maritime Use

### Environmental Constraints
- **Wet hands** → Large touch targets (min 48dp, prefer 64dp+)
- **Bright sunlight** → High contrast mode, dark-on-light with bold text
- **Night sailing** → Red night mode (preserves night vision)
- **Boat motion** → Stable, non-scrolling primary UI; no tiny buttons
- **Stress/emergency** → Quick-access emergency procedures (1 tap)
- **Gloves** → Capacitive-compatible touch, voice input option

### Information Architecture
- **Home screen**: Quick access to Chat, Emergency Procedures, My Boat, Knowledge Base
- **Chat**: Full-screen, large text, streaming responses
- **Emergency**: Red-bordered section, no chat needed — direct procedure cards
- **My Boat**: Equipment registry with quick-tap to "ask about this"
- **Knowledge Base**: Browse fetched manuals and skill packs

---

## Competitive Landscape

| Product | Offline? | AI? | Marine-specific? | Notes |
|---------|----------|-----|-------------------|-------|
| **Boatman (this)** | Yes | Yes (on-device) | Yes | Our product |
| Marine mechanic YouTube | No | No | Yes | Requires internet |
| ChatGPT / Claude | No | Yes | Generic | Requires internet, not boat-specific |
| Boat maintenance apps | Partial | No | Yes | Log-only, no guidance |
| Navionics / chart apps | Partial | No | Navigation only | No repair/maintenance |
| Equipment manuals (PDF) | Yes | No | Yes | Hard to search, no guidance |

**Our unique value**: The only product combining offline AI + marine-specific knowledge + user-specific vessel data.

---

## Open Questions for Decision

1. **Model selection**: Qwen3 1.7B as default? Or offer choice during setup?
2. **Skill pack authoring**: Who curates the marine knowledge? Partner with marine professionals?
3. **Manual fetching**: Build scraper or use search API (SerpAPI, etc.) before going offline?
4. **Business model**: One-time purchase? Freemium (basic skills free, premium packs paid)? Subscription for content updates?
5. **Language**: English-first, then expand? Many sailors are multilingual.
6. **Liability**: What disclaimers and limitations are needed for safety-critical advice?
7. **Testing**: How to validate advice quality? Partner with sailing schools / mechanics?
8. **Boat database**: Build our own make/model database or integrate existing ones?

---

## Minimum Device Requirements

| Platform | Minimum Device | RAM | GPU | Notes |
|----------|---------------|-----|-----|-------|
| Android | Snapdragon 855+ (2019+) | 6 GB+ | Adreno 640+ (Vulkan) | Most mid-range phones from 2020+ |
| iOS | iPhone 11+ (A13 Bionic) | 4 GB+ | Metal | ~1-2 GB iOS overhead reduces available RAM |

**RAM rule of thumb**: Available RAM must be ~2x the GGUF model file size.

---

## Key Resources

- [NobodyWho GitHub](https://github.com/nobodywho-ooo/nobodywho)
- [NobodyWho Docs](https://docs.nobodywho.ooo/)
- [NobodyWho Flutter Package (pub.dev)](https://pub.dev/packages/nobodywho)
- [Flutter Starter Example](https://github.com/nobodywho-ooo/flutter-starter-example)
- [NobodyWho Python Package (PyPI)](https://pypi.org/project/nobodywho/)

---

## Next Steps

1. Set up Flutter project with NobodyWho integration (reference their flutter-starter-example)
2. Build minimal boat profiling UI
3. Create first skill pack (Marine Diesel Engine Fundamentals)
4. Implement basic RAG pipeline with NobodyWho embeddings
5. Build chat interface
6. Test on Android + iOS devices with Qwen3 1.7B
7. Iterate on RAG quality with real marine scenarios
