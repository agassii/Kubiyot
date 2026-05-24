// =============================================================================
// game_manager.dart
// Kubiyot Dice Game — Game Manager
//
// Responsibilities:
//   1. Manage the full game lifecycle (start, turns, end)
//   2. Orchestrate TurnStateMachine + PlayerManager
//   3. Manage turn rotation and theft window
//   4. Expose a clean API for the UI layer (via providers)
//
// This file is pure Dart — zero Flutter dependencies.
// =============================================================================

import 'turn_state_machine.dart';
import 'player_manager.dart';
import 'scoring_calculator.dart';

// -----------------------------------------------------------------------------
// GAME STATE
// -----------------------------------------------------------------------------

enum GamePhase {
  setup,          // players being added, game not started
  inProgress,     // game is running
  stealWindow,    // previous player banked — next can steal or pass
  complete,       // someone won
}

class GameState {
  final String gameId;
  final List<Player> players;
  final GameSettings settings;

  GamePhase phase;
  int currentPlayerIndex;
  TurnState? activeTurn;

  // Theft window
  bool stealWindowOpen;
  TheftContext? pendingTheftContext;

  // Who won
  String? winnerId;

  // Full event log for UI replay / history
  final List<ScoreChangeResult> eventLog;

  GameState({
    required this.gameId,
    required this.players,
    required this.settings,
    this.phase = GamePhase.setup,
    this.currentPlayerIndex = 0,
    this.activeTurn,
    this.stealWindowOpen = false,
    this.pendingTheftContext,
    this.winnerId,
    List<ScoreChangeResult>? eventLog,
  }) : eventLog = eventLog ?? [];

  Player get currentPlayer => players[currentPlayerIndex];

  Player? get winner =>
      winnerId != null
          ? players.firstWhere((p) => p.id == winnerId)
          : null;

  bool get isComplete => phase == GamePhase.complete;
}

// -----------------------------------------------------------------------------
// GAME SETTINGS
// -----------------------------------------------------------------------------

class GameSettings {
  final int winTarget;          // default 10000
  final int entryThreshold;     // default 400
  final int hotDiceBonus;       // default 200
  final bool ceilingBustCountsAsX; // default true (per your ruling)

  const GameSettings({
    this.winTarget = 10000,
    this.entryThreshold = 400,
    this.hotDiceBonus = 200,
    this.ceilingBustCountsAsX = true,
  });
}

// -----------------------------------------------------------------------------
// GAME MANAGER
// -----------------------------------------------------------------------------

class GameManager {
  final TurnStateMachine _turnMachine = TurnStateMachine();
  final PlayerManager _playerManager = PlayerManager();

  // ---------------------------------------------------------------------------
  // 1. Game Setup
  // ---------------------------------------------------------------------------

  /// Creates a new game with the given players.
  /// Players are given in turn order.
  GameState createGame({
    required List<String> playerNames,
    GameSettings settings = const GameSettings(),
  }) {
    assert(playerNames.length >= 2, 'Need at least 2 players');
    assert(playerNames.length <= 8, 'Maximum 8 players');

    final players = [
      for (int i = 0; i < playerNames.length; i++)
        Player(
          id: 'p${i + 1}',
          displayName: playerNames[i],
        )
    ];

    return GameState(
      gameId: DateTime.now().millisecondsSinceEpoch.toString(),
      players: players,
      settings: settings,
      phase: GamePhase.setup,
    );
  }

  /// Starts the game — transitions from setup to inProgress.
  GameState startGame(GameState game) {
    assert(game.phase == GamePhase.setup, 'Game already started');
    game.phase = GamePhase.inProgress;
    game.activeTurn = _turnMachine.startNewTurn(
      playerId: game.currentPlayer.id,
    );
    return game;
  }

  // ---------------------------------------------------------------------------
  // 2. Roll Dice
  // ---------------------------------------------------------------------------

  /// Call this when the current player rolls the dice.
  ///
  /// [rolledFaces] — the raw face values from the physical/virtual dice roll.
  ///                 Must match the number of available dice for this roll.
  ///
  /// Returns updated GameState.
  GameState processRoll({
    required GameState game,
    required List<int> rolledFaces,
  }) {
    assert(game.phase == GamePhase.inProgress, 'Game not in progress');
    assert(game.activeTurn != null, 'No active turn');

    final turn = game.activeTurn!;
    final player = game.currentPlayer;

    _turnMachine.processRoll(
      state: turn,
      rolledFaces: rolledFaces,
      permanentScore: player.currentScore,
      isEntered: player.isEntered,
    );

    // Handle turn completion from the roll itself (farkle, ceiling, win)
    if (turn.phase == TurnPhase.turnComplete) {
      return _handleTurnComplete(game);
    }

    return game;
  }

  // ---------------------------------------------------------------------------
  // 3. Select Dice
  // ---------------------------------------------------------------------------

  /// Call this when the player selects which scoring dice to set aside.
  GameState processSelection({
    required GameState game,
    required List<int> selectedDiceIndices,
  }) {
    assert(game.phase == GamePhase.inProgress);
    assert(game.activeTurn != null);

    final turn = game.activeTurn!;
    final player = game.currentPlayer;

    _turnMachine.processSelection(
      state: turn,
      selectedDiceIndices: selectedDiceIndices,
      permanentScore: player.currentScore,
      isEntered: player.isEntered,
    );

    return game;
  }

  // ---------------------------------------------------------------------------
  // 4. Bank
  // ---------------------------------------------------------------------------

  /// Call this when the player decides to bank their score.
  GameState processBank(GameState game) {
    assert(game.phase == GamePhase.inProgress);
    assert(game.activeTurn != null);

    final turn = game.activeTurn!;
    final player = game.currentPlayer;

    _turnMachine.processBank(
      state: turn,
      permanentScore: player.currentScore,
      isEntered: player.isEntered,
    );

    return _handleTurnComplete(game);
  }

  // ---------------------------------------------------------------------------
  // 5. Theft Decision
  // ---------------------------------------------------------------------------

  /// Call this when the next player decides to steal (or pass).
  ///
  /// [steal] — true if the player wants to steal, false to skip.
  GameState processTheftDecision({
    required GameState game,
    required bool steal,
  }) {
    assert(game.phase == GamePhase.stealWindow, 'No steal window open');
    assert(game.pendingTheftContext != null);

    if (!steal) {
      // Player passes on theft — start a normal turn.
      game.stealWindowOpen = false;
      game.pendingTheftContext = null;
      game.phase = GamePhase.inProgress;
      game.activeTurn = _turnMachine.startNewTurn(
        playerId: game.currentPlayer.id,
      );
      return game;
    }

    // Player steals.
    game.stealWindowOpen = false;
    game.phase = GamePhase.inProgress;
    game.activeTurn = _turnMachine.startTheftTurn(
      playerId: game.currentPlayer.id,
      context: game.pendingTheftContext!,
    );
    game.pendingTheftContext = null;

    return game;
  }

  // ---------------------------------------------------------------------------
  // 6. Queries for UI
  // ---------------------------------------------------------------------------

  /// Whether the current player can bank right now.
  bool canCurrentPlayerBank(GameState game) {
    if (game.activeTurn == null) return false;
    return _turnMachine.canBank(
      state: game.activeTurn!,
      isEntered: game.currentPlayer.isEntered,
    );
  }

  /// Why banking is blocked (for UI error messages).
  BankingBlockReason bankingBlockReason(GameState game) {
    if (game.activeTurn == null) return BankingBlockReason.notRoundNumber;
    return _turnMachine.getBankingBlockReason(
      state: game.activeTurn!,
      isEntered: game.currentPlayer.isEntered,
    );
  }

  /// Whether there is an active theft window for the current player.
  bool hasStealOpportunity(GameState game) =>
      game.phase == GamePhase.stealWindow &&
      game.pendingTheftContext != null;

  // ---------------------------------------------------------------------------
  // Private — Turn completion handler
  // ---------------------------------------------------------------------------

  GameState _handleTurnComplete(GameState game) {
    final turn = game.activeTurn!;
    final player = game.currentPlayer;

    switch (turn.endReason!) {

      // ── Win ──────────────────────────────────────────────────────────────
      case TurnEndReason.win:
        final result = _playerManager.bank(
          players: game.players,
          bankingPlayer: player,
          amount: turn.finalBankedScore!,
        );
        game.eventLog.add(result);
        game.phase = GamePhase.complete;
        game.winnerId = player.id;
        game.activeTurn = null;
        return game;

      // ── Banked ───────────────────────────────────────────────────────────
      case TurnEndReason.banked:
        final result = _playerManager.bank(
          players: game.players,
          bankingPlayer: player,
          amount: turn.finalBankedScore!,
        );
        game.eventLog.add(result);

        // Mark entry if not yet entered.
        if (!player.isEntered) {
          _playerManager.markEntered(player);
        }

        // Check if a stomp triggered a win (edge case: domino cascade win).
        if (result.gameWon) {
          game.phase = GamePhase.complete;
          game.winnerId = result.winnerId;
          game.activeTurn = null;
          return game;
        }

        // Check for theft window.
        final theftContext = _turnMachine.buildTheftContext(turn);
        if (theftContext != null) {
          game.stealWindowOpen = true;
          game.pendingTheftContext = theftContext;
          game.activeTurn = null;
          _advanceToNextPlayer(game);
          game.phase = GamePhase.stealWindow;
          return game;
        }

        // No theft — advance normally.
        _advanceToNextPlayer(game);
        game.activeTurn = _turnMachine.startNewTurn(
          playerId: game.currentPlayer.id,
        );
        return game;

      // ── Any Bust ─────────────────────────────────────────────────────────
      case TurnEndReason.naturalFarkle:
      case TurnEndReason.ceilingBust:
      case TurnEndReason.hotDiceBust:
        final result = _playerManager.recordX(
          players: game.players,
          player: player,
        );
        game.eventLog.add(result);

        // Advance and start next turn.
        _advanceToNextPlayer(game);
        game.activeTurn = _turnMachine.startNewTurn(
          playerId: game.currentPlayer.id,
        );
        return game;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — Player rotation
  // ---------------------------------------------------------------------------

  void _advanceToNextPlayer(GameState game) {
    game.currentPlayerIndex =
        (game.currentPlayerIndex + 1) % game.players.length;
  }
}
