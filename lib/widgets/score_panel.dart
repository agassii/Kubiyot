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
        crossAxisAlignment: CrossAxisAlignment.start,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNameRow(),
        const SizedBox(height: 4),
        _buildTable(),
      ],
    );
  }

  // ── Name above table ──────────────────────────────────────────────────────

  Widget _buildNameRow() {
    return Row(
      children: [
        if (isCurrent)
          const Text('★ ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
        Expanded(
          child: Text(
            player.displayName,
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ── Tier table ────────────────────────────────────────────────────────────

  Widget _buildTable() {
    // scoreTiers: [0] = not entered; additional elements = banked tier scores.
    // Reverse so newest (highest) tier appears at the top of the table.
    final tiers = player.scoreTiers.reversed.where((t) => t > 0).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? const Color(0xFFFFD700) : const Color(0xFF2A2A4A),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: tiers.isEmpty
          ? _buildEmptyRow()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < tiers.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: Color(0xFF2A2A4A)),
                  _buildTierRow(tiers[i], isNewestTier: i == 0),
                ],
              ],
            ),
    );
  }

  // Not-entered placeholder row.
  Widget _buildEmptyRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '—',
              style: TextStyle(color: Colors.white24, fontSize: 18, height: 1.1),
            ),
          ),
          _XMarks(count: player.consecutiveXCount),
        ],
      ),
    );
  }

  Widget _buildTierRow(int score, {required bool isNewestTier}) {
    final atRisk = isNewestTier && player.consecutiveXCount == 2;

    final Color scoreColor;
    if (atRisk) {
      scoreColor = const Color(0xFFFF9F1C);
    } else if (isNewestTier) {
      scoreColor = isCurrent ? Colors.white : Colors.white70;
    } else {
      scoreColor = const Color(0xFF374151);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, isNewestTier ? 8 : 5, 8, isNewestTier ? 8 : 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _fmt(score),
              style: TextStyle(
                color: scoreColor,
                fontSize: isNewestTier ? 20 : 12,
                fontWeight: isNewestTier ? FontWeight.bold : FontWeight.normal,
                height: 1.1,
              ),
            ),
          ),
          _XMarks(count: isNewestTier ? player.consecutiveXCount : 0),
        ],
      ),
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
