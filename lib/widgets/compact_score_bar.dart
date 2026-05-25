import 'package:flutter/material.dart';
import '../engine/player_manager.dart';
import 'score_panel.dart';

class CompactScoreBar extends StatelessWidget {
  final List<Player> players;
  final int currentPlayerIndex;
  final Set<int>? disconnectedPlayerIndices;

  const CompactScoreBar({
    super.key,
    required this.players,
    required this.currentPlayerIndex,
    this.disconnectedPlayerIndices,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTierHistory(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < players.length; i++) ...[
              Expanded(
                child: _PlayerChip(
                  player: players[i],
                  isCurrent: i == currentPlayerIndex,
                  isDisconnected:
                      disconnectedPlayerIndices?.contains(i) ?? false,
                ),
              ),
              if (i < players.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  void _showTierHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TierHistorySheet(
        players: players,
        currentPlayerIndex: currentPlayerIndex,
      ),
    );
  }
}

// ── Per-player chip in the compact bar ────────────────────────────────────────

class _PlayerChip extends StatelessWidget {
  final Player player;
  final bool isCurrent;
  final bool isDisconnected;

  const _PlayerChip({
    required this.player,
    required this.isCurrent,
    this.isDisconnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? const Color(0xFFFFD700) : const Color(0xFF2A2A4A),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNameRow(),
          const SizedBox(height: 3),
          _buildScoreRow(),
        ],
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        if (isCurrent)
          const Text('★ ',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
        Expanded(
          child: Text(
            player.displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (isDisconnected)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(left: 3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF4444),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreRow() {
    final atRisk = player.consecutiveXCount == 2;
    return Row(
      children: [
        Expanded(
          child: Text(
            _fmt(player.currentScore),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: atRisk
                  ? const Color(0xFFFF9F1C)
                  : (isCurrent ? Colors.white : Colors.white70),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ),
        _MiniXDots(count: player.consecutiveXCount),
      ],
    );
  }

  static String _fmt(int score) {
    if (score == 0) return '—';
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}

// ── Mini X dots (no animation — summary view only) ────────────────────────────

class _MiniXDots extends StatelessWidget {
  final int count;
  const _MiniXDots({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) ...[
          _dot(i),
          if (i < 2) const SizedBox(width: 3),
        ],
      ],
    );
  }

  Widget _dot(int i) {
    final filled = i < count;
    final isLast = i == 2;
    final Color fill;
    final Color border;
    if (filled) {
      fill = isLast ? const Color(0xFFFF9F1C) : const Color(0xFFEF4444);
      border = fill;
    } else {
      fill = Colors.transparent;
      border = const Color(0xFF4B5563);
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.5),
      ),
    );
  }
}

// ── Bottom sheet: full tier history ──────────────────────────────────────────

class _TierHistorySheet extends StatelessWidget {
  final List<Player> players;
  final int currentPlayerIndex;

  const _TierHistorySheet({
    required this.players,
    required this.currentPlayerIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF4B5563),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            child: ScorePanel(
              players: players,
              currentPlayerIndex: currentPlayerIndex,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
