/// Routes user queries to the most relevant knowledge categories and tags.
///
/// Uses keyword matching to classify queries into domains, then prioritizes
/// chunks from the right categories. When NobodyWho is integrated, this can
/// be replaced with embedding-based semantic routing.
class QueryRouter {
  /// Classify a query into one or more relevant categories, ranked by relevance.
  /// Returns a list of (category, weight) pairs, highest weight first.
  List<ScoredCategory> route(String query) {
    final q = query.toLowerCase();
    final scores = <String, double>{};

    // Score each category based on keyword matches
    for (final entry in _categoryKeywords.entries) {
      double score = 0;
      for (final keyword in entry.value) {
        if (q.contains(keyword)) {
          // Longer keywords are more specific, weight them higher
          score += keyword.length > 5 ? 2.0 : 1.0;
        }
      }
      if (score > 0) {
        scores[entry.key] = score;
      }
    }

    // Also check tag-level keywords for finer routing
    final matchedTags = <String>[];
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (q.contains(keyword)) {
          matchedTags.add(entry.key);
          break;
        }
      }
    }

    // If no specific category matched, include general as fallback
    if (scores.isEmpty) {
      scores['general'] = 1.0;
      scores['diagnostics'] = 0.5;
    }

    // Always add safety/diagnostics as low-weight supplementary sources
    // These cross-cutting skills are relevant to nearly every query
    scores['safety'] = (scores['safety'] ?? 0) + 0.2;
    scores['diagnostics'] = (scores['diagnostics'] ?? 0) + 0.2;
    scores['corrosion'] = (scores['corrosion'] ?? 0) + 0.1;
    scores['general'] = (scores['general'] ?? 0) + 0.3;

    // Sort by score descending
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map((e) => ScoredCategory(
              category: e.key,
              weight: e.value,
              matchedTags: matchedTags
                  .where((t) => _tagToCategory[t] == e.key || _tagToCategory[t] == 'general')
                  .toList(),
            ))
        .toList();
  }

  /// Extract specific tags from a query for sub-topic filtering
  List<String> extractTags(String query) {
    final q = query.toLowerCase();
    final tags = <String>[];
    for (final entry in _tagKeywords.entries) {
      for (final keyword in entry.value) {
        if (q.contains(keyword)) {
          tags.add(entry.key);
          break;
        }
      }
    }
    return tags;
  }

  /// Get the primary category for a query (convenience method)
  String primaryCategory(String query) {
    final results = route(query);
    return results.isNotEmpty ? results.first.category : 'general';
  }

  /// Category-level keyword mappings
  static const _categoryKeywords = <String, List<String>>{
    'diesel': [
      'engine', 'motor', 'diesel', 'cylinder', 'piston', 'crankshaft',
      'injection', 'injector', 'turbo', 'exhaust', 'manifold', 'rpm',
      'overheat', 'coolant', 'antifreeze', 'thermostat', 'impeller',
      'heat exchanger', 'raw water', 'fuel filter', 'fuel line', 'fuel tank',
      'bleed', 'air lock', 'glow plug', 'starter motor', 'starter',
      'alternator', 'belt', 'oil change', 'oil filter', 'oil pressure',
      'winteriz', 'commissioning', 'diesel bug', 'water separator',
      'mixing elbow', 'wet exhaust', 'muffler', 'transmission',
      'propeller', 'prop shaft', 'cutlass bearing', 'shaft seal',
      'saildrive', 'outboard', 'horsepower', 'throttle', 'idle',
      'smoke', 'black smoke', 'white smoke', 'blue smoke', 'won\'t start',
      'cranking', 'no start', 'stall', 'stalling', 'power loss',
      'volvo penta', 'yanmar', 'perkins', 'beta marine', 'bukh',
      'westerbeke', 'universal', 'kubota', 'mercruiser',
    ],
    'electrical': [
      'battery', 'batteries', 'voltage', 'volt', 'amp', 'current',
      'wire', 'wiring', 'fuse', 'breaker', 'circuit', 'short',
      'multimeter', 'continuity', 'resistance', 'ohm',
      'solar', 'solar panel', 'charge controller', 'mppt',
      'inverter', 'shore power', 'charger', 'charging',
      'alternator', 'regulator', 'diode',
      'led', 'light', 'navigation light', 'nav light', 'anchor light',
      'bilge pump', 'float switch', 'switch', 'panel',
      'vhf', 'radio', 'antenna', 'coax',
      'corrosion', 'corroded', 'terminal', 'crimp', 'solder',
      'galvanic', 'bonding', 'grounding', 'ground fault',
      'wind generator', 'hydro generator', 'agm', 'lithium', 'lifepo4',
      'parasitic drain', 'voltage drop',
    ],
    'plumbing': [
      'through-hull', 'through hull', 'seacock', 'thru-hull',
      'head', 'toilet', 'marine head', 'joker valve', 'holding tank',
      'macerator', 'y-valve', 'pumpout',
      'water tank', 'water pump', 'pressure pump', 'foot pump',
      'fresh water', 'watermaker', 'water filter',
      'bilge', 'bilge pump', 'float switch', 'limber',
      'leak', 'leaking', 'flooding', 'sinking',
      'hose', 'hose clamp', 'barb fitting', 'plumbing',
      'sealant', '5200', '4200', 'sikaflex', 'silicone', 'butyl',
      'stuffing box', 'stern gland', 'packing', 'shaft seal',
      'epoxy', 'underwater repair', 'plug', 'wooden plug',
      'accumulator', 'water heater', 'hot water',
    ],
    'fiberglass': [
      'fiberglass', 'fibreglass', 'gelcoat', 'gel coat',
      'blister', 'osmotic', 'osmosis', 'delamination',
      'core rot', 'balsa', 'balsa core', 'foam core',
      'epoxy', 'polyester', 'resin', 'hardener',
      'layup', 'cloth', 'mat', 'biaxial', 'woven roving',
      'fairing', 'filler', 'sanding', 'barrier coat',
      'antifouling', 'anti-fouling', 'bottom paint',
      'keel', 'keel bolt', 'rudder', 'skeg',
      'hull', 'deck', 'crack', 'scratch', 'gouge', 'impact',
      'repair', 'patch',
    ],
    'rigging': [
      'rigging', 'shroud', 'stay', 'forestay', 'backstay',
      'spreader', 'turnbuckle', 'toggle', 'swage', 'sta-lok', 'norseman',
      'halyard', 'sheet', 'line', 'rope', 'dyneema', 'spectra',
      'sail', 'mainsail', 'jib', 'genoa', 'spinnaker', 'storm sail',
      'reef', 'reefing', 'furling', 'roller furling', 'furler',
      'winch', 'block', 'sheave', 'clutch', 'traveler',
      'mast', 'boom', 'gooseneck', 'vang', 'kicker',
      'chainplate', 'tang', 'clevis pin', 'cotter pin',
      'sail repair', 'sail tape', 'batten', 'leech', 'luff',
      'uv cover', 'stitching', 'palm', 'needle', 'thread',
      'standing rigging', 'running rigging',
    ],
    'seamanship': [
      'knot', 'bowline', 'cleat hitch', 'clove hitch',
      'sheet bend', 'rolling hitch', 'splice', 'whipping',
      'anchor', 'anchoring', 'rode', 'chain', 'dragging',
      'man overboard', 'mob', 'overboard',
      'flare', 'epirb', 'distress', 'mayday', 'pan pan',
      'heavy weather', 'storm', 'heave to', 'heaving to',
      'sea anchor', 'drogue', 'lying ahull',
      'fire', 'fire extinguisher', 'abandon ship',
      'first aid', 'hypothermia', 'seasick', 'cpr',
      'compass', 'navigation', 'dead reckoning',
      'docking', 'mooring', 'fender', 'spring line',
      'tow', 'towing', 'being towed',
      'fog', 'collision', 'rules of road', 'colregs',
      'weather', 'forecast', 'barometer',
    ],
    'safety': [
      'safe', 'safety', 'danger', 'dangerous', 'risk',
      'lockout', 'tagout', 'isolation', 'isolate',
      'fire extinguisher', 'extinguisher',
      'should i', 'is it safe', 'can i',
      'before i start', 'before repair', 'precaution',
      'professional', 'call a pro', 'mechanic',
      'temporary fix', 'temporary repair', 'jury rig',
      'checklist', 'pre-repair', 'post-repair',
      'tool kit', 'spare parts', 'what to carry',
    ],
    'diagnostics': [
      'diagnos', 'troubleshoot', 'what\'s wrong',
      'why is', 'why won\'t', 'why does', 'how to find',
      'identify', 'figure out', 'determine',
      'symptom', 'noise', 'sound', 'smell', 'vibration',
      'intermittent', 'sometimes', 'randomly',
      'decision tree', 'systematic', 'step by step',
      'check', 'test', 'measure', 'inspect',
      'misdiagnos', 'common cause', 'most likely',
      'multimeter', 'compression test',
    ],
    'hydraulics': [
      'hydraulic', 'steering', 'helm pump', 'steering cylinder',
      'power steering', 'autopilot drive', 'linear drive',
      'trim tab', 'trim tabs',
      'hydraulic fluid', 'atf', 'dexron',
      'spongy steering', 'hard to turn', 'steering play',
      'bleed', 'bleeding', 'air in system',
      'emergency tiller', 'tiller',
      'windlass', 'bow thruster',
      'teleflex', 'seastar', 'vetus',
    ],
    'corrosion': [
      'corrosion', 'corrode', 'corroded', 'rust', 'rusty',
      'galvanic', 'electrolysis', 'stray current',
      'zinc', 'anode', 'sacrificial', 'dezincification',
      'dissimilar metal', 'galvanic series',
      'seized', 'stuck bolt', 'frozen bolt', 'won\'t come out',
      'fastener', 'bolt', 'nut', 'screw',
      'stainless', 'bronze', 'monel', 'brass',
      'galling', 'anti-seize', 'tefgel', 'penetrating oil',
      'bedding', 'rebed', 'rebedding', 'deck hardware',
      'bonding', 'bonding system', 'bonding wire',
    ],
    'general': [
      'tool', 'wrench', 'screwdriver', 'pliers', 'hammer',
      'drill', 'saw', 'file', 'sandpaper', 'tape',
      'lubrication', 'grease', 'wd-40', 'lanolin',
      'maintenance', 'inspection', 'schedule',
      'marine grade', 'above waterline', 'below waterline',
    ],
  };

  /// Fine-grained tag keywords for sub-topic routing within categories
  static const _tagKeywords = <String, List<String>>{
    // Diesel sub-topics
    'cooling': ['overheat', 'coolant', 'impeller', 'thermostat', 'heat exchanger', 'raw water', 'temperature'],
    'fuel_system': ['fuel', 'diesel bug', 'filter', 'bleed', 'injection', 'injector', 'water separator'],
    'starting': ['won\'t start', 'no start', 'cranking', 'glow plug', 'starter', 'starting'],
    'exhaust': ['exhaust', 'smoke', 'mixing elbow', 'wet exhaust', 'muffler', 'elbow'],
    'engine_electrical': ['alternator', 'belt', 'charging', 'starter motor'],
    'oil_lubrication': ['oil change', 'oil filter', 'oil pressure', 'oil level', 'transmission'],
    'propulsion': ['propeller', 'prop', 'shaft', 'cutlass', 'saildrive', 'transmission'],
    // Electrical sub-topics
    'battery_mgmt': ['battery', 'batteries', 'charge', 'charging', 'state of charge', 'voltage', 'agm', 'lithium'],
    'wiring': ['wire', 'wiring', 'crimp', 'connection', 'terminal', 'splice', 'corrosion'],
    'solar_wind': ['solar', 'mppt', 'wind generator', 'charge controller'],
    'instruments': ['vhf', 'radio', 'chartplotter', 'autopilot', 'instrument', 'radar', 'ais'],
    'shore_power': ['shore power', 'inverter', 'galvanic', '110v', '220v', 'isolation'],
    // Plumbing sub-topics
    'through_hulls': ['through-hull', 'seacock', 'thru-hull', 'sinking', 'flooding'],
    'heads': ['head', 'toilet', 'joker valve', 'holding tank', 'macerator'],
    'water_system': ['water pump', 'water tank', 'fresh water', 'pressure pump', 'watermaker'],
    'bilge': ['bilge', 'bilge pump', 'float switch'],
    'sealants': ['sealant', '5200', '4200', 'sikaflex', 'silicone', 'bedding'],
    // Seamanship sub-topics
    'knots_lines': ['knot', 'bowline', 'hitch', 'splice', 'whipping', 'line'],
    'emergencies': ['mayday', 'distress', 'man overboard', 'fire', 'abandon', 'sinking', 'collision'],
    'anchoring': ['anchor', 'anchoring', 'rode', 'dragging', 'chain'],
    'weather_heavy': ['heavy weather', 'storm', 'heave to', 'drogue', 'sea anchor'],
    'first_aid': ['first aid', 'hypothermia', 'burn', 'fracture', 'bleeding', 'cpr', 'seasick'],
    // Fiberglass sub-topics
    'gelcoat': ['gelcoat', 'gel coat', 'scratch', 'chip', 'crazing'],
    'structural': ['delamination', 'core rot', 'blister', 'osmotic', 'keel', 'rudder'],
    'bottom': ['antifouling', 'bottom paint', 'barrier coat', 'haul out'],
    // Safety sub-topics
    'isolation': ['lockout', 'tagout', 'isolate', 'disconnect', 'shut off'],
    'risk_assess': ['safe', 'danger', 'risk', 'should i', 'is it safe', 'precaution'],
    'when_to_stop': ['call a pro', 'professional', 'stop', 'don\'t attempt'],
    // Diagnostics sub-topics
    'decision_tree': ['diagnos', 'troubleshoot', 'decision tree', 'systematic'],
    'senses': ['noise', 'sound', 'smell', 'vibration', 'look', 'feel'],
    'root_cause': ['why', 'cause', 'root cause', 'misdiagnos'],
    // Hydraulics sub-topics
    'steering_hydraulic': ['hydraulic steering', 'helm pump', 'steering cylinder', 'spongy', 'emergency tiller'],
    'hydraulic_bleed': ['bleed', 'bleeding', 'air in', 'spongy steering'],
    'trim': ['trim tab', 'trim tabs'],
    // Corrosion sub-topics
    'galvanic': ['galvanic', 'dissimilar metal', 'galvanic series', 'electrolysis', 'stray current'],
    'anodes': ['zinc', 'anode', 'sacrificial', 'pencil zinc'],
    'seized_bolts': ['seized', 'stuck bolt', 'frozen bolt', 'extraction', 'penetrating oil', 'galling'],
    'bedding': ['bedding', 'rebed', 'deck hardware', 'bolt hole', 'core rot'],
  };

  /// Maps tags to their parent category
  static const _tagToCategory = <String, String>{
    'cooling': 'diesel', 'fuel_system': 'diesel', 'starting': 'diesel',
    'exhaust': 'diesel', 'engine_electrical': 'diesel', 'oil_lubrication': 'diesel',
    'propulsion': 'diesel',
    'battery_mgmt': 'electrical', 'wiring': 'electrical', 'solar_wind': 'electrical',
    'instruments': 'electrical', 'shore_power': 'electrical',
    'through_hulls': 'plumbing', 'heads': 'plumbing', 'water_system': 'plumbing',
    'bilge': 'plumbing', 'sealants': 'plumbing',
    'knots_lines': 'seamanship', 'emergencies': 'seamanship', 'anchoring': 'seamanship',
    'weather_heavy': 'seamanship', 'first_aid': 'seamanship',
    'gelcoat': 'fiberglass', 'structural': 'fiberglass', 'bottom': 'fiberglass',
    'isolation': 'safety', 'risk_assess': 'safety', 'when_to_stop': 'safety',
    'decision_tree': 'diagnostics', 'senses': 'diagnostics', 'root_cause': 'diagnostics',
    'steering_hydraulic': 'hydraulics', 'hydraulic_bleed': 'hydraulics', 'trim': 'hydraulics',
    'galvanic': 'corrosion', 'anodes': 'corrosion', 'seized_bolts': 'corrosion', 'bedding': 'corrosion',
  };

  /// Get the parent category for a tag
  static String? categoryForTag(String tag) => _tagToCategory[tag];
}

class ScoredCategory {
  final String category;
  final double weight;
  final List<String> matchedTags;

  const ScoredCategory({
    required this.category,
    required this.weight,
    this.matchedTags = const [],
  });

  @override
  String toString() => 'ScoredCategory($category, w=$weight, tags=$matchedTags)';
}
