// =============================================================================
// player_manager.dart
// Kubiyot Dice Game — Player Manager
//
// Responsibilities:
//   1. Manage score tiers (bank, burn, drop)
//   2. Track consecutive X marks and apply 3-X penalty
//   3. Handle stomping (Overlapping Tier Rule)
//   4. Resolve Domino cascade (recursive until no collisions)
//   5. Manage entry status (one-way flag, permanent once entered)
//
// Invariant: every value in scoreTiers is always a multiple of 100.
//
// This file is pure Dart — zero Flutter dependencies.
// =============================================================================

// -----------------------------------------------------------------------------
// PLAYER MODEL
// -----------------------------------------------------------------------------

class Player {
  final String id;
  final String displayName;

  // ── Score Tiers ─────────────────────────────────────────────────────────────
  // Index 0 is always 0 (starting score).
  // Last element is current banked score.
  // Example: [0, 400, 900, 1500] → current = 1500, previous = 900
  //
  // Invariant: all values are multiples of 100.
  final List<int> scoreTiers;

  // ── X Tracking ──────────────────────────────────────────────────────────────
  // Only CONSECUTIVE X marks matter.
  // Resets to 0 on any successful bank.
  int consecutiveXCount;

  // ── Entry Status ─────────────────────────────────────────────────────────────
  // One-way flag: once true, never goes back to false.
  // Per Constraint #3: entry immunity is permanent for the whole game.
  bool isEntered;

  Player({
    required this.id,
    required this.displayName,
    List<int>? scoreTiers,
    this.consecutiveXCount = 0,
    this.isEntered = false,
  }) : scoreTiers = scoreTiers ?? [0];

  // ── Computed Properties ──────────────────────────────────────────────────────

  int get currentScore => scoreTiers.last;

  int get previousTierScore =>
      scoreTiers.length > 1 ? scoreTiers[scoreTiers.length - 2] : 0;

  bool get hasOnlyOneTier => scoreTiers.length == 1;

  @override
  String toString() =>
      'Player[$displayName] score=$currentScore tiers=$scoreTiers X=$consecutiveXCount entered=$isEntered';
}

// -----------------------------------------------------------------------------
// RESULT TYPES
// -----------------------------------------------------------------------------

/// What happened to a player after a score-changing event.
enum PlayerEventType {
  banked,       // successfully banked points
  xRecorded,    // got an X (bust)
  tierBurned,   // got 3rd X — dropped to previous tier
  stomped,      // another player landed on exact score
  dominoed,     // stomped as result of domino cascade
  won,          // reached exactly 10,000
}

class PlayerEvent {
  final String playerId;
  final PlayerEventType type;
  final int scoreBefore;
  final int scoreAfter;
  final String? triggeredByPlayerId; // for stomp/domino events

  const PlayerEvent({
    required this.playerId,
    required this.type,
    required this.scoreBefore,
    required this.scoreAfter,
    this.triggeredByPlayerId,
  });

  @override
  String toString() =>
      'PlayerEvent[$type] $playerId: $scoreBefore → $scoreAfter';
}

/// Full result of any score-changing operation.
/// May contain multiple events due to domino cascade.
class ScoreChangeResult {
  final List<PlayerEvent> events;
  final bool gameWon;
  final String? winnerId;

  const ScoreChangeResult({
    required this.events,
    this.gameWon = false,
    this.winnerId,
  });
}

// -----------------------------------------------------------------------------
// PLAYER MANAGER
// -----------------------------------------------------------------------------

class PlayerManager {

  // ---------------------------------------------------------------------------
  // 1. Banking — add points to score tier
  // ---------------------------------------------------------------------------

  /// Called when a player successfully banks their turn score.
  ///
  /// [players]      — all players in the game (for stomp check).
  /// [bankingPlayer] — the player who is banking.
  /// [amount]       — points to bank (must be multiple of 100, > 0).
  ///
  /// Returns a [ScoreChangeResult] with all triggered events.
  ScoreChangeResult bank({
    required List<Player> players,
    required Player bankingPlayer,
    required int amount,
  }) {
    // Invariant check.
    assert(amount % 100 == 0, 'BUG: Non-round bank amount: $amount');
    assert(amount > 0, 'BUG: Cannot bank 0 or negative amount');

    final scoreBefore = bankingPlayer.currentScore;
    final newScore = scoreBefore + amount;

    // Win condition.
    if (newScore == 10000) {
      bankingPlayer.scoreTiers.add(newScore);
      bankingPlayer.consecutiveXCount = 0;
      _markEntered(bankingPlayer);

      return ScoreChangeResult(
        events: [
          PlayerEvent(
            playerId: bankingPlayer.id,
            type: PlayerEventType.won,
            scoreBefore: scoreBefore,
            scoreAfter: newScore,
          ),
        ],
        gameWon: true,
        winnerId: bankingPlayer.id,
      );
    }

    // Normal bank.
    bankingPlayer.scoreTiers.add(newScore);
    bankingPlayer.consecutiveXCount = 0;
    _markEntered(bankingPlayer);

    final events = <PlayerEvent>[
      PlayerEvent(
        playerId: bankingPlayer.id,
        type: PlayerEventType.banked,
        scoreBefore: scoreBefore,
        scoreAfter: newScore,
      ),
    ];

    // Check if this bank stomps another player.
    final stompEvents = _resolveStompCascade(
      players: players,
      triggerPlayerId: bankingPlayer.id,
      landingScore: newScore,
    );
    events.addAll(stompEvents);

    return ScoreChangeResult(events: events);
  }

  // ---------------------------------------------------------------------------
  // 2. Recording an X (bust)
  // ---------------------------------------------------------------------------

  /// Called when a player's turn ends in any kind of bust.
  ///
  /// All bust types count as X (naturalFarkle, ceilingBust, hotDiceBust).
  ///
  /// Returns a [ScoreChangeResult] — may include tierBurned event and
  /// subsequent domino cascade if the tier drop lands on another player.
  ScoreChangeResult recordX({
    required List<Player> players,
    required Player player,
  }) {
    final scoreBefore = player.currentScore;
    player.consecutiveXCount++;

    final events = <PlayerEvent>[];

    // 3-X Rule: third consecutive X burns the current tier.
    if (player.consecutiveXCount >= 3) {
      player.consecutiveXCount = 0;

      // Drop to previous tier.
      final scoreAfter = _burnCurrentTier(player);

      events.add(PlayerEvent(
        playerId: player.id,
        type: PlayerEventType.tierBurned,
        scoreBefore: scoreBefore,
        scoreAfter: scoreAfter,
      ));

      // Domino cascade: did this drop land on another player's score?
      // isDirectStomp=false because the trigger is a tier burn, not a bank.
      final cascadeEvents = _resolveStompCascade(
        players: players,
        triggerPlayerId: player.id,
        landingScore: scoreAfter,
        isDirectStomp: false,
      );
      events.addAll(cascadeEvents);
    } else {
      // Just an X — no tier change.
      events.add(PlayerEvent(
        playerId: player.id,
        type: PlayerEventType.xRecorded,
        scoreBefore: scoreBefore,
        scoreAfter: scoreBefore, // score unchanged
      ));
    }

    return ScoreChangeResult(events: events);
  }

  // ---------------------------------------------------------------------------
  // 3. Stomp + Domino Cascade
  // ---------------------------------------------------------------------------

  /// Resolves the full domino cascade starting from a score landing event.
  ///
  /// A player landing on [landingScore] stomps any other player sitting
  /// exactly at that score. The stomped player drops to their previous tier,
  /// which may in turn trigger another stomp — and so on recursively until
  /// no more collisions exist.
  ///
  /// Per rules: the original trigger player (who caused the first landing)
  /// is immune to being stomped back.
  List<PlayerEvent> _resolveStompCascade({
    required List<Player> players,
    required String triggerPlayerId,
    required int landingScore,
    bool isDirectStomp = true,
  }) {
    final events = <PlayerEvent>[];

    // Track which players have already been processed this cascade
    // to prevent infinite loops.
    final processedPlayerIds = <String>{triggerPlayerId};

    // Queue of (landingScore, triggerPlayerId) pairs to resolve.
    final queue = <_StompCheck>[
      _StompCheck(landingScore: landingScore, triggerPlayerId: triggerPlayerId),
    ];

    while (queue.isNotEmpty) {
      final check = queue.removeAt(0);

      // Find all players sitting exactly at this score who haven't been
      // processed yet and are not the trigger player.
      final stomped = players.where((p) =>
          p.currentScore == check.landingScore &&
          !processedPlayerIds.contains(p.id),
      ).toList();

      for (final victim in stomped) {
        processedPlayerIds.add(victim.id);

        final scoreBefore = victim.currentScore;
        final scoreAfter = _burnCurrentTier(victim);
        victim.consecutiveXCount = 0; // stomp resets X count

        events.add(PlayerEvent(
          playerId: victim.id,
          type: (isDirectStomp && events.isEmpty)
              ? PlayerEventType.stomped
              : PlayerEventType.dominoed,
          scoreBefore: scoreBefore,
          scoreAfter: scoreAfter,
          triggeredByPlayerId: check.triggerPlayerId,
        ));

        // The victim's new score may itself cause a domino collision.
        queue.add(_StompCheck(
          landingScore: scoreAfter,
          triggerPlayerId: victim.id,
        ));
      }
    }

    return events;
  }

  // ---------------------------------------------------------------------------
  // 4. Entry status
  // ---------------------------------------------------------------------------

  /// Marks a player as entered. One-way — never reverts.
  void _markEntered(Player player) {
    if (!player.isEntered) {
      player.isEntered = true;
    }
  }

  /// Marks a player as entered externally (e.g. after successful theft).
  void markEntered(Player player) => _markEntered(player);

  // ---------------------------------------------------------------------------
  // 5. Queries
  // ---------------------------------------------------------------------------

  /// Whether a player can bank the given amount.
  /// Checks entry threshold and round number invariant.
  bool canBank(Player player, int amount) {
    if (amount % 100 != 0) return false;
    if (!player.isEntered && amount < 400) return false;
    return true;
  }

  /// Whether a player is at risk of tier burn on next X.
  bool isOnLastWarning(Player player) => player.consecutiveXCount == 2;

  /// Returns all players sitting exactly at [score].
  List<Player> playersAtScore(List<Player> players, int score) =>
      players.where((p) => p.currentScore == score).toList();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Pops the last score tier, dropping the player to their previous tier.
  /// If only one tier exists (score = 0), stays at 0.
  /// Returns the new current score.
  int _burnCurrentTier(Player player) {
    if (player.scoreTiers.length > 1) {
      player.scoreTiers.removeLast();
    }
    // Invariant: result is always a multiple of 100.
    assert(player.currentScore % 100 == 0,
        'BUG: Score tier invariant violated after burn: ${player.currentScore}');
    return player.currentScore;
  }
}

// -----------------------------------------------------------------------------
// Internal helper for cascade queue
// -----------------------------------------------------------------------------

class _StompCheck {
  final int landingScore;
  final String triggerPlayerId;

  const _StompCheck({
    required this.landingScore,
    required this.triggerPlayerId,
  });
}
