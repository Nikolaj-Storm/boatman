import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/models/boat_profile.dart';

class BoatProfileScreen extends StatelessWidget {
  const BoatProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final boat = appState.activeBoat;

    if (boat == null) {
      return const Center(child: Text('No boat profile set up'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editBoat(context, boat),
        icon: const Icon(Icons.edit),
        label: const Text('Edit Boat'),
      ),
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Boat header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sailing,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              boat.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              boat.summary,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editBoat(context, boat),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vessel details
          _buildSection(context, 'Vessel', Icons.directions_boat, [
            _buildDetail('Type', boat.boatType ?? 'Not set'),
            _buildDetail('Make', boat.make ?? 'Not set'),
            _buildDetail('Model', boat.model ?? 'Not set'),
            _buildDetail('Year', boat.year ?? 'Not set'),
            _buildDetail('Hull', boat.hullMaterial ?? 'Not set'),
            _buildDetail('Length', boat.lengthFt != null ? '${boat.lengthFt} ft' : 'Not set'),
          ]),

          // Engine details
          _buildSection(context, 'Engine', Icons.engineering, [
            _buildDetail('Type', boat.engineType ?? 'Not set'),
            _buildDetail('Make', boat.engineMake ?? 'Not set'),
            _buildDetail('Model', boat.engineModel ?? 'Not set'),
            _buildDetail('Power', boat.engineHp != null ? '${boat.engineHp} hp' : 'Not set'),
            _buildDetail('Fuel', boat.fuelType ?? 'Not set'),
          ]),

          // Electrical
          _buildSection(context, 'Electrical', Icons.bolt, [
            _buildDetail('Battery Type', boat.batteryType ?? 'Not set'),
            _buildDetail('Bank Capacity', boat.batteryBankAh != null ? '${boat.batteryBankAh} Ah' : 'Not set'),
            _buildDetail('Shore Power', boat.shoreVoltage ?? 'Not set'),
            _buildDetail('Inverter', boat.hasInverter ? 'Yes' : 'No'),
            _buildDetail('Solar', boat.hasSolarPanels ? 'Yes' : 'No'),
            _buildDetail('Wind Gen', boat.hasWindGenerator ? 'Yes' : 'No'),
          ]),

          // Electronics
          _buildSection(context, 'Electronics', Icons.monitor, [
            _buildDetail('Autopilot', _formatMakeModel(boat.autopilotMake, boat.autopilotModel)),
            _buildDetail('Chartplotter', _formatMakeModel(boat.chartplotterMake, boat.chartplotterModel)),
            _buildDetail('VHF', _formatMakeModel(boat.vhfMake, boat.vhfModel)),
            _buildDetail('Radar', boat.radarMake ?? 'Not set'),
          ]),

          // Plumbing
          _buildSection(context, 'Plumbing', Icons.plumbing, [
            _buildDetail('Head Type', boat.headType ?? 'Not set'),
            _buildDetail('Watermaker', boat.watermakerMake ?? 'None'),
            _buildDetail('Fresh Water', '${boat.freshWaterCapacityGal} gal'),
            _buildDetail('Fuel Tank', '${boat.fuelCapacityGal} gal'),
          ]),

          // Notes
          if (boat.notes != null && boat.notes!.isNotEmpty)
            _buildSection(context, 'Notes', Icons.note, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(boat.notes!, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ]),

          const SizedBox(height: 24),

          // Quick action buttons
          Text('Quick Actions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(context, 'Ask about my engine', Icons.engineering),
              _buildActionButton(context, 'Check maintenance schedule', Icons.calendar_today),
              _buildActionButton(context, 'Import a manual (PDF)', Icons.upload_file),
            ],
          ),
          const SizedBox(height: 80), // space for FAB
        ],
      ),
    ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: value == 'Not set' ? Colors.grey : null)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: Navigate to relevant action
      },
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
      ),
    );
  }

  String _formatMakeModel(String? make, String? model) {
    if (make == null && model == null) return 'Not set';
    return [make, model].where((s) => s != null).join(' ');
  }

  void _editBoat(BuildContext context, BoatProfile boat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BoatEditScreen(boat: boat),
      ),
    );
  }
}

class _BoatEditScreen extends StatefulWidget {
  final BoatProfile boat;

  const _BoatEditScreen({required this.boat});

  @override
  State<_BoatEditScreen> createState() => _BoatEditScreenState();
}

class _BoatEditScreenState extends State<_BoatEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _lengthController;
  late final TextEditingController _engineMakeController;
  late final TextEditingController _engineModelController;
  late final TextEditingController _engineHpController;
  late final TextEditingController _batteryAhController;
  late final TextEditingController _notesController;
  late String? _boatType;
  late String? _hullMaterial;
  late String? _engineType;
  late String? _batteryType;
  late bool _hasInverter;
  late bool _hasSolar;
  late bool _hasWind;

  @override
  void initState() {
    super.initState();
    final b = widget.boat;
    _nameController = TextEditingController(text: b.name);
    _makeController = TextEditingController(text: b.make);
    _modelController = TextEditingController(text: b.model);
    _yearController = TextEditingController(text: b.year);
    _lengthController = TextEditingController(text: b.lengthFt);
    _engineMakeController = TextEditingController(text: b.engineMake);
    _engineModelController = TextEditingController(text: b.engineModel);
    _engineHpController = TextEditingController(text: b.engineHp);
    _batteryAhController = TextEditingController(text: b.batteryBankAh);
    _notesController = TextEditingController(text: b.notes);
    _boatType = b.boatType;
    _hullMaterial = b.hullMaterial;
    _engineType = b.engineType;
    _batteryType = b.batteryType;
    _hasInverter = b.hasInverter;
    _hasSolar = b.hasSolarPanels;
    _hasWind = b.hasWindGenerator;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _lengthController.dispose();
    _engineMakeController.dispose();
    _engineModelController.dispose();
    _engineHpController.dispose();
    _batteryAhController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final b = widget.boat;
    b.name = _nameController.text;
    b.make = _makeController.text.isNotEmpty ? _makeController.text : null;
    b.model = _modelController.text.isNotEmpty ? _modelController.text : null;
    b.year = _yearController.text.isNotEmpty ? _yearController.text : null;
    b.lengthFt = _lengthController.text.isNotEmpty ? _lengthController.text : null;
    b.boatType = _boatType;
    b.hullMaterial = _hullMaterial;
    b.engineMake = _engineMakeController.text.isNotEmpty ? _engineMakeController.text : null;
    b.engineModel = _engineModelController.text.isNotEmpty ? _engineModelController.text : null;
    b.engineHp = _engineHpController.text.isNotEmpty ? _engineHpController.text : null;
    b.engineType = _engineType;
    b.batteryType = _batteryType;
    b.batteryBankAh = _batteryAhController.text.isNotEmpty ? _batteryAhController.text : null;
    b.hasInverter = _hasInverter;
    b.hasSolarPanels = _hasSolar;
    b.hasWindGenerator = _hasWind;
    b.notes = _notesController.text.isNotEmpty ? _notesController.text : null;

    await context.read<AppState>().updateBoat(b);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Boat Profile'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Boat Name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _boatType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'sailboat', child: Text('Sailboat')),
                DropdownMenuItem(value: 'motorboat', child: Text('Motorboat')),
                DropdownMenuItem(value: 'catamaran', child: Text('Catamaran')),
                DropdownMenuItem(value: 'trawler', child: Text('Trawler')),
              ],
              onChanged: (v) => setState(() => _boatType = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _makeController, decoration: const InputDecoration(labelText: 'Make'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _modelController, decoration: const InputDecoration(labelText: 'Model'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _yearController, decoration: const InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _lengthController, decoration: const InputDecoration(labelText: 'Length (ft)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _hullMaterial,
              decoration: const InputDecoration(labelText: 'Hull Material'),
              items: const [
                DropdownMenuItem(value: 'fiberglass', child: Text('Fiberglass')),
                DropdownMenuItem(value: 'wood', child: Text('Wood')),
                DropdownMenuItem(value: 'aluminum', child: Text('Aluminum')),
                DropdownMenuItem(value: 'steel', child: Text('Steel')),
              ],
              onChanged: (v) => setState(() => _hullMaterial = v),
            ),
            const SizedBox(height: 24),
            Text('Engine', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _engineType,
              decoration: const InputDecoration(labelText: 'Engine Type'),
              items: const [
                DropdownMenuItem(value: 'diesel_inboard', child: Text('Diesel Inboard')),
                DropdownMenuItem(value: 'diesel_saildrive', child: Text('Diesel Saildrive')),
                DropdownMenuItem(value: 'outboard', child: Text('Outboard')),
                DropdownMenuItem(value: 'gasoline_inboard', child: Text('Gasoline Inboard')),
              ],
              onChanged: (v) => setState(() => _engineType = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _engineMakeController, decoration: const InputDecoration(labelText: 'Engine Make')),
            const SizedBox(height: 12),
            TextField(controller: _engineModelController, decoration: const InputDecoration(labelText: 'Engine Model')),
            const SizedBox(height: 12),
            TextField(controller: _engineHpController, decoration: const InputDecoration(labelText: 'Horsepower'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Text('Electrical', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _batteryType,
              decoration: const InputDecoration(labelText: 'Battery Type'),
              items: const [
                DropdownMenuItem(value: 'lead-acid', child: Text('Lead-Acid (Flooded)')),
                DropdownMenuItem(value: 'agm', child: Text('AGM')),
                DropdownMenuItem(value: 'lithium', child: Text('Lithium (LiFePO4)')),
              ],
              onChanged: (v) => setState(() => _batteryType = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _batteryAhController, decoration: const InputDecoration(labelText: 'Battery Bank (Ah)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Inverter'), value: _hasInverter, onChanged: (v) => setState(() => _hasInverter = v)),
            SwitchListTile(title: const Text('Solar Panels'), value: _hasSolar, onChanged: (v) => setState(() => _hasSolar = v)),
            SwitchListTile(title: const Text('Wind Generator'), value: _hasWind, onChanged: (v) => setState(() => _hasWind = v)),
            const SizedBox(height: 24),
            Text('Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Additional Notes', hintText: 'Anything else relevant...'),
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Save Changes')),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
