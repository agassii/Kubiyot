// =============================================================================
// game_state_serializer_test.dart
// Kubiyot — Tests for GameStateSerializer
//
// Strategy: round-trip every field through toMap → fromMap and verify
// the restored GameState is structurally identical to the original.
// No Hive, no Flutter — pure Dart.
// Run with: dart test test/game_state_serializer_test.dart
// =============================================================================

import 'package:test/test.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';
import '../lib/engine/player_manager.dart';
import '../lib/engine/scoring_calculator.dart';
import '../lib/services/game_state_serializer.dart';

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

GameState _restore(GameState game) =>
    GameStateSerializer.fromMap(GameStateSerializer.toMap(game));

void _expectPlayersMatch(List<Player> a, List<Player> b) {
  expect(a.length, b.length, reason: 'player count');
  for (int i = 0; i < a.length; i++) {
    expect(a[i].id, b[i].id, reason: 'player[$i].id');
    expect(a[i].displayName, b[i].displayName, reason: 'player[$i].displayName');
    expect(a[i].scoreTiers, b[i].scoreTiers, reason: 'player[$i].scoreTiers');
    expect(a[i].consecutiveXCount, b[i].consecutiveXCount,
        reason: 'player[$i].consecutiveXCount');
    expect(a[i].isEntered, b[i].isEntered, reason: 'player[$i].isEntered');
    expect(a[i].tierHistory.length, b[i].tierHistory.length,
        reason: 'player[$i].tierHistory.length');
    for (int j = 0; j < a[i].tierHistory.length; j++) {
      expect(a[i].tierHistory[j].score, b[i].tierHistory[j].score,
          reason: 'player[$i].tierHistory[$j].score');
      expect(a[i].tierHistory[j].xCount, b[i].tierHistory[j].xCount,
          reason: 'player[$i].tierHistory[$j].xCount');
      expect(a[i].tierHistory[j].burned, b[i].tierHistory[j].burned,
          reason: 'player[$i].tierHistory[$j].burned');
    }
  }
}

void _expectDiceMatch(List<ScoredDie> a, List<ScoredDie> b, String label) {
  expect(a.length, b.length, reason: '$label length');
  for (int i = 0; i < a.length; i++) {
    expect(a[i].index, b[i].index, reason: '$label[$i].index');
    expect(a[i].face, b[i].face, reason: '$label[$i].face');
  }
}

void _expectTriplesMatch(Map<DiceFace, int> a, Map<DiceFace, int> b) {
  expect(a.length, b.length, reason: 'triples map size');
  for (final face in a.keys) {
    expect(b[face], a[face], reason: 'triples[$face]');
  }
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // SS — Basic field serialization
  // ===========================================================================
  group('SS — GameState round-trip', () {

    test('SS-01: setup phase — no active turn', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);

      final r = _restore(game);

      expect(r.gameId, game.gameId);
      expect(r.phase, GamePhase.setup);
      expect(r.currentPlayerIndex, 0);
      expect(r.stealWindowOpen, false);
      expect(r.winnerId, isNull);
      expect(r.activeTurn, isNull);
      expect(r.pendingTheftContext, isNull);
      expect(r.eventLog, isEmpty);
      _expectPlayersMatch(r.players, game.players);
    });

    test('SS-02: inProgress phase — waitingToRoll turn', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);

      final r = _restore(game);

      expect(r.phase, GamePhase.inProgress);
      expect(r.activeTurn, isNotNull);
      expect(r.activeTurn!.playerId, 'p1');
      expect(r.activeTurn!.phase, TurnPhase.waitingToRoll);
      expect(r.activeTurn!.temporaryScore, 0);
      expect(r.activeTurn!.isTheftTurn, false);
      expect(r.activeTurn!.rollNumber, 0);
      expect(r.activeTurn!.hotDiceCount, 0);
      expect(r.activeTurn!.currentRoll, isEmpty);
      expect(r.activeTurn!.setAsideDice, isEmpty);
      expect(r.activeTurn!.rollHistory, isEmpty);
      expect(r.activeTurn!.setAsideTriples, isEmpty);
    });

    test('SS-03: turn with roll — awaitingSelection phase', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      // [1,1,1,2,3] → three 1s = 1000; non-scoring: 2, 3
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 2, 3]);

      final r = _restore(game);

      expect(r.activeTurn!.phase, TurnPhase.awaitingSelection);
      expect(r.activeTurn!.rollNumber, 1);
      expect(r.activeTurn!.temporaryScore, 0); // score added in processSelection, not processRoll
      expect(r.activeTurn!.currentRoll.length, 5);
      expect(r.activeTurn!.currentRoll[0].face, DiceFace.one);
      expect(r.activeTurn!.currentRoll[3].face, DiceFace.two);
      expect(r.activeTurn!.rollHistory.length, 1);
      expect(r.activeTurn!.rollHistory[0].rollPoints, 1000);
      expect(r.activeTurn!.rollHistory[0].isFarkle, false);
      expect(r.activeTurn!.rollHistory[0].scoringDice.length, 3);
      _expectDiceMatch(
        r.activeTurn!.currentRoll,
        game.activeTurn!.currentRoll,
        'currentRoll',
      );
    });

    test('SS-04: setAsideTriples preserved after selection', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 2, 3]);
      // Select [1,1,1] (indices 0,1,2) → setAsideTriples = {one: 1}
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);

      final r = _restore(game);

      expect(r.activeTurn!.setAsideDice.length, 3);
      _expectDiceMatch(
        r.activeTurn!.setAsideDice,
        game.activeTurn!.setAsideDice,
        'setAsideDice',
      );
      _expectTriplesMatch(
        r.activeTurn!.setAsideTriples,
        {DiceFace.one: 1},
      );
    });

    test('SS-05: player with multiple score tiers and X count', () {
      final alice = Player(
        id: 'p1',
        displayName: 'Alice',
        scoreTiers: [0, 400, 900, 1500],
        consecutiveXCount: 2,
        isEntered: true,
      );
      final game = GameState(
        gameId: 'g1',
        players: [alice, Player(id: 'p2', displayName: 'Bob')],
        settings: const GameSettings(),
        phase: GamePhase.inProgress,
      );

      final r = _restore(game);

      final p = r.players[0];
      expect(p.scoreTiers, [0, 400, 900, 1500]);
      expect(p.consecutiveXCount, 2);
      expect(p.isEntered, true);
    });

    test('SS-06: custom GameSettings round-trip', () {
      final game = GameState(
        gameId: 'g1',
        players: [
          Player(id: 'p1', displayName: 'Alice'),
          Player(id: 'p2', displayName: 'Bob'),
        ],
        settings: const GameSettings(
          winTarget: 5000,
          entryThreshold: 200,
          hotDiceBonus: 300,
          ceilingBustCountsAsX: false,
        ),
      );

      final r = _restore(game);

      expect(r.settings.winTarget, 5000);
      expect(r.settings.entryThreshold, 200);
      expect(r.settings.hotDiceBonus, 300);
      expect(r.settings.ceilingBustCountsAsX, false);
    });

    test('SS-07: stealWindow phase with pendingTheftContext', () {
      final ctx = const TheftContext(
        inheritedScore: 600,
        inheritedTriples: {DiceFace.three: 1, DiceFace.five: 1},
        availableDiceCount: 2,
      );
      final game = GameState(
        gameId: 'g1',
        players: [
          Player(id: 'p1', displayName: 'Alice'),
          Player(id: 'p2', displayName: 'Bob'),
        ],
        settings: const GameSettings(),
        phase: GamePhase.stealWindow,
        stealWindowOpen: true,
        pendingTheftContext: ctx,
      );

      final r = _restore(game);

      expect(r.phase, GamePhase.stealWindow);
      expect(r.stealWindowOpen, true);
      expect(r.pendingTheftContext!.inheritedScore, 600);
      expect(r.pendingTheftContext!.availableDiceCount, 2);
      _expectTriplesMatch(
        r.pendingTheftContext!.inheritedTriples,
        {DiceFace.three: 1, DiceFace.five: 1},
      );
    });

    test('SS-08: complete phase with winner', () {
      final game = GameState(
        gameId: 'g1',
        players: [
          Player(
            id: 'p1',
            displayName: 'Alice',
            scoreTiers: [0, 10000],
            isEntered: true,
          ),
          Player(id: 'p2', displayName: 'Bob'),
        ],
        settings: const GameSettings(),
        phase: GamePhase.complete,
        winnerId: 'p1',
      );

      final r = _restore(game);

      expect(r.phase, GamePhase.complete);
      expect(r.winnerId, 'p1');
      expect(r.activeTurn, isNull);
    });

    test('SS-09: eventLog with banked and stomped events', () {
      const events = [
        ScoreChangeResult(
          events: [
            PlayerEvent(
              playerId: 'p1',
              type: PlayerEventType.banked,
              scoreBefore: 0,
              scoreAfter: 500,
            ),
            PlayerEvent(
              playerId: 'p2',
              type: PlayerEventType.stomped,
              scoreBefore: 500,
              scoreAfter: 0,
              triggeredByPlayerId: 'p1',
            ),
          ],
        ),
      ];
      final game = GameState(
        gameId: 'g1',
        players: [
          Player(id: 'p1', displayName: 'Alice'),
          Player(id: 'p2', displayName: 'Bob'),
        ],
        settings: const GameSettings(),
        eventLog: events,
      );

      final r = _restore(game);

      expect(r.eventLog.length, 1);
      expect(r.eventLog[0].events.length, 2);
      expect(r.eventLog[0].events[0].type, PlayerEventType.banked);
      expect(r.eventLog[0].events[0].scoreBefore, 0);
      expect(r.eventLog[0].events[0].scoreAfter, 500);
      expect(r.eventLog[0].events[1].type, PlayerEventType.stomped);
      expect(r.eventLog[0].events[1].triggeredByPlayerId, 'p1');
    });

    test('SS-10: theft turn — theftContext preserved in activeTurn', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      // Alice banks 1000 to trigger steal window (2 leftover dice)
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      gm.processBank(game);
      // Now in stealWindow — Bob steals
      gm.processTheftDecision(game: game, steal: true);
      // Bob is now in a theft turn with theftContext

      expect(game.activeTurn!.isTheftTurn, true);
      expect(game.activeTurn!.theftContext, isNotNull);

      final r = _restore(game);

      expect(r.activeTurn!.isTheftTurn, true);
      expect(r.activeTurn!.theftContext, isNotNull);
      expect(
        r.activeTurn!.theftContext!.inheritedScore,
        game.activeTurn!.theftContext!.inheritedScore,
      );
      expect(
        r.activeTurn!.theftContext!.availableDiceCount,
        game.activeTurn!.theftContext!.availableDiceCount,
      );
      // Sentinel placeholders in setAsideDice must survive the round-trip
      expect(
        r.activeTurn!.setAsideDice.length,
        game.activeTurn!.setAsideDice.length,
      );
    });

    test('SS-12: player tierHistory round-trips correctly', () {
      final alice = Player(
        id: 'p1',
        displayName: 'Alice',
        scoreTiers: [0, 900],
        consecutiveXCount: 1,
        isEntered: true,
        tierHistory: [
          const TierRecord(score: 400, xCount: 1),
          const TierRecord(score: 900, xCount: 3, burned: true),
        ],
      );
      final game = GameState(
        gameId: 'g1',
        players: [alice, Player(id: 'p2', displayName: 'Bob')],
        settings: const GameSettings(),
        phase: GamePhase.inProgress,
      );
      final r = _restore(game);
      final p = r.players[0];
      expect(p.tierHistory.length, 2);
      expect(p.tierHistory[0].score, 400);
      expect(p.tierHistory[0].xCount, 1);
      expect(p.tierHistory[0].burned, false);
      expect(p.tierHistory[1].score, 900);
      expect(p.tierHistory[1].xCount, 3);
      expect(p.tierHistory[1].burned, true);
    });

    test('SS-11: encode/decode (JSON string path)', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);

      final json = GameStateSerializer.encode(game);
      final r = GameStateSerializer.decode(json);

      expect(r.gameId, game.gameId);
      expect(r.phase, game.phase);
      _expectPlayersMatch(r.players, game.players);
    });
  });

  // ===========================================================================
  // SS-FUNC — Functional: deserialized game can be continued by GameManager
  // ===========================================================================
  group('SS-FUNC — functional continuation after restore', () {

    test('SS-FUNC-01: can roll remaining dice on restored awaitingSelection turn',
        () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);
      // 3 dice set aside (score=1000), 2 remaining (bankingDecision)

      final restored = _restore(game);

      // Roll the 2 remaining dice — should succeed without assert
      expect(
        () => gm.processRoll(game: restored, rolledFaces: [5, 3]),
        returnsNormally,
      );
      // [5,3] scores [5]=50 → awaitingSelection; select it to add score
      if (restored.activeTurn?.phase == TurnPhase.awaitingSelection) {
        final idx = restored.activeTurn!.rollHistory.last.scoringDice.first.index;
        gm.processSelection(game: restored, selectedDiceIndices: [idx]);
      }
      expect(restored.activeTurn!.temporaryScore, greaterThan(1000));
    });

    test('SS-FUNC-02: can bank on restored bankingDecision turn', () {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 5, 2]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2, 3]);
      // score=1050 — not round, forcedContinue. Let me get a round score instead.
      // Actually [1,1,1,5,2] → three 1s=1000, single 5=50 → score=1050 → NOT round
      // After selection of all 4 scoring dice → forcedContinue
      // Roll the last die [2] — farkle or score
      // Let me just verify the state, then bank on a different state.

      // Use a different setup: roll [1,2,3,4,5] → straight = 1500 (hot dice)
      // Skip that — let's do roll [1,1,1,2,3] select [0,1,2] → score=1000, bankingDecision
      final game2 = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game2);
      gm.processRoll(game: game2, rolledFaces: [1, 1, 1, 2, 3]);
      gm.processSelection(game: game2, selectedDiceIndices: [0, 1, 2]);

      expect(game2.activeTurn!.phase, TurnPhase.bankingDecision);
      final restored = _restore(game2);

      expect(() => gm.processBank(restored), returnsNormally);
      // Banking with leftover dice opens a stealWindow for Bob
      expect(restored.players[0].currentScore, 1000); // Alice banked 1000
      expect(restored.currentPlayerIndex, 1); // advanced to Bob
    });
  });
}
