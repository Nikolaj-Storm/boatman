import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boatman/services/database_service.dart';
import 'package:boatman/services/ai_service.dart';
import 'package:boatman/services/skill_pack_service.dart';
import 'package:boatman/services/manual_import_service.dart';
import 'package:boatman/services/manual_search_service.dart';
import 'package:boatman/models/app_state.dart';
import 'package:boatman/theme/boatman_theme.dart';
import 'package:boatman/screens/home_screen.dart';
import 'package:boatman/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize NobodyWho runtime (loads native FFI bridge)
  await AiService.initRuntime();

  final dbService = DatabaseService();
  await dbService.initialize();

  final skillPackService = SkillPackService();
  final aiService = AiService();
  final manualImportService = ManualImportService();
  final manualSearchService = ManualSearchService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(dbService)),
        Provider.value(value: dbService),
        Provider.value(value: skillPackService),
        Provider.value(value: aiService),
        Provider.value(value: manualImportService),
        Provider.value(value: manualSearchService),
      ],
      child: const BoatmanApp(),
    ),
  );
}

class BoatmanApp extends StatelessWidget {
  const BoatmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: 'Boatman',
          theme: BoatmanTheme.light,
          darkTheme: BoatmanTheme.dark,
          themeMode: appState.themeMode,
          debugShowCheckedModeBanner: false,
          home: appState.hasCompletedOnboarding
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
