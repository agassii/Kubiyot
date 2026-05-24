// =============================================================================
// scoring_calculator.dart
// Kubiyot Dice Game — Core Scoring Engine
//
// Responsibilities:
//   1. Detect all valid scoring patterns in a single roll
//   2. Apply the Complementary Die Rule (3d.a) using set-aside context
//   3. Detect Hot Dice (all 5 set aside) and apply +200 bonus
//   4. Return a fully auditable ScoringResult
//
// This file is pure Dart — zero Flutter dependencies. Fully unit-testable.
// =============================================================================

// -----------------------------------------------------------------------------
// ENUMS
// -----------------------------------------------------------------------------

enum DiceFace {
  one(1),
  two(2),
  three(3),
  four(4),
  five(5),
  six(6);

  const DiceFace(this.value);
  final int value;

  static DiceFace fromInt(int v) =>
      DiceFace.values.firstWhere((f) => f.value == v);
}

/// Why a turn ended without banking.
enum BustType {
  naturalFarkle, // 0 scoring dice in a roll
  ceilingBust, // permanent + turn score would exceed 10,000
  hotDiceBust, // busted on the mandatory Hot Dice re-roll
}

/// The atomic scoring pattern applied to a group of dice.
enum ScoringPattern {
  singleOne, // 1 die: [1] = 100
  singleFive, // 1 die: [5] = 50
  threeOfAKindOnes, // 3 dice: [1][1][1] = 1000
  threeOfAKindOther, // 3 dice: [x][x][x] = x*100
  complementaryBonus, // 1 die: matches a set-aside triple = 100 flat
  fullStraight, // 5 dice: [1-5] or [2-6] = 1500
}

// -----------------------------------------------------------------------------
// DATA CLASSES
// -----------------------------------------------------------------------------

/// One die as it enters the scoring calculator.
/// [index] is its stable position (0–4) in the dice pool.
class ScoredDie {
  final int index;
  final DiceFace face;

  const ScoredDie({required this.index, required this.face});

  @override
  String toString() => 'Die[$index]:${face.value}';
}

/// A single scoring contribution: which dice, which pattern, how many points.
class ScoringContribution {
  final List<ScoredDie> dice;
  final ScoringPattern pattern;
  final int points;

  const ScoringContribution({
    required this.dice,
    required this.pattern,
    required this.points,
  });

  @override
  String toString() =>
      '$pattern → ${dice.map((d) => d.face.value).toList()} = $points pts';
}

/// Full result of scoring one roll.
class ScoringResult {
  /// All contributions found in this roll.
  final List<ScoringContribution> contributions;

  /// Dice that scored (must be set aside — player cannot leave these).
  final List<ScoredDie> scoringDice;

  /// Dice that did NOT score — player may optionally roll these again.
  final List<ScoredDie> nonScoringDice;

  /// Total points from this roll alone (before adding to turn total).
  final int rollPoints;

  /// True if 0 scoring dice were found → Farkle / bust.
  final bool isFarkle;

  /// True if ALL 5 dice scored → Hot Dice triggered.
  /// Caller is responsible for adding +200 and scheduling mandatory re-roll.
  final bool isHotDice;

  const ScoringResult({
    required this.contributions,
    required this.scoringDice,
    required this.nonScoringDice,
    required this.rollPoints,
    required this.isFarkle,
    required this.isHotDice,
  });

  @override
  String toString() {
    if (isFarkle) return 'FARKLE — 0 points';
    final lines = contributions.map((c) => '  $c').join('\n');
    return 'Roll Score: $rollPoints pts${isHotDice ? ' 🔥 HOT DICE' : ''}\n$lines';
  }
}

// -----------------------------------------------------------------------------
// SCORING CALCULATOR
// -----------------------------------------------------------------------------

class ScoringCalculator {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Score a single roll.
  ///
  /// [rolledDice]         — the 5 dice just rolled (indices 0–4).
  /// [setAsideTriples]    — map of face → count of COMPLETE triples already
  ///                        set aside THIS turn (for Complementary Die Rule).
  ///                        e.g., {DiceFace.five: 1} means [5][5][5] is set aside.
  ///
  /// Returns a [ScoringResult] with full contribution breakdown.
  ScoringResult scoreRoll({
    required List<ScoredDie> rolledDice,
    Map<DiceFace, int> setAsideTriples = const {},
  }) {
    assert(rolledDice.length >= 1 && rolledDice.length <= 5, 'Must roll 1–5 dice');

    // 1. Check for a full straight FIRST (highest priority pattern).
    //    A straight uses all 5 dice — if detected, no other patterns apply.
    final straightResult = _checkFullStraight(rolledDice);
    if (straightResult != null) return straightResult;

    // 2. Score the remaining dice with standard + complementary rules.
    return _scoreStandard(rolledDice, setAsideTriples);
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Full Straight Detection
  // ---------------------------------------------------------------------------

  /// Returns a ScoringResult if all 5 dice form [1-5] or [2-6].
  /// Returns null otherwise.
  ScoringResult? _checkFullStraight(List<ScoredDie> dice) {
    // Sort by face value for comparison — order in the array doesn't matter.
    final sorted = [...dice]..sort((a, b) => a.face.value.compareTo(b.face.value));
    final values = sorted.map((d) => d.face.value).toList();

    final isLowStraight  = _listEquals(values, [1, 2, 3, 4, 5]);
    final isHighStraight = _listEquals(values, [2, 3, 4, 5, 6]);

    if (!isLowStraight && !isHighStraight) return null;

    final contribution = ScoringContribution(
      dice: sorted,
      pattern: ScoringPattern.fullStraight,
      points: 1500,
    );

    // All 5 dice scored → Hot Dice is mandatory.
    return ScoringResult(
      contributions: [contribution],
      scoringDice: sorted,
      nonScoringDice: const [],
      rollPoints: 1500,
      isFarkle: false,
      isHotDice: true, // caller adds +200 and schedules re-roll
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Standard Scoring (Three-of-a-kind, Singles, Complementary)
  // ---------------------------------------------------------------------------

  ScoringResult _scoreStandard(
    List<ScoredDie> dice,
    Map<DiceFace, int> setAsideTriples,
  ) {
    // Group dice by face value.
    final Map<DiceFace, List<ScoredDie>> groups = {};
    for (final die in dice) {
      groups.putIfAbsent(die.face, () => []).add(die);
    }

    final contributions = <ScoringContribution>[];
    final scoringDice   = <ScoredDie>[];

    for (final entry in groups.entries) {
      final face  = entry.key;
      final group = entry.value;
      final count = group.length;

      if (count >= 3) {
        // ── Three-of-a-kind (the base triple) ──────────────────────────────
        final tripleContrib = _scoreTriple(face, group.sublist(0, 3));
        contributions.add(tripleContrib);
        scoringDice.addAll(group.sublist(0, 3));

        // ── Extra dice beyond the triple (4th and 5th) ─────────────────────
        // These are Complementary dice by the same rule as cross-roll extras.
        for (int i = 3; i < count; i++) {
          final extraDie = group[i];
          contributions.add(ScoringContribution(
            dice: [extraDie],
            pattern: ScoringPattern.complementaryBonus,
            points: 100,
          ));
          scoringDice.add(extraDie);
        }
      } else {
        // ── Fewer than 3: check singles and complementary rule ──────────────
        for (final die in group) {
          // Does a set-aside triple of this face exist from a prior roll?
          final hasSetAsideTriple = (setAsideTriples[face] ?? 0) > 0;

          if (hasSetAsideTriple) {
            // Complementary Die Rule (3d.a): worth 100 flat regardless of face.
            contributions.add(ScoringContribution(
              dice: [die],
              pattern: ScoringPattern.complementaryBonus,
              points: 100,
            ));
            scoringDice.add(die);
          } else if (face == DiceFace.one) {
            contributions.add(ScoringContribution(
              dice: [die],
              pattern: ScoringPattern.singleOne,
              points: 100,
            ));
            scoringDice.add(die);
          } else if (face == DiceFace.five) {
            contributions.add(ScoringContribution(
              dice: [die],
              pattern: ScoringPattern.singleFive,
              points: 50,
            ));
            scoringDice.add(die);
          }
          // All other faces with count < 3 and no set-aside triple: no score.
        }
      }
    }

    final rollPoints = contributions.fold(0, (sum, c) => sum + c.points);
    final isFarkle   = scoringDice.isEmpty;
    final isHotDice  = scoringDice.length == 5 && !isFarkle;

    final nonScoringDice = dice
        .where((d) => !scoringDice.any((s) => s.index == d.index))
        .toList();

    return ScoringResult(
      contributions: contributions,
      scoringDice: scoringDice,
      nonScoringDice: nonScoringDice,
      rollPoints: rollPoints,
      isFarkle: isFarkle,
      isHotDice: isHotDice,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Score a single triple group (3 dice of the same face).
  ScoringContribution _scoreTriple(DiceFace face, List<ScoredDie> three) {
    assert(three.length == 3);
    final points = face == DiceFace.one ? 1000 : face.value * 100;
    final pattern = face == DiceFace.one
        ? ScoringPattern.threeOfAKindOnes
        : ScoringPattern.threeOfAKindOther;

    return ScoringContribution(dice: three, pattern: pattern, points: points);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
// HOT DICE RESOLVER  (thin wrapper — lives here, used by TurnStateMachine)
// -----------------------------------------------------------------------------

class HotDiceResolver {
  static const int hotDiceBonus = 200;

  /// Call this when [ScoringResult.isHotDice] is true.
  /// Returns the bonus points to add to the turn score.
  /// Caller MUST then schedule a mandatory 5-dice re-roll.
  int applyBonus() => hotDiceBonus;

  /// After the mandatory re-roll:
  /// - If the new roll is a Farkle → the ENTIRE turn score (including bonus) is wiped.
  /// - If it scores → continue normally.
  /// - If the new score would exceed 10,000 → Ceiling Bust.
  ///
  /// This method validates the post-hot-dice state.
  HotDiceOutcome resolveAfterReRoll({
    required ScoringResult reRollResult,
    required int turnScoreIncludingBonus, // score AFTER +200 was applied
    required int permanentScore,
  }) {
    if (reRollResult.isFarkle) {
      return HotDiceOutcome.bust;
    }

    final projected = permanentScore + turnScoreIncludingBonus + reRollResult.rollPoints;

    if (projected > 10000) {
      return HotDiceOutcome.ceilingBust;
    }

    if (projected == 10000) {
      return HotDiceOutcome.win;
    }

    return HotDiceOutcome.continueOrBank;
  }
}

enum HotDiceOutcome {
  bust,           // Farkle on forced re-roll — all points wiped
  ceilingBust,   // exceeded 10,000 — all points wiped, X recorded
  win,            // exactly 10,000 — game over
  continueOrBank, // normal continuation
}
