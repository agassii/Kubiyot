import 'package:flutter/material.dart';
import '../engine/player_manager.dart';

class ScorePanel extends StatelessWidget {
  final List<Player> players;
  final int currentPlayerIndex;

  const ScorePanel({
    super.key,
    required this.players,
    required this.currentPlayerIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          for (int i = 0; i < players.length; i++) ...[
            Expanded(
              child: _PlayerCard(
                player: players[i],
                isCurrent: i == currentPlayerIndex,
              ),
            ),
            if (i < players.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── Player card ───────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Player player;
  final bool isCurrent;

  const _PlayerCard({required this.player, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF1E3A5F) : const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? const Color(0xFFFFD700) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNameRow(),
          const SizedBox(height: 5),
          _buildScoreSection(),
          const SizedBox(height: 6),
          _XMarks(count: player.consecutiveXCount),
        ],
      ),
    );
  }

  // ── Name row ──────────────────────────────────────────────────────────────

  Widget _buildNameRow() {
    return Row(
      children: [
        if (isCurrent)
          const Text('★ ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
        Expanded(
          child: Text(
            player.displayName,
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Entry badge
        if (!player.isEntered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  // ── Score section — tier ladder with strikethrough ────────────────────────

  Widget _buildScoreSection() {
    final atRisk = player.consecutiveXCount == 2;
    final current = player.currentScore;

    // Color for the current (live) score.
    final Color scoreColor;
    if (atRisk) {
      scoreColor = const Color(0xFFFF9F1C); // orange = one X away from tier burn
    } else if (isCurrent) {
      scoreColor = Colors.white;
    } else {
      scoreColor = Colors.white54;
    }

    // Previous non-zero tier (the safety-net score the player would drop to).
    final prevTier = player.scoreTiers.length >= 2
        ? player.scoreTiers[player.scoreTiers.length - 2]
        : null;
    final showPrev = prevTier != null && prevTier > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous tier shown with strikethrough — visually "passed" score.
        if (showPrev)
          Text(
            _fmt(prevTier!),
            style: TextStyle(
              color: atRisk
                  ? const Color(0xFF9CA3AF) // grey when at risk
                  : const Color(0xFF4B5563),
              fontSize: 11,
              height: 1.1,
              decoration: TextDecoration.lineThrough,
              decorationColor: atRisk
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF4B5563),
              decorationThickness: 1.5,
            ),
          ),
        // Current score
        Text(
          _fmt(current),
          style: TextStyle(
            color: scoreColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  static String _fmt(int score) {
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}

// ── X-mark row ────────────────────────────────────────────────────────────────

class _XMarks extends StatelessWidget {
  final int count;
  const _XMarks({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) ...[
          _XDot(filled: i < count, isLast: i == 2),
          if (i < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _XDot extends StatelessWidget {
  final bool filled;
  final bool isLast; // third dot = danger

  const _XDot({required this.filled, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    if (filled) {
      fill = isLast ? const Color(0xFFFF9F1C) : const Color(0xFFEF4444);
      border = fill;
    } else {
      fill = Colors.transparent;
      border = const Color(0xFF4B5563);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.5),
      ),
      child: filled
          ? const Center(
              child: Text(
                '✕',
                style: TextStyle(
                  fontSize: 6,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            )
          : null,
    );
  }
}
