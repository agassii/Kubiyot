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

class _PlayerCard extends StatelessWidget {
  final Player player;
  final bool isCurrent;

  const _PlayerCard({required this.player, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Row(
            children: [
              if (isCurrent)
                const Text(
                  '★ ',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 14),
                ),
              Expanded(
                child: Text(
                  player.displayName,
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatScore(player.currentScore),
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white54,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _XMarks(count: player.consecutiveXCount),
        ],
      ),
    );
  }

  static String _formatScore(int score) {
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}

class _XMarks extends StatelessWidget {
  final int count;
  const _XMarks({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) ...[
          _XDot(filled: i < count),
          if (i < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _XDot extends StatelessWidget {
  final bool filled;
  const _XDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? const Color(0xFFEF4444) : const Color(0xFF374151),
        border: Border.all(
          color: filled ? const Color(0xFFEF4444) : const Color(0xFF4B5563),
          width: 1.5,
        ),
      ),
    );
  }
}
