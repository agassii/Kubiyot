// =============================================================================
// hive_service.dart
// Kubiyot — Hive persistence for the active game
//
// Stores exactly one game slot (the in-progress game) as a JSON string.
// Call init() once at app startup before any other method.
// Web: backed by IndexedDB (via hive_flutter's Hive.initFlutter).
// Native: backed by a .hive file in the app documents directory.
// =============================================================================

import 'dart:convert';
import 'package:hive/hive.dart';
import '../engine/game_manager.dart';
import 'game_state_serializer.dart';

class HiveService {
  static const String boxName = 'kubiyot_game';
  static const String _key = 'active_game';

  late final Box<String> _box;

  /// Opens the Hive box. Must be called once before save/load/clear.
  /// The caller is responsible for calling Hive.initFlutter() (app startup)
  /// or Hive.init(path) (tests) before this.
  Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);
  }

  /// Closes the underlying box. Primarily used in tests.
  Future<void> close() => _box.close();

  /// Persists [state] as JSON. Overwrites any previously saved game.
  Future<void> saveGame(GameState state) async {
    await _box.put(_key, jsonEncode(GameStateSerializer.toMap(state)));
  }

  /// Returns the saved game, or null if nothing has been saved yet.
  GameState? loadGame() {
    final data = _box.get(_key);
    if (data == null) return null;
    return GameStateSerializer.fromMap(jsonDecode(data) as Map<String, dynamic>);
  }

  /// Deletes the saved game slot.
  Future<void> clearGame() => _box.delete(_key);
}
