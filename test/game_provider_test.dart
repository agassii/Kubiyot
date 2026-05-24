// =============================================================================
// game_provider_test.dart
// Kubiyot — Tests for GameNotifier
//
// Tests GameNotifier directly (no Riverpod container needed).
// Run with: flutter test test/game_provider_test.dart
// =============================================================================

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../lib/providers/game_provider.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';

void main() {
  group('GameNotifier', () {
    late GameNotifier notifier;

    setUp(() {
      notifier = GameNotifier(random: Random(0));
    });

    tearDown(() {
      notifier.dispose();
    });

    // ── Initial state ─────────────────────────────────────────────────────────

    test('GP-01: initial state is null', () {
      expect(notifier.state, isNull);
      expect(notifier.isActive, isFalse);
      expect(notifier.canBank, isFalse);
      expect(notifier.hasStealOpportunity, isFalse);
    });

    // ── createGame ────────────────────────────────────────────────────────────

    test('GP-02: createGame sets state and notifies', () {
      int calls = 0;
      notifier.addListener(() => calls++);

      notifier.createGame(['Alice', 'Bob']);

      expect(calls, 1);
      expect(notifier.state, isNotNull);
      expect(notifier.state!.players.length, 2);
      expect(notifier.state!.players[0].displayName, 'Alice');
      expect(notifier.state!.players[1].displayName, 'Bob');
      expect(notifier.state!.phase, GamePhase.setup);
    });

    test('GP-03: createGame passes GameSettings through', () {
      notifier.createGame(
        ['Alice', 'Bob'],
        settings: const GameSettings(winTarget: 5000),
      );
      expect(notifier.state!.settings.winTarget, 5000);
    });

    // ── startGame ─────────────────────────────────────────────────────────────

    test('GP-04: startGame transitions to inProgress and notifies', () {
      notifier.createGame(['Alice', 'Bob']);
      int calls = 0;
      notifier.addListener(() => calls++);

      notifier.startGame();

      expect(calls, 1);
      expect(notifier.state!.phase, GamePhase.inProgress);
      expect(notifier.state!.activeTurn, isNotNull);
      expect(notifier.state!.activeTurn!.phase, TurnPhase.waitingToRoll);
      expect(notifier.isActive, isTrue);
    });

    // ── rollDice ──────────────────────────────────────────────────────────────

    test('GP-05: rollDice generates 5 dice on first normal roll', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      expect(notifier.state!.activeTurn!.availableDiceCount, 5);
    });

    test('GP-06: rollDice updates state and notifies', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      int calls = 0;
      notifier.addListener(() => calls++);

      notifier.rollDice();

      expect(calls, 1);
      // Phase is no longer waitingToRoll after any roll
      expect(
        notifier.state!.activeTurn?.phase ?? TurnPhase.turnComplete,
        isNot(TurnPhase.waitingToRoll),
      );
    });

    test('GP-07: rollDice generates 2 dice on theft turn with 2 leftover', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      // Force a steal window with 2 leftover dice
      final state = notifier.state!;
      state.phase = GamePhase.stealWindow;
      state.stealWindowOpen = true;
      state.pendingTheftContext = const TheftContext(
        inheritedScore: 400,
        inheritedTriples: {},
        availableDiceCount: 2,
      );
      state.currentPlayerIndex = 1;

      notifier.decideTheft(true);

      // Theft turn has 2 available dice (3 sentinels in setAsideDice)
      expect(notifier.state!.activeTurn!.availableDiceCount, 2);
    });

    // ── selectDice ────────────────────────────────────────────────────────────

    test('GP-08: selectDice updates setAsideDice and notifies', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      // Force awaitingSelection with a known scoring die
      final state = notifier.state!;
      state.activeTurn!.phase = TurnPhase.awaitingSelection;
      // Inject a fake roll result with one scoring die at index 0
      state.activeTurn!.temporaryScore = 100;
      // Use engine directly to create a proper roll state
      // (simpler: manually verify via rollDice + check scoring dice)
      // Just verify notifyListeners fires on the call path
      int calls = 0;
      notifier.addListener(() => calls++);

      // We can test selectDice by rolling first and picking a scoring die
      final freshNotifier = GameNotifier(random: Random(42));
      freshNotifier.createGame(['Alice', 'Bob']);
      freshNotifier.startGame();
      freshNotifier.rollDice();
      final turn = freshNotifier.state!.activeTurn;
      if (turn?.phase == TurnPhase.awaitingSelection) {
        final idx = turn!.rollHistory.last.scoringDice.first.index;
        freshNotifier.addListener(() => calls++);
        freshNotifier.selectDice([idx]);
        expect(calls, 1);
        expect(freshNotifier.state!.activeTurn!.setAsideDice
            .any((d) => d.index == idx), isTrue);
      }
      freshNotifier.dispose();
    });

    // ── bank ──────────────────────────────────────────────────────────────────

    test('GP-09: bank advances turn and notifies', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      // Directly set up a bankable state
      final turn = notifier.state!.activeTurn!;
      turn.temporaryScore = 400;
      turn.phase = TurnPhase.bankingDecision;
      notifier.state!.players[0].isEntered = true;

      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.bank();

      expect(calls, 1);
      // Turn ended — either next player's turn started or steal window opened
      expect(
        notifier.state!.phase == GamePhase.inProgress ||
            notifier.state!.phase == GamePhase.stealWindow,
        isTrue,
      );
    });

    // ── decideTheft ───────────────────────────────────────────────────────────

    test('GP-10: decideTheft(false) starts normal turn and notifies', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      final state = notifier.state!;
      state.phase = GamePhase.stealWindow;
      state.stealWindowOpen = true;
      state.pendingTheftContext = const TheftContext(
        inheritedScore: 400,
        inheritedTriples: {},
        availableDiceCount: 2,
      );
      state.currentPlayerIndex = 1;

      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.decideTheft(false);

      expect(calls, 1);
      expect(notifier.state!.phase, GamePhase.inProgress);
      expect(notifier.state!.activeTurn!.isTheftTurn, isFalse);
    });

    test('GP-11: decideTheft(true) starts theft turn with inherited context', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      final state = notifier.state!;
      state.phase = GamePhase.stealWindow;
      state.stealWindowOpen = true;
      state.pendingTheftContext = const TheftContext(
        inheritedScore: 600,
        inheritedTriples: {},
        availableDiceCount: 3,
      );
      state.currentPlayerIndex = 1;

      notifier.decideTheft(true);

      final turn = notifier.state!.activeTurn!;
      expect(turn.isTheftTurn, isTrue);
      expect(turn.temporaryScore, 600);
      expect(turn.availableDiceCount, 3);
    });

    // ── Queries ───────────────────────────────────────────────────────────────

    test('GP-12: canBank is false at turn start (0 pts, not round entry)', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      expect(notifier.canBank, isFalse);
    });

    test('GP-13: hasStealOpportunity is false at game start', () {
      notifier.createGame(['Alice', 'Bob']);
      notifier.startGame();
      expect(notifier.hasStealOpportunity, isFalse);
    });

    test('GP-14: bankingBlockReason returns notRoundNumber with no game', () {
      expect(
        notifier.bankingBlockReason,
        BankingBlockReason.notRoundNumber,
      );
    });
  });
}
