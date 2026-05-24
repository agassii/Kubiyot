// =============================================================================
// game_manager_test.dart
// Kubiyot — Full Test Suite for GameManager
//
// Covers: game lifecycle, turn rotation, theft window, win condition,
//         bust handling, stomp via banking, and end-to-end scenarios.
// Run with: dart test test/game_manager_test.dart
// =============================================================================

import 'package:test/test.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';
import '../lib/engine/player_manager.dart';
import '../lib/engine/scoring_calculator.dart';

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

/// Creates and starts a 2-player game.
GameState twoPlayerGame(GameManager gm) {
  final game = gm.createGame(playerNames: ['Alice', 'Bob']);
  return gm.startGame(game);
}

/// Simulate a full turn: roll, select all scoring dice, bank.
/// Auto-declines any steal window that opens after banking.
/// Returns updated game. Assumes the roll has at least one scoring die.
GameState simulateBankingTurn({
  required GameManager gm,
  required GameState game,
  required List<int> roll,
  required List<int> selectIndices,
}) {
  gm.processRoll(game: game, rolledFaces: roll);
  if (game.activeTurn?.phase == TurnPhase.awaitingSelection) {
    gm.processSelection(game: game, selectedDiceIndices: selectIndices);
  }
  if (game.activeTurn?.phase == TurnPhase.bankingDecision) {
    gm.processBank(game);
  }
  // If banking opened a steal window, auto-decline so rotation continues.
  if (game.phase == GamePhase.stealWindow) {
    gm.processTheftDecision(game: game, steal: false);
  }
  return game;
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

void main() {
  late GameManager gm;

  setUp(() => gm = GameManager());

  // ===========================================================================
  // GAME SETUP & LIFECYCLE
  // ===========================================================================
  group('Game Setup & Lifecycle', () {
    test('GL-01: createGame builds correct player list', () {
      final game = gm.createGame(playerNames: ['Alice', 'Bob', 'Carol']);
      expect(game.players.length, 3);
      expect(game.players.map((p) => p.displayName).toList(),
          ['Alice', 'Bob', 'Carol']);
      expect(game.phase, GamePhase.setup);
    });

    test('GL-02: startGame transitions to inProgress', () {
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      expect(game.phase, GamePhase.inProgress);
      expect(game.activeTurn, isNotNull);
      expect(game.currentPlayer.displayName, 'Alice');
    });

    test('GL-03: turn advances to next player after bust', () {
      final game = twoPlayerGame(gm);
      // Alice Farkles
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);
      expect(game.currentPlayer.displayName, 'Bob');
    });

    test('GL-04: turn advances after banking', () {
      final game = twoPlayerGame(gm);
      simulateBankingTurn(
        gm: gm,
        game: game,
        roll: [4, 4, 4, 2, 3],
        selectIndices: [0, 1, 2],
      );
      expect(game.currentPlayer.displayName, 'Bob');
    });

    test('GL-05: turn rotation wraps around', () {
      final game = twoPlayerGame(gm);
      // Alice busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);
      expect(game.currentPlayer.displayName, 'Bob');
      // Bob busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);
      // Back to Alice
      expect(game.currentPlayer.displayName, 'Alice');
    });

    test('GL-06: createGame requires at least 2 players', () {
      expect(
        () => gm.createGame(playerNames: ['Solo']),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ===========================================================================
  // ENTRY THRESHOLD
  // ===========================================================================
  group('Entry Threshold', () {
    test('ET-01: player cannot bank below 400 when not entered', () {
      final game = twoPlayerGame(gm);
      // Alice rolls [5][2][2][6][6] = 50 pts
      gm.processRoll(game: game, rolledFaces: [5, 2, 2, 6, 6]);
      gm.processSelection(game: game, selectedDiceIndices: [0]);

      // Score = 50 → forcedContinue (not round AND below threshold)
      expect(game.activeTurn!.phase, TurnPhase.forcedContinue);
      expect(gm.canCurrentPlayerBank(game), false);
    });

    test('ET-02: player can bank exactly 400 when not entered', () {
      final game = twoPlayerGame(gm);
      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);

      expect(game.activeTurn!.temporaryScore, 400);
      expect(gm.canCurrentPlayerBank(game), true);
    });

    test('ET-03: after entry, player can bank 200', () {
      final game = twoPlayerGame(gm);
      // Alice enters with 400
      simulateBankingTurn(
        gm: gm,
        game: game,
        roll: [4, 4, 4, 2, 3],
        selectIndices: [0, 1, 2],
      );
      // Bob busts to keep rotation
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);

      // Alice now entered — can bank 200
      gm.processRoll(game: game, rolledFaces: [1, 1, 2, 3, 4]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1]);
      expect(game.activeTurn!.temporaryScore, 200);
      expect(gm.canCurrentPlayerBank(game), true);
    });
  });

  // ===========================================================================
  // BUST HANDLING
  // ===========================================================================
  group('Bust Handling', () {
    test('BH-01: natural farkle records X, score unchanged', () {
      final game = twoPlayerGame(gm);
      // Give Alice some score first
      simulateBankingTurn(
        gm: gm,
        game: game,
        roll: [4, 4, 4, 2, 3],
        selectIndices: [0, 1, 2],
      );
      // Bob busts to pass
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);
      // Alice farkles
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);

      final alice = game.players[0];
      expect(alice.currentScore, 400); // unchanged
      expect(alice.consecutiveXCount, 1);
    });

    test('BH-02: 3 consecutive X burns tier', () {
      final game = twoPlayerGame(gm);

      // Alice banks 400, then 500 → tiers [0, 400, 900]
      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts
      simulateBankingTurn(
          gm: gm, game: game, roll: [5, 5, 5, 2, 3], selectIndices: [0, 1, 2]);
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts

      final alice = game.players[0];
      expect(alice.currentScore, 900);
      expect(alice.scoreTiers, [0, 400, 900]);

      // Alice gets 3 X's
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // X1
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // X2
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // X3 → tier burned

      expect(alice.currentScore, 400); // dropped from 900
      expect(alice.scoreTiers, [0, 400]);
      expect(alice.consecutiveXCount, 0);
    });

    test('BH-03: ceiling bust records X and wipes turn', () {
      final game = twoPlayerGame(gm);
      final alice = game.players[0];

      // Manually set Alice to 9800 banked
      alice.scoreTiers.add(9800);
      alice.isEntered = true;

      // Alice rolls and would exceed 10000
      gm.processRoll(game: game, rolledFaces: [1, 5, 2, 3, 4]); // 150 pts → 9950 → bust
      expect(alice.currentScore, 9800); // unchanged
      expect(alice.consecutiveXCount, 1);
    });
  });

  // ===========================================================================
  // WIN CONDITION
  // ===========================================================================
  group('Win Condition', () {
    test('WC-01: reaching exactly 10000 ends game immediately', () {
      final game = twoPlayerGame(gm);
      final alice = game.players[0];

      alice.scoreTiers.add(9800);
      alice.isEntered = true;

      // Alice rolls [1][1] = 200 → exactly 10000 → WIN detected at roll time
      gm.processRoll(game: game, rolledFaces: [1, 1, 2, 3, 4]);

      expect(game.phase, GamePhase.complete);
      expect(game.winnerId, alice.id);
      expect(alice.currentScore, 10000);
    });

    test('WC-02: exceeding 10000 is a bust, not a win', () {
      final game = twoPlayerGame(gm);
      final alice = game.players[0];

      alice.scoreTiers.add(9800);
      alice.isEntered = true;

      // Alice rolls 300 → 10100 → ceiling bust
      gm.processRoll(game: game, rolledFaces: [3, 3, 3, 2, 4]); // 300 pts
      expect(game.phase, GamePhase.inProgress);
      expect(alice.currentScore, 9800); // unchanged
      expect(alice.consecutiveXCount, 1);
    });

    test('WC-03: game continues normally before win', () {
      final game = twoPlayerGame(gm);
      expect(game.phase, GamePhase.inProgress);
      expect(game.isComplete, false);
    });
  });

  // ===========================================================================
  // THEFT WINDOW
  // ===========================================================================
  group('Theft Window', () {
    test('TW-01: steal window opens after bank with leftover dice', () {
      final game = twoPlayerGame(gm);
      // Alice banks [4][4][4] with 2 leftover dice
      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);

      expect(game.phase, GamePhase.stealWindow);
      expect(game.stealWindowOpen, true);
      expect(game.pendingTheftContext, isNotNull);
      expect(game.pendingTheftContext!.availableDiceCount, 2);
    });

    test('TW-02: steal window does NOT open after hot dice bank (0 leftover)', () {
      final game = twoPlayerGame(gm);
      // Alice rolls straight [1][2][3][4][5] → hot dice → must re-roll
      gm.processRoll(game: game, rolledFaces: [1, 2, 3, 4, 5]);
      // After hot dice forced re-roll, if she banks, 0 leftover dice
      // Simulate: she gets a farkle on hot dice re-roll → bust
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);

      // Turn busted — no steal window
      expect(game.phase, GamePhase.inProgress);
      expect(game.stealWindowOpen, false);
    });

    test('TW-03: next player passes on theft → normal turn starts', () {
      final game = twoPlayerGame(gm);
      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);

      expect(game.phase, GamePhase.stealWindow);

      // Bob passes on theft
      gm.processTheftDecision(game: game, steal: false);
      expect(game.phase, GamePhase.inProgress);
      expect(game.currentPlayer.displayName, 'Bob');
      expect(game.activeTurn, isNotNull);
      expect(game.activeTurn!.isTheftTurn, false);
    });

    test('TW-04: next player steals → theft turn starts with inherited context', () {
      final game = twoPlayerGame(gm);
      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);

      // Bob steals
      gm.processTheftDecision(game: game, steal: true);

      expect(game.phase, GamePhase.inProgress);
      expect(game.activeTurn!.isTheftTurn, true);
      expect(game.activeTurn!.temporaryScore, 400); // inherited from Alice
      expect(game.activeTurn!.setAsideTriples.containsKey(DiceFace.four), true);
    });

    test('TW-05: thief busts → X on thief, Alice keeps banked score', () {
      final game = twoPlayerGame(gm);
      final alice = game.players[0];
      final bob = game.players[1];

      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);

      expect(alice.currentScore, 400);

      // Bob steals and busts
      gm.processTheftDecision(game: game, steal: true);
      gm.processRoll(game: game, rolledFaces: [2, 3]);

      // Bob gets X, Alice keeps 400
      expect(alice.currentScore, 400); // unchanged
      expect(bob.consecutiveXCount, 1);
    });

    test('TW-06: theft context carries triple for complementary rule', () {
      final game = twoPlayerGame(gm);
      gm.processRoll(game: game, rolledFaces: [4, 4, 4, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);

      gm.processTheftDecision(game: game, steal: true);

      final turn = game.activeTurn!;
      expect(turn.setAsideTriples[DiceFace.four], 1);
    });
  });

  // ===========================================================================
  // STOMP VIA BANKING
  // ===========================================================================
  group('Stomp via Banking', () {
    test('ST-01: player banks onto another player score → stomp', () {
      final game = twoPlayerGame(gm);
      final alice = game.players[0];
      final bob = game.players[1];

      // Alice banks 400
      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);

      // Bob banks 400 → lands on Alice's score
      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);

      // Alice should be stomped → drops to 0
      expect(bob.currentScore, 400);
      expect(alice.currentScore, 0); // stomped back to previous tier
    });

    test('ST-02: event log records stomp event', () {
      final game = twoPlayerGame(gm);

      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);
      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);

      final allEvents = game.eventLog.expand((r) => r.events).toList();
      final stompEvents = allEvents
          .where((e) => e.type == PlayerEventType.stomped)
          .toList();
      expect(stompEvents.length, 1);
    });
  });

  // ===========================================================================
  // END-TO-END SCENARIO
  // ===========================================================================
  group('End-to-End Scenario', () {
    test('E2E-01: full 2-player game to completion', () {
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);

      final alice = game.players[0];

      // Manually advance Alice to 9800 via score tiers
      alice.scoreTiers.add(9800);
      alice.isEntered = true;

      // Alice goes first — bust her to pass to Bob
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Alice busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // Bob busts

      // Alice's turn: 9800 + 200 = 10000 → WIN detected at roll time
      gm.processRoll(game: game, rolledFaces: [1, 1, 2, 3, 4]);

      expect(game.isComplete, true);
      expect(game.winner?.displayName, 'Alice');
    });

    test('E2E-02: event log grows with each action', () {
      final game = twoPlayerGame(gm);

      // Alice banks
      simulateBankingTurn(
          gm: gm, game: game, roll: [4, 4, 4, 2, 3], selectIndices: [0, 1, 2]);
      // Bob busts
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]);

      expect(game.eventLog.length, 2); // bank + bust
    });

    test('E2E-03: 3-player rotation is correct', () {
      final game = gm.createGame(playerNames: ['A', 'B', 'C']);
      gm.startGame(game);

      expect(game.currentPlayer.displayName, 'A');
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // A busts
      expect(game.currentPlayer.displayName, 'B');
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // B busts
      expect(game.currentPlayer.displayName, 'C');
      gm.processRoll(game: game, rolledFaces: [2, 3, 4, 6, 6]); // C busts
      expect(game.currentPlayer.displayName, 'A'); // back to A
    });
  });
}
