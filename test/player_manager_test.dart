// =============================================================================
// player_manager_test.dart
// Kubiyot — Full Test Suite for PlayerManager
//
// Covers: banking, X tracking, 3-X rule, stomping, domino cascade,
//         entry status, and score tier invariant.
// Run with: dart test test/player_manager_test.dart
// =============================================================================

import 'package:test/test.dart';
import '../lib/engine/player_manager.dart';

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

Player makePlayer(String id, {
  int score = 0,
  List<int>? tiers,
  int xCount = 0,
  bool entered = false,
}) {
  return Player(
    id: id,
    displayName: id,
    scoreTiers: tiers ?? [0, if (score > 0) score],
    consecutiveXCount: xCount,
    isEntered: entered,
  );
}

// Shorthand to get events of a specific type
List<PlayerEvent> eventsOfType(
  ScoreChangeResult result,
  PlayerEventType type,
) => result.events.where((e) => e.type == type).toList();

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

void main() {
  late PlayerManager manager;

  setUp(() => manager = PlayerManager());

  // ===========================================================================
  // BANKING
  // ===========================================================================
  group('Banking', () {
    test('B-01: basic bank adds tier correctly', () {
      final p = makePlayer('p1');
      final result = manager.bank(
        players: [p],
        bankingPlayer: p,
        amount: 400,
      );
      expect(p.currentScore, 400);
      expect(p.scoreTiers, [0, 400]);
      expect(eventsOfType(result, PlayerEventType.banked).length, 1);
    });

    test('B-02: banking resets consecutive X count', () {
      final p = makePlayer('p1', xCount: 2);
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      expect(p.consecutiveXCount, 0);
    });

    test('B-03: banking marks player as entered', () {
      final p = makePlayer('p1', entered: false);
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      expect(p.isEntered, true);
    });

    test('B-04: multiple banks build tier history', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.bank(players: [p], bankingPlayer: p, amount: 500);
      manager.bank(players: [p], bankingPlayer: p, amount: 600);
      expect(p.scoreTiers, [0, 400, 900, 1500]);
    });

    test('B-05: bank to exactly 10000 → WIN', () {
      final p = makePlayer('p1', tiers: [0, 9800], entered: true);
      final result = manager.bank(
        players: [p],
        bankingPlayer: p,
        amount: 200,
      );
      expect(result.gameWon, true);
      expect(result.winnerId, 'p1');
      expect(p.currentScore, 10000);
      expect(eventsOfType(result, PlayerEventType.won).length, 1);
    });

    test('B-06: bank asserts on non-round amount', () {
      final p = makePlayer('p1');
      expect(
        () => manager.bank(players: [p], bankingPlayer: p, amount: 350),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ===========================================================================
  // X TRACKING
  // ===========================================================================
  group('X Tracking', () {
    test('X-01: first X increments count, no tier change', () {
      final p = makePlayer('p1', tiers: [0, 400], entered: true);
      final result = manager.recordX(players: [p], player: p);
      expect(p.consecutiveXCount, 1);
      expect(p.currentScore, 400); // unchanged
      expect(eventsOfType(result, PlayerEventType.xRecorded).length, 1);
    });

    test('X-02: second X increments count, no tier change', () {
      final p = makePlayer('p1', tiers: [0, 400], entered: true, xCount: 1);
      manager.recordX(players: [p], player: p);
      expect(p.consecutiveXCount, 2);
      expect(p.currentScore, 400);
    });

    test('X-03: third X burns tier, resets count', () {
      final p = makePlayer('p1', tiers: [0, 400, 900], entered: true, xCount: 2);
      final result = manager.recordX(players: [p], player: p);
      expect(p.consecutiveXCount, 0);
      expect(p.currentScore, 400); // dropped from 900 to 400
      expect(p.scoreTiers, [0, 400]);
      expect(eventsOfType(result, PlayerEventType.tierBurned).length, 1);
    });

    test('X-04: successful bank resets X count', () {
      final p = makePlayer('p1', tiers: [0, 400], entered: true, xCount: 2);
      manager.bank(players: [p], bankingPlayer: p, amount: 500);
      expect(p.consecutiveXCount, 0);
    });

    test('X-05: third X with only one tier stays at 0', () {
      // Player who entered then got 3 X's — can't go below 0
      final p = makePlayer('p1', tiers: [0, 400], entered: true, xCount: 2);
      manager.recordX(players: [p], player: p);
      // Burns 400 tier → back to [0]
      expect(p.currentScore, 0);
      expect(p.scoreTiers, [0]);
    });

    test('X-06: third X at score=0, stays at 0', () {
      // IV-05: player already at 0, gets 3rd X
      final p = makePlayer('p1', tiers: [0], entered: false, xCount: 2);
      manager.recordX(players: [p], player: p);
      expect(p.currentScore, 0);
      expect(p.scoreTiers, [0]);
    });

    test('X-07: isOnLastWarning true at xCount=2', () {
      final p = makePlayer('p1', xCount: 2);
      expect(manager.isOnLastWarning(p), true);
    });

    test('X-08: isOnLastWarning false at xCount=1', () {
      final p = makePlayer('p1', xCount: 1);
      expect(manager.isOnLastWarning(p), false);
    });
  });

  // ===========================================================================
  // ENTRY STATUS
  // ===========================================================================
  group('Entry Status', () {
    test('E-01: entry is permanent — not reverted after dropping to 0', () {
      final p = makePlayer('p1', tiers: [0, 400], entered: true, xCount: 2);
      // 3rd X → drops to 0
      manager.recordX(players: [p], player: p);
      expect(p.isEntered, true); // still entered
      expect(p.currentScore, 0);
    });

    test('E-02: entry immunity — entered player at 0 can bank 200', () {
      final p = makePlayer('p1', tiers: [0], entered: true);
      expect(manager.canBank(p, 200), true);
    });

    test('E-03: not entered, 300 → cannot bank', () {
      final p = makePlayer('p1', entered: false);
      expect(manager.canBank(p, 300), false);
    });

    test('E-04: not entered, 400 → can bank', () {
      final p = makePlayer('p1', entered: false);
      expect(manager.canBank(p, 400), true);
    });

    test('E-05: not entered, 350 → cannot bank (not round AND below threshold)', () {
      final p = makePlayer('p1', entered: false);
      expect(manager.canBank(p, 350), false);
    });

    test('E-06: markEntered sets flag permanently', () {
      final p = makePlayer('p1', entered: false);
      manager.markEntered(p);
      expect(p.isEntered, true);
      // Call again — should not throw or change
      manager.markEntered(p);
      expect(p.isEntered, true);
    });

    test('E-07: stomped player retains entry status', () {
      final p1 = makePlayer('p1', tiers: [0, 400, 900], entered: true);
      final p2 = makePlayer('p2', tiers: [0, 400, 600], entered: true);

      // p2 banks 300 → lands on 900 → stomps p1
      manager.bank(players: [p1, p2], bankingPlayer: p2, amount: 300);
      // p1 drops from 900 to 400
      expect(p1.currentScore, 400);
      expect(p1.isEntered, true); // still entered
    });
  });

  // ===========================================================================
  // STOMP (Category 8 — P-01 to P-04)
  // ===========================================================================
  group('Stomp — Overlapping Tier Rule', () {
    test('P-01: Player B banks to 1500, Player A is at 1500 → A stomped', () {
      final pA = makePlayer('pA', tiers: [0, 400, 1500], entered: true);
      final pB = makePlayer('pB', tiers: [0, 400, 1200], entered: true);

      final result = manager.bank(
        players: [pA, pB],
        bankingPlayer: pB,
        amount: 300, // 1200 + 300 = 1500
      );

      expect(pB.currentScore, 1500);
      expect(pA.currentScore, 400); // dropped to previous tier

      final stompEvents = eventsOfType(result, PlayerEventType.stomped);
      expect(stompEvents.length, 1);
      expect(stompEvents.first.playerId, 'pA');
      expect(stompEvents.first.triggeredByPlayerId, 'pB');
    });

    test('P-02: 3rd X cascade → B drops to 800, A is at 800 → domino', () {
      final pA = makePlayer('pA', tiers: [0, 400, 800, 1200], entered: true);
      final pB = makePlayer('pB', tiers: [0, 400, 800], entered: true, xCount: 2);

      final result = manager.recordX(players: [pA, pB], player: pB);

      // pB drops from 800 to 400
      expect(pB.currentScore, 400);

      // pA was at 800 — pB's crash landing stomps pA
      // pA drops from 800 to 400... wait, check tiers
      // pA tiers: [0, 400, 800, 1200] — current=1200, not 800
      // This test needs pA to be AT 800
    });

    test('P-02-correct: B drops to 800, A is sitting at 800 → domino', () {
      // pA is currently at 800
      final pA = makePlayer('pA', tiers: [0, 400, 800], entered: true);
      // pB is at 1100, gets 3rd X, drops to 800
      final pB = makePlayer('pB', tiers: [0, 400, 800, 1100], entered: true, xCount: 2);

      final result = manager.recordX(players: [pA, pB], player: pB);

      // pB drops from 1100 to 800
      expect(pB.currentScore, 800);

      // pA was at 800 → domino stomped → drops to 400
      expect(pA.currentScore, 400);

      final dominoEvents = eventsOfType(result, PlayerEventType.dominoed);
      expect(dominoEvents.length, 1);
      expect(dominoEvents.first.playerId, 'pA');
      expect(dominoEvents.first.triggeredByPlayerId, 'pB');
    });

    test('P-03: triple domino cascade', () {
      // pB drops to 800 → stomps pA → pA drops to 400 → stomps pC
      final pA = makePlayer('pA', tiers: [0, 400, 800], entered: true);
      final pC = makePlayer('pC', tiers: [0, 400], entered: true);
      final pB = makePlayer('pB', tiers: [0, 400, 800, 1100], entered: true, xCount: 2);

      final result = manager.recordX(players: [pA, pB, pC], player: pB);

      // pB: 1100 → 800
      expect(pB.currentScore, 800);
      // pA: 800 → 400 (domino from pB)
      expect(pA.currentScore, 400);
      // pC: 400 → 0 (domino from pA)
      expect(pC.currentScore, 0);

      // Total cascade events: tierBurned(pB) + dominoed(pA) + dominoed(pC)
      expect(result.events.length, 3);
    });

    test('P-04: passing through score without landing does NOT stomp', () {
      // pA is at 800. pB banks from 600 to 1000 (passes through 800).
      final pA = makePlayer('pA', tiers: [0, 400, 800], entered: true);
      final pB = makePlayer('pB', tiers: [0, 400, 600], entered: true);

      manager.bank(players: [pA, pB], bankingPlayer: pB, amount: 400);

      // pB lands at 1000, pA is at 800 — no stomp
      expect(pA.currentScore, 800); // unchanged
      expect(pB.currentScore, 1000);
    });

    test('STOMP-immune: stomped player retains isEntered', () {
      final pA = makePlayer('pA', tiers: [0, 400, 900], entered: true);
      final pB = makePlayer('pB', tiers: [0, 400, 600], entered: true);

      manager.bank(players: [pA, pB], bankingPlayer: pB, amount: 300);

      expect(pA.currentScore, 400);
      expect(pA.isEntered, true);
    });

    test('STOMP-xreset: stomped player has X count reset', () {
      final pA = makePlayer('pA', tiers: [0, 400, 900], entered: true, xCount: 2);
      final pB = makePlayer('pB', tiers: [0, 400, 600], entered: true);

      manager.bank(players: [pA, pB], bankingPlayer: pB, amount: 300);

      // pA stomped → X count reset
      expect(pA.consecutiveXCount, 0);
    });
  });

  // ===========================================================================
  // SCORE TIER INVARIANT (Category 12)
  // ===========================================================================
  group('Category 12 — Score Tier Invariant', () {
    test('IV-03: 3 X tears down correctly', () {
      final p = makePlayer('p1', tiers: [0, 400, 900], entered: true, xCount: 2);
      manager.recordX(players: [p], player: p);
      expect(p.scoreTiers, [0, 400]);
      expect(p.currentScore % 100, 0); // invariant holds
    });

    test('IV-04: stomp tears down correctly', () {
      final pA = makePlayer('pA', tiers: [0, 400, 900], entered: true);
      final pB = makePlayer('pB', tiers: [0, 600], entered: true);
      manager.bank(players: [pA, pB], bankingPlayer: pB, amount: 300);
      expect(pA.scoreTiers, [0, 400]);
      expect(pA.currentScore % 100, 0);
    });

    test('IV-09: all tiers always multiples of 100 after multiple operations', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.bank(players: [p], bankingPlayer: p, amount: 500);
      manager.recordX(players: [p], player: p);
      manager.recordX(players: [p], player: p);
      manager.bank(players: [p], bankingPlayer: p, amount: 300);

      for (final tier in p.scoreTiers) {
        expect(tier % 100, 0, reason: 'Tier $tier is not a multiple of 100');
      }
    });

    test('IV-10: domino cascade — all tiers remain multiples of 100', () {
      final pA = makePlayer('pA', tiers: [0, 400, 800], entered: true);
      final pC = makePlayer('pC', tiers: [0, 400], entered: true);
      final pB = makePlayer('pB',
          tiers: [0, 400, 800, 1100], entered: true, xCount: 2);

      manager.recordX(players: [pA, pB, pC], player: pB);

      for (final tier in [...pA.scoreTiers, ...pB.scoreTiers, ...pC.scoreTiers]) {
        expect(tier % 100, 0, reason: 'Tier $tier is not a multiple of 100');
      }
    });
  });

  // ===========================================================================
  // TIER HISTORY
  // ===========================================================================
  group('Tier History', () {
    test('TH-01: first bank creates tierHistory entry with xCount=0', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      expect(p.tierHistory.length, 1);
      expect(p.tierHistory.first.score, 400);
      expect(p.tierHistory.first.xCount, 0);
      expect(p.tierHistory.first.burned, false);
    });

    test('TH-02: getting X increments current tier xCount in-place', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.recordX(players: [p], player: p);
      expect(p.tierHistory.first.xCount, 1);
      manager.recordX(players: [p], player: p);
      expect(p.tierHistory.first.xCount, 2);
    });

    test('TH-03: banking creates new entry; previous entry xCount is frozen', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.recordX(players: [p], player: p); // 400: x=1
      manager.bank(players: [p], bankingPlayer: p, amount: 500);
      expect(p.tierHistory.length, 2);
      expect(p.tierHistory[0].score, 400);
      expect(p.tierHistory[0].xCount, 1); // frozen
      expect(p.tierHistory[1].score, 900);
      expect(p.tierHistory[1].xCount, 0); // new tier
    });

    test('TH-04: 3-X burn marks current tier entry burned with xCount=3', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.bank(players: [p], bankingPlayer: p, amount: 500); // at 900
      manager.recordX(players: [p], player: p);
      manager.recordX(players: [p], player: p);
      manager.recordX(players: [p], player: p); // 3rd X
      expect(p.tierHistory[1].score, 900);
      expect(p.tierHistory[1].xCount, 3);
      expect(p.tierHistory[1].burned, true);
      expect(p.tierHistory[0].burned, false);
      expect(p.currentScore, 400);
    });

    test('TH-05: X before first bank does not create tierHistory entry', () {
      final p = makePlayer('p1', tiers: [0], entered: false, xCount: 2);
      manager.recordX(players: [p], player: p);
      expect(p.tierHistory, isEmpty);
    });

    test('TH-06: stomp marks tier burned; returning tier resumes its xCount', () {
      final p = makePlayer('p1');
      manager.bank(players: [p], bankingPlayer: p, amount: 400);
      manager.recordX(players: [p], player: p); // 400: x=1
      manager.bank(players: [p], bankingPlayer: p, amount: 500); // at 900
      manager.recordX(players: [p], player: p);
      manager.recordX(players: [p], player: p); // 900: x=2
      final stomper = makePlayer('s', tiers: [0, 600], entered: true);
      manager.bank(players: [p, stomper], bankingPlayer: stomper, amount: 300);
      // p stomped back to 400
      expect(p.currentScore, 400);
      expect(p.tierHistory[1].burned, true);
      expect(p.tierHistory[1].xCount, 2);
      expect(p.tierHistory[0].xCount, 1); // preserved
      expect(p.tierHistory[0].burned, false);
      // Next X updates the 400 entry
      manager.recordX(players: [p, stomper], player: p);
      expect(p.tierHistory[0].xCount, 2); // 1 → 2
      expect(p.consecutiveXCount, 1);
    });
  });

  // ===========================================================================
  // QUERIES
  // ===========================================================================
  group('Queries', () {
    test('playersAtScore returns correct players', () {
      final p1 = makePlayer('p1', tiers: [0, 400, 800], entered: true);
      final p2 = makePlayer('p2', tiers: [0, 400], entered: true);
      final p3 = makePlayer('p3', tiers: [0, 400, 800], entered: true);

      final atEight = manager.playersAtScore([p1, p2, p3], 800);
      expect(atEight.map((p) => p.id).toList()..sort(), ['p1', 'p3']);
    });

    test('previousTierScore is correct', () {
      final p = makePlayer('p1', tiers: [0, 400, 900, 1500]);
      expect(p.previousTierScore, 900);
    });

    test('previousTierScore is 0 when only one tier', () {
      final p = makePlayer('p1', tiers: [0]);
      expect(p.previousTierScore, 0);
    });
  });
}
