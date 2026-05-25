// =============================================================================
// ai_player.dart
// Kubiyot Dice Game — AI Decision Engine
//
// Pure Dart — zero Flutter dependencies.
// =============================================================================

import 'dart:math';
import 'game_manager.dart';
import 'turn_state_machine.dart';
import 'scoring_calculator.dart';
import 'player_manager.dart';

// -----------------------------------------------------------------------------
// ENUMS / DATA TYPES
// -----------------------------------------------------------------------------

enum AiDifficulty { easy, medium, hard }

enum AiDecisionType { roll, bank, selectDice, steal, skipSteal }

class AiDecision {
  final AiDecisionType type;
  final List<int>? diceIndices; // only set for selectDice

  const AiDecision({required this.type, this.diceIndices});
}

// -----------------------------------------------------------------------------
// AI PLAYER
// -----------------------------------------------------------------------------

class AiPlayer {
  final Random _random;

  AiPlayer([Random? random]) : _random = random ?? Random();

  // Farkle probabilities for N dice.
  static const Map<int, double> farkleProb = {
    1: 0.667,
    2: 0.444,
    3: 0.278,
    4: 0.139,
    5: 0.040,
  };

  // Rough expected additional score from rolling N dice in a non-farkle turn.
  static const Map<int, double> _avgRollYield = {
    1: 30.0,
    2: 80.0,
    3: 175.0,
    4: 300.0,
    5: 480.0,
  };

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  AiDecision decide({
    required GameState game,
    TurnState? turn,
    required AiDifficulty difficulty,
  }) {
    if (game.phase == GamePhase.stealWindow) {
      return _decideSteal(game, difficulty);
    }

    if (turn == null) return const AiDecision(type: AiDecisionType.roll);

    switch (turn.phase) {
      case TurnPhase.waitingToRoll:
      case TurnPhase.forcedContinue:
      case TurnPhase.hotDiceForced:
        return const AiDecision(type: AiDecisionType.roll);
      case TurnPhase.awaitingSelection:
        return _decideSelection(turn, difficulty);
      case TurnPhase.bankingDecision:
        return _decideBanking(game, turn, difficulty);
      case TurnPhase.turnComplete:
        return const AiDecision(type: AiDecisionType.roll);
    }
  }

  // ---------------------------------------------------------------------------
  // Dice selection
  // ---------------------------------------------------------------------------

  AiDecision _decideSelection(TurnState turn, AiDifficulty difficulty) {
    final allIndices =
        turn.rollHistory.last.scoringDice.map((d) => d.index).toList();

    if (difficulty == AiDifficulty.easy) {
      return AiDecision(type: AiDecisionType.selectDice, diceIndices: allIndices);
    }
    // Medium and hard both use EV-optimised selection.
    return AiDecision(
      type: AiDecisionType.selectDice,
      diceIndices: _selectDiceHard(turn),
    );
  }

  // Evaluates whether keeping fewer single-die scorers (5s then 1s) and
  // rolling one more die improves expected value.
  List<int> _selectDiceHard(TurnState turn) {
    final lastResult = turn.rollHistory.last;
    final setAsideAlready = turn.isTheftTurn
        ? (5 - (turn.theftContext?.availableDiceCount ?? 5))
        : turn.setAsideDice.length;

    // Separate scoring contributions.
    final alwaysKeep = <ScoredDie>[];
    final optional = <ScoredDie>[]; // single 1s and 5s only

    for (final contrib in lastResult.contributions) {
      if (contrib.pattern == ScoringPattern.singleOne ||
          contrib.pattern == ScoringPattern.singleFive) {
        optional.addAll(contrib.dice);
      } else {
        alwaysKeep.addAll(contrib.dice);
      }
    }

    // Remove optional dice starting with lowest value (5s before 1s).
    optional.sort((a, b) => b.face.value.compareTo(a.face.value));

    while (optional.isNotEmpty && alwaysKeep.length + optional.length > 1) {
      final candidate = optional.first;
      final dieValue = candidate.face == DiceFace.one ? 100.0 : 50.0;

      final totalSelected = alwaysKeep.length + optional.length;
      final diceLeftWith = 5 - setAsideAlready - totalSelected;
      final diceLeftWithout = diceLeftWith + 1;

      if (diceLeftWith < 1) break;

      final evWith = dieValue + (_avgRollYield[diceLeftWith] ?? 0);
      final evWithout = _avgRollYield[diceLeftWithout.clamp(1, 5)] ?? 0;

      if (evWithout > evWith) {
        optional.removeAt(0);
      } else {
        break;
      }
    }

    final selected = [...alwaysKeep, ...optional];
    if (selected.isEmpty) {
      return [lastResult.scoringDice.first.index];
    }
    return selected.map((d) => d.index).toList();
  }

  // ---------------------------------------------------------------------------
  // Banking decision
  // ---------------------------------------------------------------------------

  AiDecision _decideBanking(GameState game, TurnState turn, AiDifficulty difficulty) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return _decideBankingEasy(game, turn);
      case AiDifficulty.medium:
        return _decideBankingMedium(game, turn);
      case AiDifficulty.hard:
        return _decideBankingHard(game, turn);
    }
  }

  AiDecision _decideBankingEasy(GameState game, TurnState turn) {
    final player = game.currentPlayer;
    final remaining = turn.availableDiceCount;

    if (player.consecutiveXCount == 2 && turn.temporaryScore >= 300) {
      return const AiDecision(type: AiDecisionType.bank);
    }
    if (turn.temporaryScore >= 400 && remaining <= 2) {
      return const AiDecision(type: AiDecisionType.bank);
    }
    return const AiDecision(type: AiDecisionType.roll);
  }

  AiDecision _decideBankingMedium(GameState game, TurnState turn) {
    final hard = _decideBankingHard(game, turn);
    if (_random.nextDouble() < 0.25) {
      return hard.type == AiDecisionType.bank
          ? const AiDecision(type: AiDecisionType.roll)
          : const AiDecision(type: AiDecisionType.bank);
    }
    return hard;
  }

  AiDecision _decideBankingHard(GameState game, TurnState turn) {
    final player = game.currentPlayer;
    final remaining = turn.availableDiceCount;
    final newScore = player.currentScore + turn.temporaryScore;

    // Check for stomp opportunity.
    final stompTarget = game.players
        .where((p) => p.id != player.id && p.currentScore == newScore)
        .firstOrNull;

    if (stompTarget != null && _evaluateStompHard(player, stompTarget, turn)) {
      return const AiDecision(type: AiDecisionType.bank);
    }

    // Own score above 8 000 — bank conservatively.
    if (player.currentScore > 8000) {
      return const AiDecision(type: AiDecisionType.bank);
    }

    // Lower threshold when an opponent is close to winning.
    final threshold =
        game.players.any((p) => p.id != player.id && p.currentScore > 8000)
            ? 0.20
            : 0.30;

    final prob = farkleProb[remaining] ?? 0.667;
    return prob < threshold
        ? const AiDecision(type: AiDecisionType.roll)
        : const AiDecision(type: AiDecisionType.bank);
  }

  // worthStomping when victimLoss > myExposure × 1.5
  // myExposure = turn.temporaryScore (the gap the AI creates this turn)
  // Override: always stomp if victim.currentScore > 7000
  bool _evaluateStompHard(Player player, Player victim, TurnState turn) {
    if (victim.currentScore > 7000) return true;

    final victimLoss = victim.currentScore - victim.previousTierScore;
    final myExposure = turn.temporaryScore.toDouble();

    return victimLoss > myExposure * 1.5;
  }

  // ---------------------------------------------------------------------------
  // Steal decision
  // ---------------------------------------------------------------------------

  AiDecision _decideSteal(GameState game, AiDifficulty difficulty) {
    final player = game.currentPlayer;
    final ctx = game.pendingTheftContext!;

    switch (difficulty) {
      case AiDifficulty.easy:
        return _decideStealEasy(player, ctx);
      case AiDifficulty.medium:
        return _decideStealMedium(player, ctx);
      case AiDifficulty.hard:
        return _decideStealHard(player, ctx);
    }
  }

  AiDecision _decideStealEasy(Player player, TheftContext ctx) {
    final steal = ctx.inheritedScore > 600 &&
        ctx.availableDiceCount >= 3 &&
        player.consecutiveXCount < 2;
    return AiDecision(
        type: steal ? AiDecisionType.steal : AiDecisionType.skipSteal);
  }

  AiDecision _decideStealMedium(Player player, TheftContext ctx) {
    final hard = _decideStealHard(player, ctx);
    if (_random.nextDouble() < 0.30) {
      return hard.type == AiDecisionType.steal
          ? const AiDecision(type: AiDecisionType.skipSteal)
          : const AiDecision(type: AiDecisionType.steal);
    }
    return hard;
  }

  AiDecision _decideStealHard(Player player, TheftContext ctx) {
    if (player.consecutiveXCount == 2 && ctx.inheritedScore < 400) {
      return const AiDecision(type: AiDecisionType.skipSteal);
    }

    final pSucceed = 1.0 - (farkleProb[ctx.availableDiceCount] ?? 0.667);
    final expectedGain = pSucceed * (_avgRollYield[ctx.availableDiceCount] ?? 0);
    final freshTurnEv =
        (1.0 - (farkleProb[5] ?? 0.040)) * (_avgRollYield[5] ?? 480);

    final steal = ctx.inheritedScore + expectedGain > freshTurnEv;
    return AiDecision(
        type: steal ? AiDecisionType.steal : AiDecisionType.skipSteal);
  }
}
