import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/scoring_calculator.dart';
import '../engine/turn_state_machine.dart';
import '../models/roll_reveal.dart';
import '../services/hive_service.dart';

class GameNotifier extends ChangeNotifier {
  final GameManager _manager;
  final Random _random;
  final HiveService? _hive;
  GameState? _state;
  bool _isDisposed = false;

  RollReveal? _rollReveal;
  RollReveal? get rollReveal => _rollReveal;

  GameNotifier({GameManager? manager, Random? random, HiveService? hiveService})
      : _manager = manager ?? GameManager(),
        _random = random ?? Random(),
        _hive = hiveService {
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
    _rollReveal = null;
    _state = _manager.createGame(playerNames: playerNames, settings: settings);
    _save();
    notifyListeners();
  }

  void startGame() {
    assert(_state != null, 'Call createGame first');
    _rollReveal = null;
    _state = _manager.startGame(_state!);
    _save();
    notifyListeners();
  }

  // ── Turn actions ──────────────────────────────────────────────────────────

  void rollDice() {
    assert(_state?.activeTurn != null, 'No active turn to roll');
    final turn = _state!.activeTurn!;

    // Capture the rolling player's name before the engine may advance turns.
    final playerName = _state!.players
        .firstWhere((p) => p.id == turn.playerId,
            orElse: () => _state!.currentPlayer)
        .displayName;

    final n = turn.availableDiceCount;
    final faces = List.generate(n, (_) => _random.nextInt(6) + 1);
    _state = _manager.processRoll(game: _state!, rolledFaces: faces);

    // After processRoll, `turn` is mutated in place — currentRoll and
    // rollHistory.last are set even if _handleTurnComplete replaced activeTurn.
    // Bug #4: show dice for ALL rolls, not only terminal / hot-dice ones.
    final needsReveal = turn.rollHistory.isNotEmpty &&
        (turn.phase == TurnPhase.turnComplete ||
            turn.phase == TurnPhase.hotDiceForced ||
            turn.phase == TurnPhase.awaitingSelection);

    if (needsReveal) {
      _rollReveal = RollReveal(
        rolledDice: List.from(turn.currentRoll),
        // setAsideDice is cleared for hotDiceForced; preserved otherwise.
        setAsideDice: List.from(turn.setAsideDice),
        scoringResult: turn.rollHistory.last,
        endReason: turn.endReason,
        isHotDice: turn.phase == TurnPhase.hotDiceForced,
        sentinelCount: turn.isTheftTurn
            ? (5 - (turn.theftContext?.availableDiceCount ?? 5))
            : 0,
        playerName: playerName,
      );
      // Selection rolls: auto-dismiss after the animation settles (1300 ms).
      // Terminal / hot-dice reveals stay longer so the player can read them.
      final delay = turn.phase == TurnPhase.awaitingSelection
          ? const Duration(milliseconds: 1300)
          : const Duration(milliseconds: 1800);
      Future.delayed(delay, () {
        if (!_isDisposed && _rollReveal != null) {
          _rollReveal = null;
          notifyListeners();
        }
      });
    }

    _save();
    notifyListeners();
  }

  void dismissRollReveal() {
    if (_rollReveal != null) {
      _rollReveal = null;
      notifyListeners();
    }
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
    _hive!.saveGame(_state!);
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  bool get canBank =>
      _state != null && _manager.canCurrentPlayerBank(_state!);

  BankingBlockReason get bankingBlockReason => _state != null
      ? _manager.bankingBlockReason(_state!)
      : BankingBlockReason.notRoundNumber;

  bool get hasStealOpportunity =>
      _state != null && _manager.hasStealOpportunity(_state!);

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

final gameProvider = ChangeNotifierProvider<GameNotifier>(
  (ref) => GameNotifier(),
);
