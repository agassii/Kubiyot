// =============================================================================
// game_provider.dart
// Kubiyot — Reactive game state bridge between GameManager and the UI
//
// Uses ChangeNotifierProvider so every notifyListeners() call triggers a
// rebuild regardless of object identity (GameManager mutates in place).
// =============================================================================

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/scoring_calculator.dart';
import '../engine/turn_state_machine.dart';
import '../services/hive_service.dart';

class GameNotifier extends ChangeNotifier {
  final GameManager _manager;
  final Random _random;
  final HiveService? _hive;
  GameState? _state;

  GameNotifier({GameManager? manager, Random? random, HiveService? hiveService})
      : _manager = manager ?? GameManager(),
        _random = random ?? Random(),
        _hive = hiveService {
    // Restore any in-progress game from disk (synchronous — box already open).
    _state = hiveService?.loadGame();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  GameState? get state => _state;
  bool get isActive => _state != null && !_state!.isComplete;

  // ── Setup ──────────────────────────────────────────────────────────────────

  void createGame(
    List<String> playerNames, {
    GameSettings settings = const GameSettings(),
  }) {
    _state = _manager.createGame(playerNames: playerNames, settings: settings);
    _save();
    notifyListeners();
  }

  void startGame() {
    assert(_state != null, 'Call createGame first');
    _state = _manager.startGame(_state!);
    _save();
    notifyListeners();
  }

  // ── Turn actions ──────────────────────────────────────────────────────────

  /// Generates N random dice (N = activeTurn.availableDiceCount) and processes
  /// the roll. With the theft-turn sentinel approach, availableDiceCount
  /// automatically reflects the correct leftover count.
  void rollDice() {
    assert(_state?.activeTurn != null, 'No active turn to roll');
    final n = _state!.activeTurn!.availableDiceCount;
    final faces = List.generate(n, (_) => _random.nextInt(6) + 1);
    _state = _manager.processRoll(game: _state!, rolledFaces: faces);
    _save();
    notifyListeners();
  }

  void selectDice(List<int> indices) {
    assert(_state?.activeTurn != null, 'No active turn');
    _state = _manager.processSelection(
      game: _state!,
      selectedDiceIndices: indices,
    );
    _save();
    notifyListeners();
  }

  void bank() {
    assert(_state?.activeTurn != null, 'No active turn');
    _state = _manager.processBank(_state!);
    _save();
    notifyListeners();
  }

  void decideTheft(bool steal) {
    assert(_state != null, 'No game in progress');
    _state = _manager.processTheftDecision(game: _state!, steal: steal);
    _save();
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _save() {
    if (_hive == null || _state == null) return;
    _hive!.saveGame(_state!); // Future<void> — fire-and-forget is intentional
  }

  // ── Queries (delegates to GameManager so logic stays in the engine) ────────

  bool get canBank =>
      _state != null && _manager.canCurrentPlayerBank(_state!);

  BankingBlockReason get bankingBlockReason => _state != null
      ? _manager.bankingBlockReason(_state!)
      : BankingBlockReason.notRoundNumber;

  bool get hasStealOpportunity =>
      _state != null && _manager.hasStealOpportunity(_state!);
}

final gameProvider = ChangeNotifierProvider<GameNotifier>(
  (ref) => GameNotifier(),
);
