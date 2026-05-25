// =============================================================================
// ai_player_test.dart
// Kubiyot — AI Player Decision Engine Tests
// =============================================================================

import 'package:test/test.dart';
import '../lib/engine/ai_player.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';
import '../lib/engine/player_manager.dart';
import '../lib/engine/scoring_calculator.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

Player _makePlayer({
  required String id,
  required List<int> scoreTiers,
  int consecutiveXCount = 0,
  bool isEntered = true,
}) =>
    Player(
      id: id,
      displayName: id,
      scoreTiers: scoreTiers,
      consecutiveXCount: consecutiveXCount,
      isEntered: isEntered,
    );

GameState _makeGame({
  required List<Player> players,
  int currentPlayerIndex = 0,
  GamePhase phase = GamePhase.inProgress,
  TheftContext? pendingTheftContext,
}) =>
    GameState(
      gameId: 'test',
      players: players,
      settings: const GameSettings(),
      phase: phase,
      currentPlayerIndex: currentPlayerIndex,
      pendingTheftContext: pendingTheftContext,
    );

// Creates a TurnState at bankingDecision with the given temporaryScore and
// remaining dice count (setAsideCount = 5 - remainingDice).
TurnState _makeBankingTurn({
  required int temporaryScore,
  required int remainingDice,
  String playerId = 'p1',
}) {
  assert(remainingDice >= 1 && remainingDice <= 5);
  return TurnState(
    playerId: playerId,
    isTheftTurn: false,
    phase: TurnPhase.bankingDecision,
    temporaryScore: temporaryScore,
    setAsideDice: List.generate(
      5 - remainingDice,
      (i) => ScoredDie(index: i, face: DiceFace.one),
    ),
    rollNumber: 1,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final ai = AiPlayer();

  // ── Easy AI ─────────────────────────────────────────────────────────────────

  group('Easy AI — banking', () {
    test('banks when score >= 400 AND remaining dice <= 2', () {
      final game = _makeGame(players: [_makePlayer(id: 'p1', scoreTiers: [0])]);
      final turn = _makeBankingTurn(temporaryScore: 400, remainingDice: 2);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.easy).type,
        AiDecisionType.bank,
      );
    });

    test('rolls when score < 400 (even with dice <= 2)', () {
      final game = _makeGame(players: [_makePlayer(id: 'p1', scoreTiers: [0])]);
      final turn = _makeBankingTurn(temporaryScore: 300, remainingDice: 2);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.easy).type,
        AiDecisionType.roll,
      );
    });

    test('rolls when score >= 400 but more than 2 dice remain', () {
      final game = _makeGame(players: [_makePlayer(id: 'p1', scoreTiers: [0])]);
      final turn = _makeBankingTurn(temporaryScore: 400, remainingDice: 3);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.easy).type,
        AiDecisionType.roll,
      );
    });

    test('banks when consecutiveXCount == 2 AND score >= 300', () {
      final game = _makeGame(players: [
        _makePlayer(id: 'p1', scoreTiers: [0], consecutiveXCount: 2),
      ]);
      final turn = _makeBankingTurn(temporaryScore: 300, remainingDice: 3);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.easy).type,
        AiDecisionType.bank,
      );
    });

    test('rolls when consecutiveXCount == 2 but score < 300', () {
      final game = _makeGame(players: [
        _makePlayer(id: 'p1', scoreTiers: [0], consecutiveXCount: 2),
      ]);
      final turn = _makeBankingTurn(temporaryScore: 200, remainingDice: 3);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.easy).type,
        AiDecisionType.roll,
      );
    });
  });

  group('Easy AI — stealing', () {
    test('steals when all conditions met', () {
      final player = _makePlayer(id: 'p1', scoreTiers: [0]);
      final ctx = TheftContext(
          inheritedScore: 700, inheritedTriples: {}, availableDiceCount: 3);
      final game = _makeGame(
        players: [player],
        phase: GamePhase.stealWindow,
        pendingTheftContext: ctx,
      );
      expect(
        ai.decide(game: game, turn: null, difficulty: AiDifficulty.easy).type,
        AiDecisionType.steal,
      );
    });

    test('skips when availableDiceCount < 3', () {
      final player = _makePlayer(id: 'p1', scoreTiers: [0]);
      final ctx = TheftContext(
          inheritedScore: 700, inheritedTriples: {}, availableDiceCount: 2);
      final game = _makeGame(
        players: [player],
        phase: GamePhase.stealWindow,
        pendingTheftContext: ctx,
      );
      expect(
        ai.decide(game: game, turn: null, difficulty: AiDifficulty.easy).type,
        AiDecisionType.skipSteal,
      );
    });

    test('skips when inheritedScore <= 600', () {
      final player = _makePlayer(id: 'p1', scoreTiers: [0]);
      final ctx = TheftContext(
          inheritedScore: 500, inheritedTriples: {}, availableDiceCount: 3);
      final game = _makeGame(
        players: [player],
        phase: GamePhase.stealWindow,
        pendingTheftContext: ctx,
      );
      expect(
        ai.decide(game: game, turn: null, difficulty: AiDifficulty.easy).type,
        AiDecisionType.skipSteal,
      );
    });

    test('skips when consecutiveXCount >= 2', () {
      final player =
          _makePlayer(id: 'p1', scoreTiers: [0], consecutiveXCount: 2);
      final ctx = TheftContext(
          inheritedScore: 700, inheritedTriples: {}, availableDiceCount: 3);
      final game = _makeGame(
        players: [player],
        phase: GamePhase.stealWindow,
        pendingTheftContext: ctx,
      );
      expect(
        ai.decide(game: game, turn: null, difficulty: AiDifficulty.easy).type,
        AiDecisionType.skipSteal,
      );
    });
  });

  // ── Hard AI ──────────────────────────────────────────────────────────────────

  group('Hard AI — farkle probability', () {
    test('rolls when farkleProb < 0.30 (4 dice: prob = 0.139)', () {
      // farkleProb[4] = 0.139 < 0.30 → should roll
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 1000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 200]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 600, remainingDice: 4);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.roll,
      );
    });

    test('banks when farkleProb >= 0.30 (2 dice: prob = 0.444)', () {
      // farkleProb[2] = 0.444 >= 0.30 → should bank
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 1000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 200]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 600, remainingDice: 2);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.bank,
      );
    });

    test('rolls with 3 dice (farkleProb = 0.278 < 0.30)', () {
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 1000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 200]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 600, remainingDice: 3);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.roll,
      );
    });
  });

  group('Hard AI — stomp logic', () {
    test('stomps when victimLoss > myExposure * 1.5', () {
      // p1 (AI): scoreTiers = [0, 1000] → currentScore = 1000
      // turn.temporaryScore = 500 → would land at 1500 (stomp p2!)
      // p2 (victim): scoreTiers = [0, 700, 1500] → victimLoss = 1500 - 700 = 800
      // myExposure = 500
      // 800 > 500 * 1.5 = 750 → TRUE → bank
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 1000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 700, 1500]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 500, remainingDice: 4);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.bank,
      );
    });

    test('does NOT stomp when myExposure too high', () {
      // p1 (AI): scoreTiers = [0, 1000] → currentScore = 1000
      // turn.temporaryScore = 500 → would land at 1500 (stomp p2!)
      // p2 (victim): scoreTiers = [0, 1000, 1500] → victimLoss = 1500 - 1000 = 500
      // myExposure = 500
      // 500 > 500 * 1.5 = 750 → FALSE → normal logic
      // Normal: remainingDice = 4, farkleProb[4] = 0.139 < 0.30 → roll
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 1000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 1000, 1500]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 500, remainingDice: 4);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.roll,
      );
    });

    test('always stomps when victim.currentScore > 7000', () {
      // Override regardless of exposure or farkle prob.
      // p1: currentScore=7000, turn.temporaryScore=500 → lands at 7500
      // p2: scoreTiers=[0, 7000, 7500] → victim at 7500 (>7000)
      // Even with 4 dice remaining (farkle prob low → normally roll),
      // the override forces a bank.
      final p1 = _makePlayer(id: 'p1', scoreTiers: [0, 7000]);
      final p2 = _makePlayer(id: 'p2', scoreTiers: [0, 7000, 7500]);
      final game = _makeGame(players: [p1, p2]);
      final turn = _makeBankingTurn(temporaryScore: 500, remainingDice: 4);
      expect(
        ai.decide(game: game, turn: turn, difficulty: AiDifficulty.hard).type,
        AiDecisionType.bank,
      );
    });
  });
}
