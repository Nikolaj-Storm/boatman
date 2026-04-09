import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:boatman/models/knowledge_chunk.dart';
import 'package:boatman/services/database_service.dart';

class SkillPackService {
  static const _uuid = Uuid();

  static final List<SkillPack> availablePacks = [
    // Domain-specific packs
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
    // General / universal skill packs
    SkillPack(
      id: 'seamanship_emergency',
      name: 'Seamanship & Emergency Procedures',
      description: 'Knots, anchoring, man overboard, heavy weather, fire fighting, '
          'first aid at sea, and emergency signaling procedures.',
      category: 'seamanship',
      filename: 'seamanship_emergency.md',
    ),
    SkillPack(
      id: 'fiberglass_hull_repair',
      name: 'Fiberglass & Hull Repair',
      description: 'Gelcoat repair, fiberglass layup, osmotic blisters, core rot, '
          'keel inspection, bottom painting, and epoxy work.',
      category: 'fiberglass',
      filename: 'fiberglass_hull_repair.md',
    ),
    SkillPack(
      id: 'rigging_sails_deck',
      name: 'Rigging, Sails & Deck Hardware',
      description: 'Standing and running rigging inspection, sail repair, winch maintenance, '
          'roller furling, blocks, and chainplate inspection.',
      category: 'rigging',
      filename: 'rigging_sails_deck.md',
    ),
    // Safety and diagnostics (cross-cutting skills)
    SkillPack(
      id: 'repair_safety_triage',
      name: 'Repair Safety Triage',
      description: 'Safety-first decision framework: risk assessment, isolation/lockout, '
          'when to stop, when to call a pro, pre-repair checklists, and emergency tool kit.',
      category: 'safety',
      filename: 'repair_safety_triage.md',
    ),
    SkillPack(
      id: 'field_diagnostics',
      name: 'Field Diagnostics',
      description: 'Structured troubleshooting interview: decision trees for engine, electrical, '
          'and water problems. Five-senses diagnostic, common misdiagnoses, and logging.',
      category: 'diagnostics',
      filename: 'field_diagnostics.md',
    ),
    // Specialized systems
    SkillPack(
      id: 'hydraulics_and_hoses',
      name: 'Hydraulics & Hoses',
      description: 'Hydraulic steering, autopilot drives, trim tabs, hose inspection, '
          'bleeding procedures, and emergency steering.',
      category: 'hydraulics',
      filename: 'hydraulics_and_hoses.md',
    ),
    SkillPack(
      id: 'corrosion_and_fasteners',
      name: 'Corrosion & Fasteners',
      description: 'Galvanic corrosion, stray current, sacrificial anodes, marine fastener '
          'selection, seized bolt extraction, and hardware bedding.',
      category: 'corrosion',
      filename: 'corrosion_and_fasteners.md',
    ),
  ];

  /// Load a skill pack from assets, chunk it, tag it, and save to database
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

    // Auto-tag each chunk based on content
    final taggedChunks = chunks.map((c) => _autoTag(c)).toList();

    // Save to database
    await db.saveChunks(taggedChunks);

    return taggedChunks.length;
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

  /// Auto-tag a chunk based on its content and title
  KnowledgeChunk _autoTag(KnowledgeChunk chunk) {
    final text = '${chunk.title} ${chunk.content}'.toLowerCase();
    final matchedTags = <String>[];

    for (final entry in _autoTagRules.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          matchedTags.add(entry.key);
          break; // One match per tag is enough
        }
      }
    }

    if (matchedTags.isEmpty) return chunk;

    return KnowledgeChunk(
      id: chunk.id,
      sourceId: chunk.sourceId,
      sourceType: chunk.sourceType,
      category: chunk.category,
      title: chunk.title,
      content: chunk.content,
      chunkIndex: chunk.chunkIndex,
      tags: matchedTags.join(','),
    );
  }

  /// Tag auto-detection rules: tag name → keywords that indicate the tag
  static const _autoTagRules = <String, List<String>>{
    // Diesel sub-topics
    'cooling': ['overheat', 'coolant', 'impeller', 'thermostat', 'heat exchanger', 'raw water cooling', 'temperature gauge'],
    'fuel_system': ['fuel filter', 'fuel line', 'diesel bug', 'bleed', 'injection pump', 'injector', 'water separator', 'racor', 'fuel tank'],
    'starting': ['won\'t start', 'no start', 'cranking', 'glow plug', 'starter motor', 'starting circuit'],
    'exhaust': ['exhaust', 'mixing elbow', 'wet exhaust', 'muffler', 'smoke color', 'black smoke', 'white smoke', 'blue smoke'],
    'engine_electrical': ['alternator', 'drive belt', 'charging circuit', 'starter solenoid'],
    'oil_lubrication': ['oil change', 'oil filter', 'oil pressure', 'engine oil', 'transmission fluid', 'gear oil'],
    'propulsion': ['propeller', 'prop shaft', 'cutlass bearing', 'saildrive', 'transmission', 'shaft seal', 'stuffing box'],
    // Electrical sub-topics
    'battery_mgmt': ['battery', 'state of charge', 'voltage', 'amp hour', 'deep cycle', 'agm', 'lithium', 'lifepo4', 'equalization'],
    'wiring': ['wire', 'wiring', 'crimp', 'connection', 'terminal', 'splice', 'tinned copper', 'heat shrink', 'abyc'],
    'diagnostics': ['multimeter', 'voltage drop', 'continuity', 'resistance', 'ammeter', 'parasitic drain'],
    'solar_wind': ['solar panel', 'mppt', 'pwm', 'charge controller', 'wind generator'],
    'instruments': ['vhf', 'radio', 'chartplotter', 'autopilot', 'radar', 'ais', 'antenna'],
    'shore_power': ['shore power', 'inverter', 'galvanic isolator', 'isolation transformer'],
    // Plumbing sub-topics
    'through_hulls': ['through-hull', 'seacock', 'ball valve', 'gate valve', 'wooden plug', 'sinking'],
    'heads': ['marine head', 'toilet', 'joker valve', 'holding tank', 'macerator', 'y-valve', 'pumpout'],
    'water_system': ['water pump', 'water tank', 'fresh water', 'pressure pump', 'accumulator', 'watermaker', 'foot pump'],
    'bilge': ['bilge pump', 'float switch', 'bilge', 'limber hole'],
    'sealants': ['sealant', '5200', '4200', 'sikaflex', 'silicone', 'butyl tape', 'bedding'],
    'leak_repair': ['emergency patch', 'collision mat', 'underwater epoxy', 'leak repair'],
    // Seamanship sub-topics
    'knots_lines': ['bowline', 'cleat hitch', 'clove hitch', 'sheet bend', 'rolling hitch', 'splice', 'whipping', 'knot'],
    'emergencies': ['mayday', 'pan-pan', 'distress', 'man overboard', 'mob', 'fire fighting', 'abandon ship', 'epirb'],
    'anchoring': ['anchor', 'anchoring', 'anchor rode', 'dragging', 'fouled anchor', 'chain'],
    'weather_heavy': ['heavy weather', 'storm', 'heave to', 'heaving to', 'drogue', 'sea anchor', 'lying ahull'],
    'first_aid': ['first aid', 'hypothermia', 'burn', 'fracture', 'bleeding', 'cpr', 'seasick'],
    'navigation': ['compass', 'dead reckoning', 'celestial', 'chart', 'bearing', 'fix'],
    // Fiberglass sub-topics
    'gelcoat': ['gelcoat', 'gel coat', 'scratch', 'chip', 'crazing', 'polish'],
    'structural': ['delamination', 'core rot', 'blister', 'osmotic', 'balsa core', 'foam core', 'keel bolt', 'rudder'],
    'bottom': ['antifouling', 'bottom paint', 'barrier coat', 'haul out', 'ablative'],
    'resin_work': ['epoxy', 'polyester resin', 'fiberglass cloth', 'layup', 'hardener', 'mixing ratio', 'fairing compound'],
    // Rigging sub-topics
    'standing_rig': ['shroud', 'stay', 'forestay', 'backstay', 'spreader', 'turnbuckle', 'swage', 'chainplate'],
    'running_rig': ['halyard', 'sheet', 'control line', 'dyneema', 'block', 'clutch'],
    'sails': ['sail repair', 'sail tape', 'batten', 'uv cover', 'leech line', 'stitching', 'palm and needle'],
    'hardware': ['winch', 'roller furling', 'furler', 'gooseneck', 'vang', 'traveler'],
    // Safety sub-topics
    'isolation': ['lockout', 'tagout', 'isolate', 'disconnect', 'shut off', 'breaker off'],
    'risk_assess': ['severity', 'critical', 'danger', 'risk', 'safe to', 'is it safe'],
    'pre_repair': ['before starting', 'checklist', 'pre-repair', 'gather tools'],
    'post_repair': ['verify', 'test the repair', 'post-repair', 'monitor', 'log the repair'],
    'when_to_stop': ['call a pro', 'professional help', 'stop immediately', 'don\'t attempt'],
    'spare_parts': ['spare parts', 'tool kit', 'toolkit', 'what to carry', 'emergency kit'],
    // Diagnostics sub-topics
    'decision_tree': ['decision tree', 'diagnostic sequence', 'does the starter', 'is water coming'],
    'five_senses': ['look', 'listen', 'smell', 'touch', 'taste', 'noise', 'sound', 'vibration'],
    'root_cause': ['misdiagnos', 'common cause', 'root cause', 'actually', 'most likely'],
    'interview': ['what changed', 'when did this start', 'consistent or intermittent', 'what makes it worse'],
    // Hydraulics sub-topics
    'steering_hydraulic': ['hydraulic steering', 'helm pump', 'steering cylinder', 'ram', 'emergency tiller'],
    'hydraulic_bleed': ['bleed', 'bleeding procedure', 'spongy steering', 'air bubbles'],
    'autopilot_hydraulic': ['autopilot drive', 'linear drive', 'rotary drive'],
    'trim_tabs': ['trim tab', 'trim tabs', 'transom'],
    'hose_inspection': ['hose inspection', 'bulging', 'wire braid', 'chafe', 'replace hose'],
    // Corrosion sub-topics
    'galvanic_corrosion': ['galvanic corrosion', 'dissimilar metals', 'galvanic series', 'noble', 'less noble'],
    'stray_current': ['stray current', 'electrolysis', 'wiring fault', 'shore power corrosion'],
    'anodes': ['sacrificial anode', 'zinc anode', 'pencil zinc', 'anode consumption'],
    'seized_bolts': ['seized bolt', 'stuck bolt', 'penetrating oil', 'bolt extraction', 'ez-out', 'galling'],
    'fastener_select': ['fastener selection', 'silicon bronze', 'monel', '316 stainless', 'marine fastener'],
    'bedding_hardware': ['bedding', 'rebed', 'rebedding', 'bolt hole', 'seal the core'],
  };

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

    // If chunks are too large (>1500 chars), split them further
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
