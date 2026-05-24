import '../engine/scoring_calculator.dart';
import '../engine/turn_state_machine.dart';

/// Snapshot of a roll that needs to be shown to the player before the game
/// advances. Used for farkle, bust, hot dice, and win outcomes — any case
/// where the engine would otherwise jump past the roll without the player
/// seeing what happened.
class RollReveal {
  /// The dice that were just rolled.
  final List<ScoredDie> rolledDice;

  /// Dice that were locked (set aside) before this roll. Empty for hot dice
  /// (setAsideDice is cleared by the engine when hot dice fires).
  final List<ScoredDie> setAsideDice;

  /// Full scoring result for the rolled dice.
  final ScoringResult scoringResult;

  /// Non-null only for terminal rolls (farkle, bust, win).
  /// Null when isHotDice is true.
  final TurnEndReason? endReason;

  final bool isHotDice;

  /// Number of sentinel placeholders in setAsideDice for theft turns.
  final int sentinelCount;

  /// Display name of the player who rolled.
  final String playerName;

  const RollReveal({
    required this.rolledDice,
    required this.setAsideDice,
    required this.scoringResult,
    required this.playerName,
    this.endReason,
    this.isHotDice = false,
    this.sentinelCount = 0,
  });

  bool get isFarkle =>
      endReason == TurnEndReason.naturalFarkle ||
      endReason == TurnEndReason.hotDiceBust;

  bool get isCeilingBust => endReason == TurnEndReason.ceilingBust;

  bool get isWin => endReason == TurnEndReason.win;
}
