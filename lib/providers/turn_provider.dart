import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/player_manager.dart';
import '../engine/turn_state_machine.dart';
import '../models/roll_reveal.dart';
import 'game_provider.dart';

// ── State selectors ───────────────────────────────────────────────────────────

final currentTurnProvider = Provider<TurnState?>((ref) {
  return ref.watch(gameProvider).state?.activeTurn;
});

final currentPlayerProvider = Provider<Player?>((ref) {
  return ref.watch(gameProvider).state?.currentPlayer;
});

final gamePhaseProvider = Provider<GamePhase?>((ref) {
  return ref.watch(gameProvider).state?.phase;
});

final turnPhaseProvider = Provider<TurnPhase?>((ref) {
  return ref.watch(gameProvider).state?.activeTurn?.phase;
});

final canBankProvider = Provider<bool>((ref) {
  return ref.watch(gameProvider).canBank;
});

final bankingBlockReasonProvider = Provider<BankingBlockReason>((ref) {
  return ref.watch(gameProvider).bankingBlockReason;
});

final isStealWindowProvider = Provider<bool>((ref) {
  return ref.watch(gameProvider).hasStealOpportunity;
});

final rollRevealProvider = Provider<RollReveal?>((ref) {
  return ref.watch(gameProvider).rollReveal;
});

// ── Available actions ─────────────────────────────────────────────────────────

/// Snapshot of what the current player is allowed to do right now.
class TurnActions {
  final bool canRoll;
  final bool mustRoll;
  final bool mustSelect;
  final bool canBank;
  final bool isStealWindow;
  final bool isRollReveal;

  const TurnActions({
    this.canRoll = false,
    this.mustRoll = false,
    this.mustSelect = false,
    this.canBank = false,
    this.isStealWindow = false,
    this.isRollReveal = false,
  });

  static const none = TurnActions();
}

final turnActionsProvider = Provider<TurnActions>((ref) {
  // Suppress all normal actions while showing a roll reveal.
  if (ref.watch(rollRevealProvider) != null) {
    return const TurnActions(isRollReveal: true);
  }

  final notifier = ref.watch(gameProvider);
  final game = notifier.state;
  if (game == null || game.isComplete) return TurnActions.none;

  if (game.phase == GamePhase.stealWindow) {
    return const TurnActions(isStealWindow: true);
  }

  final turn = game.activeTurn;
  if (turn == null) return TurnActions.none;

  return switch (turn.phase) {
    TurnPhase.waitingToRoll     => const TurnActions(canRoll: true),
    TurnPhase.hotDiceForced     => const TurnActions(canRoll: true, mustRoll: true),
    TurnPhase.forcedContinue    => const TurnActions(canRoll: true, mustRoll: true),
    TurnPhase.awaitingSelection => const TurnActions(mustSelect: true),
    TurnPhase.bankingDecision   =>
        TurnActions(canRoll: true, canBank: notifier.canBank),
    TurnPhase.turnComplete      => TurnActions.none,
  };
});
