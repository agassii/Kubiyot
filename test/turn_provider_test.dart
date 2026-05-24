// =============================================================================
// turn_provider_test.dart
// Kubiyot — Tests for derived turn providers
//
// Uses ProviderContainer directly — no widget tree required.
// Run with: flutter test test/turn_provider_test.dart
// =============================================================================

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lib/providers/game_provider.dart';
import '../lib/providers/turn_provider.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';

void main() {
  group('Turn Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          gameProvider.overrideWith(
            (ref) => GameNotifier(random: Random(0)),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    void createAndStart() {
      container.read(gameProvider).createGame(['Alice', 'Bob']);
      container.read(gameProvider).startGame();
    }

    // ── Before game ──────────────────────────────────────────────────────────

    test('TP-01: all providers return null/default before game', () {
      expect(container.read(currentTurnProvider), isNull);
      expect(container.read(currentPlayerProvider), isNull);
      expect(container.read(gamePhaseProvider), isNull);
      expect(container.read(turnPhaseProvider), isNull);
      expect(container.read(canBankProvider), isFalse);
      expect(container.read(isStealWindowProvider), isFalse);
      expect(
        container.read(bankingBlockReasonProvider),
        BankingBlockReason.notRoundNumber,
      );
    });

    test('TP-02: turnActionsProvider returns none before game', () {
      final actions = container.read(turnActionsProvider);
      expect(actions.canRoll, isFalse);
      expect(actions.mustRoll, isFalse);
      expect(actions.mustSelect, isFalse);
      expect(actions.canBank, isFalse);
      expect(actions.isStealWindow, isFalse);
    });

    // ── After startGame ───────────────────────────────────────────────────────

    test('TP-03: currentTurnProvider is not null after start', () {
      createAndStart();
      expect(container.read(currentTurnProvider), isNotNull);
    });

    test('TP-04: currentPlayerProvider returns Alice first', () {
      createAndStart();
      expect(container.read(currentPlayerProvider)?.displayName, 'Alice');
    });

    test('TP-05: gamePhaseProvider reflects inProgress after start', () {
      createAndStart();
      expect(container.read(gamePhaseProvider), GamePhase.inProgress);
    });

    test('TP-06: turnPhaseProvider is waitingToRoll at turn start', () {
      createAndStart();
      expect(container.read(turnPhaseProvider), TurnPhase.waitingToRoll);
    });

    test('TP-07: turnActionsProvider allows roll at turn start', () {
      createAndStart();
      final actions = container.read(turnActionsProvider);
      expect(actions.canRoll, isTrue);
      expect(actions.mustRoll, isFalse);
      expect(actions.mustSelect, isFalse);
      expect(actions.canBank, isFalse);
      expect(actions.isStealWindow, isFalse);
    });

    test('TP-08: canBankProvider is false at turn start (0 pts)', () {
      createAndStart();
      expect(container.read(canBankProvider), isFalse);
    });

    // ── Phase transitions ─────────────────────────────────────────────────────

    test('TP-09: turnActionsProvider reflects awaitingSelection', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.activeTurn!.phase = TurnPhase.awaitingSelection;
      notifier.notifyListeners();

      final actions = container.read(turnActionsProvider);
      expect(actions.mustSelect, isTrue);
      expect(actions.canRoll, isFalse);
      expect(actions.canBank, isFalse);
    });

    test('TP-10: turnActionsProvider reflects hotDiceForced', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.activeTurn!.phase = TurnPhase.hotDiceForced;
      notifier.notifyListeners();

      final actions = container.read(turnActionsProvider);
      expect(actions.canRoll, isTrue);
      expect(actions.mustRoll, isTrue);
      expect(actions.mustSelect, isFalse);
    });

    test('TP-11: turnActionsProvider reflects forcedContinue', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.activeTurn!.phase = TurnPhase.forcedContinue;
      notifier.notifyListeners();

      final actions = container.read(turnActionsProvider);
      expect(actions.canRoll, isTrue);
      expect(actions.mustRoll, isTrue);
    });

    test('TP-12: turnActionsProvider reflects steal window', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.phase = GamePhase.stealWindow;
      notifier.state!.activeTurn = null;
      notifier.notifyListeners();

      final actions = container.read(turnActionsProvider);
      expect(actions.isStealWindow, isTrue);
      expect(actions.canRoll, isFalse);
    });

    test('TP-13: turnActionsProvider returns none when game complete', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.phase = GamePhase.complete;
      notifier.notifyListeners();

      final actions = container.read(turnActionsProvider);
      expect(actions.canRoll, isFalse);
      expect(actions.mustSelect, isFalse);
      expect(actions.isStealWindow, isFalse);
    });

    test('TP-14: isStealWindowProvider is true when steal window open', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.phase = GamePhase.stealWindow;
      notifier.state!.stealWindowOpen = true;
      notifier.state!.pendingTheftContext = const TheftContext(
        inheritedScore: 400,
        inheritedTriples: {},
        availableDiceCount: 2,
      );
      notifier.notifyListeners();

      expect(container.read(isStealWindowProvider), isTrue);
    });

    // ── canBank integration ───────────────────────────────────────────────────

    test('TP-15: canBankProvider is true when score is round and player entered', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.players[0].isEntered = true;
      notifier.state!.activeTurn!.temporaryScore = 400;
      notifier.state!.activeTurn!.phase = TurnPhase.bankingDecision;
      notifier.notifyListeners();

      expect(container.read(canBankProvider), isTrue);
    });

    test('TP-16: bankingBlockReason is belowEntryThreshold when not entered and score < 400', () {
      createAndStart();
      final notifier = container.read(gameProvider);
      notifier.state!.players[0].isEntered = false;
      notifier.state!.activeTurn!.temporaryScore = 200;
      notifier.state!.activeTurn!.phase = TurnPhase.bankingDecision;
      notifier.notifyListeners();

      expect(
        container.read(bankingBlockReasonProvider),
        BankingBlockReason.belowEntryThreshold,
      );
    });
  });
}
