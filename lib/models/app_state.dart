import 'package:flutter/material.dart';
import 'package:boatman/models/boat_profile.dart';
import 'package:boatman/models/chat_message.dart';
import 'package:boatman/services/database_service.dart';

enum AppMode { shore, sea }

class AppState extends ChangeNotifier {
  final DatabaseService _db;

  AppMode _mode = AppMode.shore;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasCompletedOnboarding = false;
  BoatProfile? _activeBoat;
  List<BoatProfile> _boats = [];
  ChatSession? _activeChat;
  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  String? _modelLoadError;
  double _modelLoadProgress = 0.0;

  AppState(this._db) {
    _loadState();
  }

  // Getters
  AppMode get mode => _mode;
  ThemeMode get themeMode => _themeMode;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  BoatProfile? get activeBoat => _activeBoat;
  List<BoatProfile> get boats => _boats;
  ChatSession? get activeChat => _activeChat;
  bool get isModelLoaded => _isModelLoaded;
  bool get isModelLoading => _isModelLoading;
  String? get modelLoadError => _modelLoadError;
  double get modelLoadProgress => _modelLoadProgress;
  bool get isOnline => _mode == AppMode.shore;
  bool get isOffline => _mode == AppMode.sea;

  Future<void> _loadState() async {
    _boats = await _db.getBoatProfiles();
    if (_boats.isNotEmpty) {
      _activeBoat = _boats.first;
      _hasCompletedOnboarding = true;
    }
    notifyListeners();
  }

  void setMode(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<void> addBoat(BoatProfile boat) async {
    await _db.saveBoatProfile(boat);
    _boats.add(boat);
    _activeBoat ??= boat;
    notifyListeners();
  }

  Future<void> updateBoat(BoatProfile boat) async {
    await _db.saveBoatProfile(boat);
    final idx = _boats.indexWhere((b) => b.id == boat.id);
    if (idx >= 0) _boats[idx] = boat;
    if (_activeBoat?.id == boat.id) _activeBoat = boat;
    notifyListeners();
  }

  void setActiveBoat(BoatProfile boat) {
    _activeBoat = boat;
    notifyListeners();
  }

  void setActiveChat(ChatSession? session) {
    _activeChat = session;
    notifyListeners();
  }

  void setModelLoaded(bool loaded) {
    _isModelLoaded = loaded;
    _isModelLoading = false;
    _modelLoadError = null;
    notifyListeners();
  }

  void setModelLoading(bool loading, {double progress = 0.0}) {
    _isModelLoading = loading;
    _modelLoadProgress = progress;
    notifyListeners();
  }

  void setModelError(String error) {
    _modelLoadError = error;
    _isModelLoading = false;
    notifyListeners();
  }
}
