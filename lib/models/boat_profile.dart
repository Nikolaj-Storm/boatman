class BoatProfile {
  final String id;
  String name;
  String? boatType; // sailboat, motorboat, catamaran, trawler
  String? make;
  String? model;
  String? year;
  String? hullMaterial; // fiberglass, wood, aluminum, steel, ferro-cement
  String? lengthFt;

  // Engine
  String? engineMake; // Volvo Penta, Yanmar, Perkins, Beta Marine, etc.
  String? engineModel;
  String? engineYear;
  String? engineHp;
  String? engineType; // diesel, gasoline, outboard, inboard, saildrive
  String? fuelType; // diesel, gasoline

  // Electrical
  String? batteryType; // lead-acid, AGM, lithium
  String? batteryBankAh;
  String? shoreVoltage; // 110V, 220V
  bool hasInverter;
  bool hasSolarPanels;
  bool hasWindGenerator;

  // Equipment
  String? autopilotMake;
  String? autopilotModel;
  String? chartplotterMake;
  String? chartplotterModel;
  String? vhfMake;
  String? vhfModel;
  String? radarMake;

  // Plumbing
  String? headType; // manual, electric
  String? watermakerMake;
  int freshWaterCapacityGal;
  int fuelCapacityGal;

  // Notes
  String? notes;

  BoatProfile({
    required this.id,
    this.name = '',
    this.boatType,
    this.make,
    this.model,
    this.year,
    this.hullMaterial,
    this.lengthFt,
    this.engineMake,
    this.engineModel,
    this.engineYear,
    this.engineHp,
    this.engineType,
    this.fuelType,
    this.batteryType,
    this.batteryBankAh,
    this.shoreVoltage,
    this.hasInverter = false,
    this.hasSolarPanels = false,
    this.hasWindGenerator = false,
    this.autopilotMake,
    this.autopilotModel,
    this.chartplotterMake,
    this.chartplotterModel,
    this.vhfMake,
    this.vhfModel,
    this.radarMake,
    this.headType,
    this.watermakerMake,
    this.freshWaterCapacityGal = 0,
    this.fuelCapacityGal = 0,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'boat_type': boatType,
      'make': make,
      'model': model,
      'year': year,
      'hull_material': hullMaterial,
      'length_ft': lengthFt,
      'engine_make': engineMake,
      'engine_model': engineModel,
      'engine_year': engineYear,
      'engine_hp': engineHp,
      'engine_type': engineType,
      'fuel_type': fuelType,
      'battery_type': batteryType,
      'battery_bank_ah': batteryBankAh,
      'shore_voltage': shoreVoltage,
      'has_inverter': hasInverter ? 1 : 0,
      'has_solar_panels': hasSolarPanels ? 1 : 0,
      'has_wind_generator': hasWindGenerator ? 1 : 0,
      'autopilot_make': autopilotMake,
      'autopilot_model': autopilotModel,
      'chartplotter_make': chartplotterMake,
      'chartplotter_model': chartplotterModel,
      'vhf_make': vhfMake,
      'vhf_model': vhfModel,
      'radar_make': radarMake,
      'head_type': headType,
      'watermaker_make': watermakerMake,
      'fresh_water_capacity_gal': freshWaterCapacityGal,
      'fuel_capacity_gal': fuelCapacityGal,
      'notes': notes,
    };
  }

  factory BoatProfile.fromMap(Map<String, dynamic> map) {
    return BoatProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      boatType: map['boat_type'] as String?,
      make: map['make'] as String?,
      model: map['model'] as String?,
      year: map['year'] as String?,
      hullMaterial: map['hull_material'] as String?,
      lengthFt: map['length_ft'] as String?,
      engineMake: map['engine_make'] as String?,
      engineModel: map['engine_model'] as String?,
      engineYear: map['engine_year'] as String?,
      engineHp: map['engine_hp'] as String?,
      engineType: map['engine_type'] as String?,
      fuelType: map['fuel_type'] as String?,
      batteryType: map['battery_type'] as String?,
      batteryBankAh: map['battery_bank_ah'] as String?,
      shoreVoltage: map['shore_voltage'] as String?,
      hasInverter: (map['has_inverter'] as int?) == 1,
      hasSolarPanels: (map['has_solar_panels'] as int?) == 1,
      hasWindGenerator: (map['has_wind_generator'] as int?) == 1,
      autopilotMake: map['autopilot_make'] as String?,
      autopilotModel: map['autopilot_model'] as String?,
      chartplotterMake: map['chartplotter_make'] as String?,
      chartplotterModel: map['chartplotter_model'] as String?,
      vhfMake: map['vhf_make'] as String?,
      vhfModel: map['vhf_model'] as String?,
      radarMake: map['radar_make'] as String?,
      headType: map['head_type'] as String?,
      watermakerMake: map['watermaker_make'] as String?,
      freshWaterCapacityGal: map['fresh_water_capacity_gal'] as int? ?? 0,
      fuelCapacityGal: map['fuel_capacity_gal'] as int? ?? 0,
      notes: map['notes'] as String?,
    );
  }

  String get summary {
    final parts = <String>[];
    if (year != null) parts.add(year!);
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    if (parts.isEmpty) return name;
    return parts.join(' ');
  }

  String get engineSummary {
    final parts = <String>[];
    if (engineMake != null) parts.add(engineMake!);
    if (engineModel != null) parts.add(engineModel!);
    if (engineHp != null) parts.add('${engineHp}hp');
    if (parts.isEmpty) return 'No engine specified';
    return parts.join(' ');
  }

  /// Build a context string for the AI describing this boat
  String toAiContext() {
    final lines = <String>[];
    lines.add('Vessel: ${summary.isNotEmpty ? summary : "Unknown"}');
    if (boatType != null) lines.add('Type: $boatType');
    if (hullMaterial != null) lines.add('Hull: $hullMaterial');
    if (lengthFt != null) lines.add('Length: $lengthFt ft');
    if (engineMake != null || engineModel != null) {
      lines.add('Engine: $engineSummary');
    }
    if (engineType != null) lines.add('Engine type: $engineType');
    if (fuelType != null) lines.add('Fuel: $fuelType');
    if (batteryType != null) lines.add('Batteries: $batteryType ${batteryBankAh ?? ""}Ah');
    if (notes != null && notes!.isNotEmpty) lines.add('Notes: $notes');
    return lines.join('\n');
  }
}
