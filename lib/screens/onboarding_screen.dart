import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/services/ai_service.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/skill_pack_service.dart';
import 'package:boatman/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Boat profile fields
  final _nameController = TextEditingController();
  String? _boatType;
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  String? _hullMaterial;
  final _lengthController = TextEditingController();

  // Engine fields
  final _engineMakeController = TextEditingController();
  final _engineModelController = TextEditingController();
  final _engineHpController = TextEditingController();
  String? _engineType;

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _lengthController.dispose();
    _engineMakeController.dispose();
    _engineModelController.dispose();
    _engineHpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    final db = context.read<DatabaseService>();
    final skillPackService = context.read<SkillPackService>();
    final aiService = context.read<AiService>();

    // Create boat profile
    final boat = BoatProfile(
      id: const Uuid().v4(),
      name: _nameController.text.isNotEmpty ? _nameController.text : 'My Boat',
      boatType: _boatType,
      make: _makeController.text.isNotEmpty ? _makeController.text : null,
      model: _modelController.text.isNotEmpty ? _modelController.text : null,
      year: _yearController.text.isNotEmpty ? _yearController.text : null,
      hullMaterial: _hullMaterial,
      lengthFt: _lengthController.text.isNotEmpty ? _lengthController.text : null,
      engineMake: _engineMakeController.text.isNotEmpty ? _engineMakeController.text : null,
      engineModel: _engineModelController.text.isNotEmpty ? _engineModelController.text : null,
      engineHp: _engineHpController.text.isNotEmpty ? _engineHpController.text : null,
      engineType: _engineType,
      fuelType: _engineType == 'gasoline' || _engineType == 'outboard' ? 'gasoline' : 'diesel',
    );

    await appState.addBoat(boat);

    // Load skill packs into database
    await skillPackService.loadAllSkillPacks(db);

    // Try to load a model if one exists on device, otherwise mock mode
    final modelsDir = await AiService.getModelsDirectory();
    final ggufFiles = Directory(modelsDir)
        .listSync()
        .where((f) => f.path.endsWith('.gguf'))
        .toList();

    if (ggufFiles.isNotEmpty) {
      try {
        await aiService.loadChatModel(modelPath: ggufFiles.first.path);
        appState.setModelLoaded(true);
      } catch (_) {
        aiService.initializeMock();
        appState.setModelLoaded(true);
      }
    } else {
      aiService.initializeMock();
      appState.setModelLoaded(true);
    }

    appState.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildBoatInfoPage(),
                  _buildEnginePage(),
                  _buildReadyPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sailing,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Boatman',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your offline AI handyman for life at sea.\n\n'
            'Tell me about your boat and I\'ll prepare everything you need — '
            'technical guides, troubleshooting, and repair knowledge — '
            'all stored locally on your device.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoatInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell me about your boat',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('This helps me find the right technical information.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Boat Name',
              hintText: 'e.g. Sea Breeze',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _boatType,
            decoration: const InputDecoration(labelText: 'Boat Type'),
            items: const [
              DropdownMenuItem(value: 'sailboat', child: Text('Sailboat')),
              DropdownMenuItem(value: 'motorboat', child: Text('Motorboat')),
              DropdownMenuItem(value: 'catamaran', child: Text('Catamaran')),
              DropdownMenuItem(value: 'trawler', child: Text('Trawler')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _boatType = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _makeController,
                  decoration: const InputDecoration(
                    labelText: 'Make',
                    hintText: 'e.g. Beneteau',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'e.g. Oceanis 38',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    hintText: 'e.g. 2015',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lengthController,
                  decoration: const InputDecoration(
                    labelText: 'Length (ft)',
                    hintText: 'e.g. 38',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _hullMaterial,
            decoration: const InputDecoration(labelText: 'Hull Material'),
            items: const [
              DropdownMenuItem(value: 'fiberglass', child: Text('Fiberglass/GRP')),
              DropdownMenuItem(value: 'wood', child: Text('Wood')),
              DropdownMenuItem(value: 'aluminum', child: Text('Aluminum')),
              DropdownMenuItem(value: 'steel', child: Text('Steel')),
              DropdownMenuItem(value: 'ferro-cement', child: Text('Ferro-cement')),
            ],
            onChanged: (v) => setState(() => _hullMaterial = v),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(onPressed: _prevPage, child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 56),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnginePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Engine Details',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('This is critical for troubleshooting at sea.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _engineType,
            decoration: const InputDecoration(labelText: 'Engine Type'),
            items: const [
              DropdownMenuItem(value: 'diesel_inboard', child: Text('Diesel Inboard')),
              DropdownMenuItem(value: 'diesel_saildrive', child: Text('Diesel Saildrive')),
              DropdownMenuItem(value: 'outboard', child: Text('Outboard')),
              DropdownMenuItem(value: 'gasoline_inboard', child: Text('Gasoline Inboard')),
              DropdownMenuItem(value: 'electric', child: Text('Electric')),
            ],
            onChanged: (v) => setState(() => _engineType = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _engineMakeController,
            decoration: const InputDecoration(
              labelText: 'Engine Make',
              hintText: 'e.g. Volvo Penta, Yanmar, Perkins',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _engineModelController,
            decoration: const InputDecoration(
              labelText: 'Engine Model',
              hintText: 'e.g. D2-40, 3GM30F',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _engineHpController,
            decoration: const InputDecoration(
              labelText: 'Horsepower',
              hintText: 'e.g. 40',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can add more equipment details later from the My Boat screen.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(onPressed: _prevPage, child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 56),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Set Up',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'I\'ll now load the core knowledge packs:\n\n'
            '  Marine Diesel Engines\n'
            '  Marine Electrical Systems\n'
            '  Marine Plumbing & Water\n\n'
            'This data stays on your device and works fully offline.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (_isLoading)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading knowledge packs...'),
              ],
            )
          else
            ElevatedButton(
              onPressed: _finishOnboarding,
              child: const Text('Set Up Boatman'),
            ),
          const SizedBox(height: 16),
          TextButton(onPressed: _prevPage, child: const Text('Back')),
        ],
      ),
    );
  }
}
