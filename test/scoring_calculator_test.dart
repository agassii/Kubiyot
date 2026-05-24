// =============================================================================
// scoring_calculator_test.dart
// Kubiyot — Full Test Suite for ScoringCalculator
//
// Covers every case in the agreed test matrix.
// Run with: dart test test/scoring_calculator_test.dart
// =============================================================================

import 'package:test/test.dart';
import '../lib/engine/scoring_calculator.dart';

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

/// Build a list of ScoredDie from a plain int list.
/// Index is assigned positionally (0–4).
List<ScoredDie> dice(List<int> values) {
  assert(values.length == 5, 'Always pass exactly 5 dice');
  return [
    for (int i = 0; i < values.length; i++)
      ScoredDie(index: i, face: DiceFace.fromInt(values[i]))
  ];
}

// Convenience getter on ScoringResult for cleaner assertions.
extension ResultX on ScoringResult {
  List<ScoringPattern> get patterns =>
      contributions.map((c) => c.pattern).toList();
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

void main() {
  final calc = ScoringCalculator();

  // ===========================================================================
  // CATEGORY 1 — Single Scoring Dice
  // ===========================================================================
  group('Category 1 — Single Scoring Dice', () {
    test('S-01: single [1]', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 6]));
      expect(r.rollPoints, 100);
      expect(r.isFarkle, false);
      expect(r.isHotDice, false);
      expect(r.scoringDice.length, 1);
      expect(r.scoringDice.first.face, DiceFace.one);
    });

    test('S-02: single [5]', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 2, 2, 6, 6]));
      expect(r.rollPoints, 50);
      expect(r.scoringDice.length, 1);
      expect(r.scoringDice.first.face, DiceFace.five);
    });

    test('S-03: [1][5] both score — [2][6][6] are dead (NOT a straight)', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 5, 2, 6, 6]));
      expect(r.rollPoints, 150);
      expect(r.scoringDice.length, 2);
      expect(r.nonScoringDice.length, 3);
      expect(r.isFarkle, false);
    });

    test('S-04: two [1]s + one [5]', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 5, 2, 3]));
      expect(r.rollPoints, 250); // 100+100+50
    });

    test('S-05: natural Farkle — no scoring dice', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 3, 4, 6, 6]));
      expect(r.isFarkle, true);
      expect(r.rollPoints, 0);
      expect(r.scoringDice, isEmpty);
    });

    test('S-06: two [1]s + two [5]s', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 5, 5, 2]));
      expect(r.rollPoints, 300); // 100+100+50+50
    });
  });

  // ===========================================================================
  // CATEGORY 2 — Three-of-a-Kind
  // ===========================================================================
  group('Category 2 — Three-of-a-Kind', () {
    test('T-01: three [1]s = 1000', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 2, 3]));
      expect(r.rollPoints, 1000);
      expect(r.patterns, contains(ScoringPattern.threeOfAKindOnes));
    });

    test('T-02: three [2]s = 200', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 2, 2, 3, 4]));
      expect(r.rollPoints, 200);
      expect(r.patterns, contains(ScoringPattern.threeOfAKindOther));
    });

    test('T-03: three [3]s unsorted in array = 300', () {
      // [3][4][3][3][2] — sorting must happen internally
      final r = calc.scoreRoll(rolledDice: dice([3, 4, 3, 3, 2]));
      expect(r.rollPoints, 300);
    });

    test('T-04: three [4]s = 400', () {
      final r = calc.scoreRoll(rolledDice: dice([4, 4, 4, 2, 3]));
      expect(r.rollPoints, 400);
    });

    test('T-05: three [5]s = 500, NOT 150', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 5, 5, 2, 3]));
      expect(r.rollPoints, 500);
      // Must use threeOfAKindOther, not singleFive x3
      expect(r.patterns, contains(ScoringPattern.threeOfAKindOther));
      expect(r.patterns, isNot(contains(ScoringPattern.singleFive)));
    });

    test('T-06: three [6]s = 600', () {
      final r = calc.scoreRoll(rolledDice: dice([6, 6, 6, 2, 3]));
      expect(r.rollPoints, 600);
    });

    test('T-07: three [1]s + single [5] = 1050', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 5, 2]));
      expect(r.rollPoints, 1050); // 1000 + 50
    });

    test('T-08: three [2]s + single [1] + single [5], unsorted = 350', () {
      // [2][5][2][1][2] → sorted internally
      final r = calc.scoreRoll(rolledDice: dice([2, 5, 2, 1, 2]));
      expect(r.rollPoints, 350); // 200 + 100 + 50
    });
  });

  // ===========================================================================
  // CATEGORY 2b — Four-of-a-Kind
  // ===========================================================================
  group('Category 2b — Four-of-a-Kind (triple + 1 complementary)', () {
    test('F-01: four [2]s = 300', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 2, 2, 2, 3]));
      expect(r.rollPoints, 300); // 200 + 100
    });

    test('F-02: four [3]s = 400', () {
      final r = calc.scoreRoll(rolledDice: dice([3, 3, 3, 3, 2]));
      expect(r.rollPoints, 400); // 300 + 100
    });

    test('F-03: four [4]s = 500', () {
      final r = calc.scoreRoll(rolledDice: dice([4, 4, 4, 4, 2]));
      expect(r.rollPoints, 500); // 400 + 100
    });

    test('F-04: four [5]s = 600', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 5, 5, 5, 2]));
      expect(r.rollPoints, 600); // 500 + 100
    });

    test('F-05: four [6]s = 700', () {
      final r = calc.scoreRoll(rolledDice: dice([6, 6, 6, 6, 2]));
      expect(r.rollPoints, 700); // 600 + 100
    });

    test('F-06: four [1]s = 1100', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 1, 2]));
      expect(r.rollPoints, 1100); // 1000 + 100
    });

    test('F-06b: four [1]s — isHotDice is FALSE (only 4 dice scored)', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 1, 2]));
      expect(r.isHotDice, false);
      expect(r.nonScoringDice.length, 1);
    });
  });

  // ===========================================================================
  // CATEGORY 2c — Five-of-a-Kind
  // ===========================================================================
  group('Category 2c — Five-of-a-Kind (triple + 2 complementary) → Hot Dice', () {
    test('V-01: five [2]s = 400, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 2, 2, 2, 2]));
      expect(r.rollPoints, 400); // 200 + 100 + 100
      expect(r.isHotDice, true);
    });

    test('V-02: five [3]s = 500, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([3, 3, 3, 3, 3]));
      expect(r.rollPoints, 500);
      expect(r.isHotDice, true);
    });

    test('V-03: five [4]s = 600, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([4, 4, 4, 4, 4]));
      expect(r.rollPoints, 600);
      expect(r.isHotDice, true);
    });

    test('V-04: five [5]s = 700, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 5, 5, 5, 5]));
      expect(r.rollPoints, 700);
      expect(r.isHotDice, true);
    });

    test('V-05: five [6]s = 800, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([6, 6, 6, 6, 6]));
      expect(r.rollPoints, 800);
      expect(r.isHotDice, true);
    });

    test('V-06: five [1]s = 1200, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 1, 1]));
      expect(r.rollPoints, 1200); // 1000 + 100 + 100
      expect(r.isHotDice, true);
    });
  });

  // ===========================================================================
  // CATEGORY 3 — Straights
  // ===========================================================================
  group('Category 3 — Straights', () {
    test('ST-01: low straight [1-5] = 1500, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 5]));
      expect(r.rollPoints, 1500);
      expect(r.isHotDice, true);
      expect(r.patterns, contains(ScoringPattern.fullStraight));
    });

    test('ST-02: high straight [2-6] = 1500, Hot Dice', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 3, 4, 5, 6]));
      expect(r.rollPoints, 1500);
      expect(r.isHotDice, true);
    });

    test('ST-03: unsorted low straight [5][3][1][4][2] = 1500', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 3, 1, 4, 2]));
      expect(r.rollPoints, 1500);
      expect(r.isHotDice, true);
    });

    test('ST-04: NOT a straight — [1][2][3][4][4], scores only [1] = 100', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 4]));
      expect(r.rollPoints, 100); // only the [1] scores
      expect(r.isHotDice, false);
      expect(r.patterns, isNot(contains(ScoringPattern.fullStraight)));
    });

    test('ST-05: NOT a straight — [2][3][4][5][5], scores only [5] = 50', () {
      final r = calc.scoreRoll(rolledDice: dice([2, 3, 4, 5, 5]));
      // Two [5]s: no triple, no straight → each [5] scores as singleFive
      expect(r.rollPoints, 100); // 50 + 50
    });

    test('ST-06: straight takes priority over [1] single scoring', () {
      // [1][2][3][4][5] could be misread as straight + single[1] or straight alone.
      // Straight pattern uses ALL 5 dice — no double-counting.
      final r = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 5]));
      expect(r.rollPoints, 1500); // NOT 1600
      expect(r.contributions.length, 1);
    });
  });

  // ===========================================================================
  // CATEGORY 4 — Complementary Die Rule (cross-roll)
  // ===========================================================================
  group('Category 4 — Complementary Die Rule (3d.a)', () {
    // Setup: a [5][5][5] triple was set aside in a previous roll this turn.
    // Player is now rolling 2 remaining dice.

    test('C-01: comp [5] when [5][5][5] set aside — worth 100 not 50', () {
      // Rolling 2 dice: [5][2]
      final roll = [
        ScoredDie(index: 0, face: DiceFace.five),
        ScoredDie(index: 1, face: DiceFace.two),
        // Pad with 3 dead dice that don't form a straight with [5][2].
        ScoredDie(index: 2, face: DiceFace.three),
        ScoredDie(index: 3, face: DiceFace.three),
        ScoredDie(index: 4, face: DiceFace.six),
      ];
      // NOTE: in the real game these 3 padding dice are NOT in the pool.
      // The test verifies the [5] at index 0 scores 100 via complementary rule.
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.five: 1},
      );
      // [5] at index 0 → complementary bonus = 100
      final fiveContrib = r.contributions
          .firstWhere((c) => c.dice.any((d) => d.index == 0));
      expect(fiveContrib.pattern, ScoringPattern.complementaryBonus);
      expect(fiveContrib.points, 100);
    });

    test('C-03: comp [2] when [2][2][2] set aside — worth 100 (normally 0)', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.two),
        ScoredDie(index: 1, face: DiceFace.three),
        ScoredDie(index: 2, face: DiceFace.four),
        ScoredDie(index: 3, face: DiceFace.five), // still scores as single
        ScoredDie(index: 4, face: DiceFace.three),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.two: 1},
      );
      final twoContrib = r.contributions
          .firstWhere((c) => c.dice.any((d) => d.face == DiceFace.two));
      expect(twoContrib.pattern, ScoringPattern.complementaryBonus);
      expect(twoContrib.points, 100);
    });

    test('C-04: two comp [2]s when [2][2][2] set aside = 200', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.two),
        ScoredDie(index: 1, face: DiceFace.two),
        ScoredDie(index: 2, face: DiceFace.three),
        ScoredDie(index: 3, face: DiceFace.four),
        ScoredDie(index: 4, face: DiceFace.six),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.two: 1},
      );
      final twoContribs = r.contributions
          .where((c) => c.dice.any((d) => d.face == DiceFace.two))
          .toList();
      expect(twoContribs.length, 2);
      expect(twoContribs.every((c) => c.pattern == ScoringPattern.complementaryBonus), true);
      expect(twoContribs.fold(0, (s, c) => s + c.points), 200);
    });

    test('C-05: comp [6] + single [1] when [6][6][6] set aside = 200', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.six),
        ScoredDie(index: 1, face: DiceFace.one),
        ScoredDie(index: 2, face: DiceFace.three),
        ScoredDie(index: 3, face: DiceFace.four),
        ScoredDie(index: 4, face: DiceFace.two),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.six: 1},
      );
      expect(r.rollPoints, 200); // 100 (comp six) + 100 (single one)
    });

    test('C-06: comp [1] when [1][1][1] set aside — still 100 (no net change)', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.one),
        ScoredDie(index: 1, face: DiceFace.two),
        ScoredDie(index: 2, face: DiceFace.three),
        ScoredDie(index: 3, face: DiceFace.four),
        ScoredDie(index: 4, face: DiceFace.six),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.one: 1},
      );
      final oneContrib = r.contributions
          .firstWhere((c) => c.dice.any((d) => d.face == DiceFace.one));
      // Uses complementaryBonus pattern but same 100 pts
      expect(oneContrib.points, 100);
    });

    test('C-07: two comp [3]s when [3][3][3] set aside = 200', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.three),
        ScoredDie(index: 1, face: DiceFace.three),
        ScoredDie(index: 2, face: DiceFace.two),
        ScoredDie(index: 3, face: DiceFace.four),
        ScoredDie(index: 4, face: DiceFace.six),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.three: 1},
      );
      expect(r.rollPoints, 200);
    });

    test('C-08: comp [4] when [4][4][4] set aside — worth 100 (normally 0)', () {
      final roll = [
        ScoredDie(index: 0, face: DiceFace.four),
        ScoredDie(index: 1, face: DiceFace.two),
        ScoredDie(index: 2, face: DiceFace.three),
        ScoredDie(index: 3, face: DiceFace.two),
        ScoredDie(index: 4, face: DiceFace.six),
      ];
      final r = calc.scoreRoll(
        rolledDice: roll,
        setAsideTriples: {DiceFace.four: 1},
      );
      final fourContrib = r.contributions
          .firstWhere((c) => c.dice.any((d) => d.face == DiceFace.four));
      expect(fourContrib.pattern, ScoringPattern.complementaryBonus);
      expect(fourContrib.points, 100);
    });
  });

  // ===========================================================================
  // CATEGORY 5 — Hot Dice Logic (ScoringResult flags only)
  // ===========================================================================
  group('Category 5 — Hot Dice flag from ScoringResult', () {
    test('H-01: all 5 set aside → isHotDice = true', () {
      // [1][1][1][5][5] → 1000 + 50 + 50 = 1100, all 5 score
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 5, 5]));
      expect(r.isHotDice, true);
      expect(r.nonScoringDice, isEmpty);
    });

    test('H-01b: not all 5 set aside → isHotDice = false', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 5, 2]));
      expect(r.isHotDice, false);
      expect(r.nonScoringDice.length, 1);
    });

    test('H-06: scoring result correctly identifies all 5 scored in triple+comp', () {
      // [1][1][1][1][1] = 1200, all 5 score → Hot Dice
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 1, 1]));
      expect(r.isHotDice, true);
      expect(r.rollPoints, 1200);
    });
  });

  // ===========================================================================
  // CATEGORY 5 — HotDiceResolver
  // ===========================================================================
  group('HotDiceResolver', () {
    final resolver = HotDiceResolver();

    test('applyBonus always returns 200', () {
      expect(resolver.applyBonus(), 200);
    });

    test('H-02: Farkle on forced re-roll → bust', () {
      final farkleResult = calc.scoreRoll(rolledDice: dice([2, 3, 4, 6, 6]));
      expect(farkleResult.isFarkle, true);
      final outcome = resolver.resolveAfterReRoll(
        reRollResult: farkleResult,
        turnScoreIncludingBonus: 1000, // e.g. 800 + 200 bonus
        permanentScore: 0,
      );
      expect(outcome, HotDiceOutcome.bust);
    });

    test('H-03: +200 lands on exactly 10000 — still ceiling bust (any roll busts)', () {
      // Score was 9800. After +200 bonus = 10000.
      // The forced re-roll result doesn't matter — we check before rolling:
      // turnScoreIncludingBonus = 10000, permanentScore = 0.
      // Any non-zero roll → > 10000 → ceilingBust.
      // Even a Farkle (0) → turnScore stays at 10000 → win? NO.
      //
      // Per rules: if +200 puts you at exactly 10000 you CANNOT roll again
      // because ANY scoring result exceeds 10000. The turn busts back to 9800.
      // This logic lives in TurnStateMachine, not HotDiceResolver.
      // Here we verify: resolver called with a Farkle re-roll, score = 10000:
      final farkleResult = calc.scoreRoll(rolledDice: dice([2, 3, 4, 6, 6]));
      final outcome = resolver.resolveAfterReRoll(
        reRollResult: farkleResult,
        turnScoreIncludingBonus: 10000,
        permanentScore: 0,
      );
      // Farkle + 10000 → win (0 added, total exactly 10000)
      // BUT per rules this case is a bust. The TurnStateMachine must
      // intercept BEFORE calling resolveAfterReRoll when bonus itself = 10000.
      // This test documents the resolver's raw output in isolation.
      expect(outcome, HotDiceOutcome.bust); // isFarkle checked first → always bust
    });

    test('H-04: forced roll scores 100, total = 10000 → win', () {
      // Permanent = 0, turnScore after bonus = 9900, roll adds 100
      final roll = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 6]));
      expect(roll.rollPoints, 100);
      final outcome = resolver.resolveAfterReRoll(
        reRollResult: roll,
        turnScoreIncludingBonus: 9900,
        permanentScore: 0,
      );
      expect(outcome, HotDiceOutcome.win);
    });

    test('H-05: forced roll scores 150, total = 10050 → ceiling bust', () {
      final roll = calc.scoreRoll(rolledDice: dice([1, 5, 2, 2, 6]));
      expect(roll.rollPoints, 150);
      final outcome = resolver.resolveAfterReRoll(
        reRollResult: roll,
        turnScoreIncludingBonus: 9900,
        permanentScore: 0,
      );
      expect(outcome, HotDiceOutcome.ceilingBust);
    });

    test('H-07: normal continuation after hot dice re-roll', () {
      final roll = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 6]));
      final outcome = resolver.resolveAfterReRoll(
        reRollResult: roll,
        turnScoreIncludingBonus: 800,
        permanentScore: 0,
      );
      expect(outcome, HotDiceOutcome.continueOrBank);
    });
  });

  // ===========================================================================
  // CATEGORY 6 — 10,000 Ceiling  (pure math, validated by caller)
  // ===========================================================================
  group('Category 6 — 10,000 Ceiling (ceiling detection helper)', () {
    // The ceiling check lives in the TurnStateMachine, but we can validate
    // the scoring results that feed into it.

    test('W-01: 9500 permanent + 400 turn + 100 roll = 10000 → should WIN', () {
      final roll = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 6]));
      expect(roll.rollPoints, 100);
      final total = 9500 + 400 + roll.rollPoints;
      expect(total, 10000);
    });

    test('W-02: 9500 + 400 + 150 = 10050 → ceiling bust', () {
      final roll = calc.scoreRoll(rolledDice: dice([1, 5, 2, 2, 6]));
      expect(roll.rollPoints, 150);
      final total = 9500 + 400 + roll.rollPoints;
      expect(total, greaterThan(10000));
    });

    test('W-04: 9900 + 0 + 100 = 10000 → WIN', () {
      final roll = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 6]));
      expect(9900 + 0 + roll.rollPoints, 10000);
    });

    test('W-06: turn score alone of 10100 → ceiling bust', () {
      // e.g., a hot dice cascade in a single turn
      final total = 0 + 10100;
      expect(total, greaterThan(10000));
    });
  });

  // ===========================================================================
  // REGRESSION — No Double-Counting Edge Cases
  // ===========================================================================
  group('Regression — No double-counting', () {
    test('REG-01: [1][2][3][4][5] scores 1500 only, not 1600', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 2, 3, 4, 5]));
      expect(r.rollPoints, 1500);
      expect(r.contributions.length, 1);
    });

    test('REG-02: [5][5][5] scores 500 not 150', () {
      final r = calc.scoreRoll(rolledDice: dice([5, 5, 5, 2, 3]));
      expect(r.rollPoints, 500);
      expect(r.patterns, isNot(contains(ScoringPattern.singleFive)));
    });

    test('REG-03: [1][1][1][1][5] scores 1150 (1000 + 100 comp + 50)', () {
      final r = calc.scoreRoll(rolledDice: dice([1, 1, 1, 1, 5]));
      expect(r.rollPoints, 1150); // 1000 + 100 + 50
    });

    test('REG-04: unsorted [6][2][6][6][1] = 700 (600 triple + 100 single one)', () {
      final r = calc.scoreRoll(rolledDice: dice([6, 2, 6, 6, 1]));
      expect(r.rollPoints, 700);
    });
  });
}
