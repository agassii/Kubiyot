// =============================================================================
// turn_state_machine.dart
// Kubiyot Dice Game — Turn State Machine
//
// Responsibilities:
//   1. Manage TurnPhase transitions throughout a single turn
//   2. Enforce the Rounding Rule (can/cannot bank)
//   3. Enforce the Entry Threshold (400+ for first bank)
//   4. Handle Hot Dice lifecycle including the H-03 edge case
//   5. Handle Theft turns (inherited context from previous player)
//   6. Detect win condition (exactly 10,000)
//   7. Detect and classify all bust types
//
// Calls into: ScoringCalculator, HotDiceResolver
// Called by:  GameManager
//
// This file is pure Dart — zero Flutter dependencies.
// =============================================================================

import 'scoring_calculator.dart';

// -----------------------------------------------------------------------------
// ENUMS
// -----------------------------------------------------------------------------

enum TurnPhase {
  waitingToRoll,     // player hasn't rolled yet this turn
  awaitingSelection, // player must select which dice to set aside
  bankingDecision,   // score is round — player can bank OR keep rolling
  forcedContinue,    // score is NOT round — player MUST keep rolling
  hotDiceForced,     // all 5 scored — must re-roll all 5
  turnComplete,      // turn ended (banked, bust, or win)
}

enum TurnEndReason {
  banked,        // player voluntarily banked a round score
  naturalFarkle, // 0 scoring dice rolled
  ceilingBust,   // exceeded 10,000
  hotDiceBust,   // busted on mandatory Hot Dice re-roll
  win,           // reached exactly 10,000
}

enum BankingBlockReason {
  notRoundNumber,      // score ends in 50 — must keep rolling
  belowEntryThreshold, // first bank must be 400+
  none,                // banking is allowed
}

// -----------------------------------------------------------------------------
// TURN CONTEXT — carries inherited state for theft turns
// -----------------------------------------------------------------------------

/// Passed into TurnStateMachine when a player steals a turn.
/// Contains everything inherited from the previous player.
class TheftContext {
  /// Points inherited from the previous player's banked turn score.
  final int inheritedScore;

  /// Triples the previous player set aside (for Complementary Rule).
  final Map<DiceFace, int> inheritedTriples;

  /// How many dice are available to roll (leftover from previous player).
  final int availableDiceCount;

  const TheftContext({
    required this.inheritedScore,
    required this.inheritedTriples,
    required this.availableDiceCount,
  });
}

// -----------------------------------------------------------------------------
// TURN STATE — the full snapshot of a turn at any moment
// -----------------------------------------------------------------------------

class TurnState {
  // ── Identity ────────────────────────────────────────────────────────────────
  final String playerId;
  final bool isTheftTurn;
  final TheftContext? theftContext;

  // ── Phase ───────────────────────────────────────────────────────────────────
  TurnPhase phase;

  // ── Dice ────────────────────────────────────────────────────────────────────
  /// All 5 dice. State tracks which are in pool vs set aside.
  List<ScoredDie> currentRoll;

  /// Dice set aside this turn (accumulates across rolls).
  List<ScoredDie> setAsideDice;

  /// How many dice are available to roll next.
  int get availableDiceCount {
    if (phase == TurnPhase.hotDiceForced) return 5;
    return 5 - setAsideDice.length;
  }

  // ── Scoring ─────────────────────────────────────────────────────────────────
  /// Temporary score accumulated this turn (not yet banked).
  int temporaryScore;

  /// Triples set aside THIS turn (for Complementary Die Rule).
  /// Key = face, value = number of complete triples of that face.
  Map<DiceFace, int> setAsideTriples;

  /// Number of Hot Dice events triggered this turn.
  int hotDiceCount;

  /// Total bonus points from Hot Dice (+200 per trigger).
  int get hotDiceBonus => hotDiceCount * HotDiceResolver.hotDiceBonus;

  // ── Roll history ─────────────────────────────────────────────────────────────
  int rollNumber;
  List<ScoringResult> rollHistory;

  // ── End state ────────────────────────────────────────────────────────────────
  TurnEndReason? endReason;
  int? finalBankedScore; // set when endReason == TurnEndReason.banked or win

  TurnState({
    required this.playerId,
    required this.isTheftTurn,
    this.theftContext,
    this.phase = TurnPhase.waitingToRoll,
    List<ScoredDie>? currentRoll,
    List<ScoredDie>? setAsideDice,
    int? temporaryScore,
    Map<DiceFace, int>? setAsideTriples,
    this.hotDiceCount = 0,
    this.rollNumber = 0,
    List<ScoringResult>? rollHistory,
    this.endReason,
    this.finalBankedScore,
  })  : currentRoll = currentRoll ?? [],
        setAsideDice = setAsideDice ?? [],
        temporaryScore = temporaryScore ?? (theftContext?.inheritedScore ?? 0),
        setAsideTriples = setAsideTriples ?? Map.from(theftContext?.inheritedTriples ?? {}),
        rollHistory = rollHistory ?? [];

  /// Whether the current temporary score is a round number (multiple of 100).
  bool get isRoundScore => temporaryScore % 100 == 0;

  /// Whether the player has used all dice (before Hot Dice re-roll).
  bool get allDiceSetAside => setAsideDice.length == 5;

  @override
  String toString() =>
      'Turn[$playerId] phase=$phase score=$temporaryScore roll=#$rollNumber';
}

// -----------------------------------------------------------------------------
// TURN STATE MACHINE
// -----------------------------------------------------------------------------

class TurnStateMachine {
  final ScoringCalculator _calculator = ScoringCalculator();
  final HotDiceResolver _hotDiceResolver = HotDiceResolver();

  // ---------------------------------------------------------------------------
  // 1. Start a new turn
  // ---------------------------------------------------------------------------

  /// Creates a fresh TurnState for a normal (non-theft) turn.
  TurnState startNewTurn({required String playerId}) {
    return TurnState(
      playerId: playerId,
      isTheftTurn: false,
      phase: TurnPhase.waitingToRoll,
    );
  }

  /// Creates a TurnState for a theft turn.
  /// [context] carries inherited score, triples, and available dice count.
  TurnState startTheftTurn({
    required String playerId,
    required TheftContext context,
  }) {
    // Pre-populate setAsideDice with (5 - N) sentinel dice so that
    // availableDiceCount == N and effective Hot Dice fires when all N score.
    final placeholderCount = 5 - context.availableDiceCount;
    final placeholders = [
      for (int i = 0; i < placeholderCount; i++)
        ScoredDie(index: i, face: DiceFace.six),
    ];
    return TurnState(
      playerId: playerId,
      isTheftTurn: true,
      theftContext: context,
      phase: TurnPhase.waitingToRoll,
      temporaryScore: context.inheritedScore,
      setAsideTriples: Map.from(context.inheritedTriples),
      setAsideDice: placeholders,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Process a roll
  // ---------------------------------------------------------------------------

  /// Call this after the player rolls the dice.
  ///
  /// [state]        — current turn state (mutated in place).
  /// [rolledFaces]  — the face values that came up (only the dice in pool).
  /// [permanentScore] — the player's current banked score (for ceiling check).
  /// [isEntered]    — whether the player has entered the board.
  ///
  /// Returns the updated TurnState.
  TurnState processRoll({
    required TurnState state,
    required List<int> rolledFaces,
    required int permanentScore,
    required bool isEntered,
  }) {
    assert(
      state.phase == TurnPhase.waitingToRoll ||
      state.phase == TurnPhase.hotDiceForced ||
      state.phase == TurnPhase.bankingDecision ||
      state.phase == TurnPhase.forcedContinue,
      'Cannot roll in phase: ${state.phase}',
    );

    // Build ScoredDie list for this roll.
    // Indices continue from where set-aside dice left off.
    final roll = _buildRoll(rolledFaces, state.setAsideDice.length);
    state.currentRoll = roll;
    state.rollNumber++;

    // Score the roll with current set-aside triple context.
    final result = _calculator.scoreRoll(
      rolledDice: roll,
      setAsideTriples: state.setAsideTriples,
    );
    state.rollHistory.add(result);

    // ── Farkle / Bust ────────────────────────────────────────────────────────
    if (result.isFarkle) {
      return _resolveBust(
        state: state,
        reason: state.phase == TurnPhase.hotDiceForced
            ? TurnEndReason.hotDiceBust
            : TurnEndReason.naturalFarkle,
      );
    }

    // ── Hot Dice check — covers theft turns where set-aside total reaches 5 ──
    // In a theft turn, setAsideDice starts pre-populated with (5 - N) sentinels.
    // When the thief scores all N leftover dice, the combined count hits 5.
    final effectivelyHotDice = result.isHotDice ||
        (!result.isFarkle &&
            state.setAsideDice.length + result.scoringDice.length == 5);

    if (effectivelyHotDice) {
      // All scoring dice are auto-set-aside — apply ceiling/win/score now.
      final projected = permanentScore + state.temporaryScore + result.rollPoints;
      if (projected > 10000) {
        return _resolveBust(state: state, reason: TurnEndReason.ceilingBust);
      }
      if (projected == 10000) {
        state.temporaryScore += result.rollPoints;
        return _resolveWin(state);
      }
      state.temporaryScore += result.rollPoints;
      _updateSetAsideContext(state, result, forceSetAside: true);
      return _resolveHotDice(state: state, permanentScore: permanentScore);
    }

    // ── Awaiting selection ────────────────────────────────────────────────────
    // Player chooses which scoring dice to keep; ceiling/win checks and score
    // addition happen in processSelection based on the player's actual choice.
    state.phase = TurnPhase.awaitingSelection;
    return state;
  }

  // ---------------------------------------------------------------------------
  // 3. Process dice selection (player sets aside scoring dice)
  // ---------------------------------------------------------------------------

  /// Call this after the player has chosen which scoring dice to set aside.
  ///
  /// [selectedDiceIndices] — indices of dice the player chose to set aside.
  /// [permanentScore]      — needed to validate banking.
  /// [isEntered]           — whether player has entered the board.
  ///
  /// Returns updated TurnState with new phase.
  TurnState processSelection({
    required TurnState state,
    required List<int> selectedDiceIndices,
    required int permanentScore,
    required bool isEntered,
  }) {
    assert(
      state.phase == TurnPhase.awaitingSelection,
      'Cannot select in phase: ${state.phase}',
    );

    // Validate: selected dice must all be scoring dice from current roll.
    final lastResult = state.rollHistory.last;
    final validIndices = lastResult.scoringDice.map((d) => d.index).toSet();

    assert(
      selectedDiceIndices.every((i) => validIndices.contains(i)),
      'Player selected a non-scoring die',
    );
    assert(
      selectedDiceIndices.isNotEmpty,
      'Player must select at least one scoring die',
    );

    // Score only the selected dice (player may choose a subset).
    final selectedPoints = _calculateSelectedPoints(
      selectedDiceIndices.toSet(), lastResult,
    );

    // ── Ceiling check ─────────────────────────────────────────────────────────
    final projected = permanentScore + state.temporaryScore + selectedPoints;
    if (projected > 10000) {
      return _resolveBust(state: state, reason: TurnEndReason.ceilingBust);
    }

    final selectedDice = state.currentRoll
        .where((d) => selectedDiceIndices.contains(d.index))
        .toList();

    // ── Win check ─────────────────────────────────────────────────────────────
    if (projected == 10000) {
      state.temporaryScore += selectedPoints;
      state.setAsideDice.addAll(selectedDice);
      _updateTriplesFromSelection(state, selectedDice);
      return _resolveWin(state);
    }

    // ── Add points and update state ───────────────────────────────────────────
    state.temporaryScore += selectedPoints;
    state.setAsideDice.addAll(selectedDice);

    // Update triple tracking for complementary rule.
    _updateTriplesFromSelection(state, selectedDice);

    // Determine next phase based on score and remaining dice.
    state.phase = _determinePhaseAfterSelection(
      state: state,
      permanentScore: permanentScore,
      isEntered: isEntered,
    );

    return state;
  }

  // ---------------------------------------------------------------------------
  // 4. Process banking decision
  // ---------------------------------------------------------------------------

  /// Call this when the player decides to bank their score.
  ///
  /// Returns updated TurnState with endReason = banked.
  /// Throws if banking is not currently allowed.
  TurnState processBank({
    required TurnState state,
    required int permanentScore,
    required bool isEntered,
  }) {
    final blockReason = getBankingBlockReason(
      state: state,
      isEntered: isEntered,
    );

    assert(
      blockReason == BankingBlockReason.none,
      'Banking blocked: $blockReason',
    );

    state.finalBankedScore = state.temporaryScore;
    state.endReason = TurnEndReason.banked;
    state.phase = TurnPhase.turnComplete;
    return state;
  }

  // ---------------------------------------------------------------------------
  // 5. Banking validation
  // ---------------------------------------------------------------------------

  /// Returns the reason banking is blocked, or [BankingBlockReason.none].
  BankingBlockReason getBankingBlockReason({
    required TurnState state,
    required bool isEntered,
  }) {
    // Must be a round number.
    if (!state.isRoundScore) {
      return BankingBlockReason.notRoundNumber;
    }

    // First-time entry: must have at least 400 total.
    // Note: for theft turns, temporaryScore already includes inherited points.
    // Per Constraint #4: entry threshold is checked on TOTAL score.
    if (!isEntered && state.temporaryScore < 400) {
      return BankingBlockReason.belowEntryThreshold;
    }

    return BankingBlockReason.none;
  }

  /// Convenience bool for UI.
  bool canBank({required TurnState state, required bool isEntered}) {
    return getBankingBlockReason(state: state, isEntered: isEntered) ==
        BankingBlockReason.none;
  }

  // ---------------------------------------------------------------------------
  // 6. Theft context builder (called by GameManager)
  // ---------------------------------------------------------------------------

  /// Builds a TheftContext from a completed turn that ended with banking
  /// and has leftover dice.
  ///
  /// Returns null if theft is not possible (no leftover dice, or turn busted).
  TheftContext? buildTheftContext(TurnState completedTurn) {
    // Only valid if previous player banked successfully.
    if (completedTurn.endReason != TurnEndReason.banked) return null;

    // Must have leftover dice.
    final leftoverCount = 5 - completedTurn.setAsideDice.length;
    if (leftoverCount == 0) return null;

    return TheftContext(
      inheritedScore: completedTurn.finalBankedScore!,
      inheritedTriples: Map.from(completedTurn.setAsideTriples),
      availableDiceCount: leftoverCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private — Hot Dice resolution
  // ---------------------------------------------------------------------------

  TurnState _resolveHotDice({
    required TurnState state,
    required int permanentScore,
  }) {
    // ── H-03 Guard ────────────────────────────────────────────────────────────
    // If the +200 bonus alone would push us to exactly 10,000, we cannot roll
    // again because ANY scoring result would exceed 10,000.
    // Per rules: this is a bust. Return to permanent score, X recorded.
    final scoreAfterBonus = state.temporaryScore + HotDiceResolver.hotDiceBonus;
    final projectedAfterBonus = permanentScore + scoreAfterBonus;

    if (projectedAfterBonus == 10000) {
      // H-03: looks like a win but isn't — any roll would exceed 10,000.
      return _resolveBust(state: state, reason: TurnEndReason.ceilingBust);
    }

    if (projectedAfterBonus > 10000) {
      // The +200 bonus itself causes a ceiling bust.
      return _resolveBust(state: state, reason: TurnEndReason.ceilingBust);
    }

    // ── Normal Hot Dice ───────────────────────────────────────────────────────
    state.hotDiceCount++;
    state.temporaryScore += HotDiceResolver.hotDiceBonus;

    // Reset set-aside dice — player picks up all 5 again.
    state.setAsideDice.clear();
    // setAsideTriples cleared — complementary context does not survive Hot Dice.
    state.setAsideTriples.clear();

    state.phase = TurnPhase.hotDiceForced;
    return state;
  }

  // ---------------------------------------------------------------------------
  // Private — Bust resolution
  // ---------------------------------------------------------------------------

  TurnState _resolveBust({
    required TurnState state,
    required TurnEndReason reason,
  }) {
    // All points accumulated this turn are wiped.
    state.temporaryScore = 0;
    state.finalBankedScore = null;
    state.endReason = reason;
    state.phase = TurnPhase.turnComplete;
    return state;
  }

  // ---------------------------------------------------------------------------
  // Private — Win resolution
  // ---------------------------------------------------------------------------

  TurnState _resolveWin(TurnState state) {
    state.finalBankedScore = state.temporaryScore;
    state.endReason = TurnEndReason.win;
    state.phase = TurnPhase.turnComplete;
    return state;
  }

  // ---------------------------------------------------------------------------
  // Private — Phase determination after selection
  // ---------------------------------------------------------------------------

  TurnPhase _determinePhaseAfterSelection({
    required TurnState state,
    required int permanentScore,
    required bool isEntered,
  }) {
    // If all 5 dice are set aside, Hot Dice will be checked on next roll.
    // We go to waitingToRoll with hotDiceForced pending.
    if (state.setAsideDice.length == 5) {
      // This shouldn't happen here — Hot Dice is triggered in processRoll.
      // If we get here it means the player set aside exactly 5 via selection.
      // Treat as Hot Dice.
      return TurnPhase.hotDiceForced;
    }

    // Can the player bank right now?
    final canBankNow = canBank(state: state, isEntered: isEntered);

    if (canBankNow) {
      // Player has a choice: bank or keep rolling.
      return TurnPhase.bankingDecision;
    }

    // Score is not round (or below entry threshold) — must keep rolling.
    return TurnPhase.forcedContinue;
  }

  // ---------------------------------------------------------------------------
  // Private — Set-aside context updates
  // ---------------------------------------------------------------------------

  /// Points for a subset of scoring dice.
  /// A contribution's points are included only if ALL its dice are selected.
  int _calculateSelectedPoints(Set<int> selectedIndices, ScoringResult lastResult) {
    int points = 0;
    for (final contrib in lastResult.contributions) {
      final contribIndices = contrib.dice.map((d) => d.index).toSet();
      if (contribIndices.every((i) => selectedIndices.contains(i))) {
        points += contrib.points;
      }
    }
    return points;
  }

  void _updateSetAsideContext(TurnState state, ScoringResult result,
      {bool forceSetAside = false}) {
    // Auto-set-aside scoring dice when hot dice fires (normal or theft effective).
    // Triple tracking is only updated when dice are physically set aside here;
    // for manual selections, _updateTriplesFromSelection handles it instead.
    if (result.isHotDice || forceSetAside) {
      state.setAsideDice.addAll(result.scoringDice);
      for (final contrib in result.contributions) {
        if (contrib.pattern == ScoringPattern.threeOfAKindOnes ||
            contrib.pattern == ScoringPattern.threeOfAKindOther) {
          final face = contrib.dice.first.face;
          state.setAsideTriples[face] = (state.setAsideTriples[face] ?? 0) + 1;
        }
      }
    }
  }

  /// Updates triple tracking when player manually selects dice to set aside.
  void _updateTriplesFromSelection(
    TurnState state,
    List<ScoredDie> selectedDice,
  ) {
    // Group selected dice by face.
    final Map<DiceFace, int> counts = {};
    for (final die in selectedDice) {
      counts[die.face] = (counts[die.face] ?? 0) + 1;
    }

    // If player is selecting 3+ of the same face, that's a new triple.
    for (final entry in counts.entries) {
      if (entry.value >= 3) {
        state.setAsideTriples[entry.key] =
            (state.setAsideTriples[entry.key] ?? 0) + 1;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private — Roll builder
  // ---------------------------------------------------------------------------

  /// Builds a list of ScoredDie from raw face values.
  /// Indices start from [offset] to avoid collision with set-aside dice.
  List<ScoredDie> _buildRoll(List<int> faces, int offset) {
    return [
      for (int i = 0; i < faces.length; i++)
        ScoredDie(index: offset + i, face: DiceFace.fromInt(faces[i]))
    ];
  }
}
