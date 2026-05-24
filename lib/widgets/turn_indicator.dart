import 'package:flutter/material.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../models/roll_reveal.dart';

class TurnIndicator extends StatelessWidget {
  final GameState game;
  final RollReveal? rollReveal;
  final VoidCallback? onNewGame;

  const TurnIndicator({
    super.key,
    required this.game,
    this.rollReveal,
    this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: rollReveal != null
          ? _buildRevealRow()
          : game.isComplete
              ? _buildWinRow()
              : _buildTurnRow(),
    );
  }

  // ── Roll reveal message ────────────────────────────────────────────────────

  Widget _buildRevealRow() {
    final reveal = rollReveal!;
    final String message;
    final Color color;

    if (reveal.isHotDice) {
      message = '🔥  ${reveal.playerName} — HOT DICE!  +200';
      color = const Color(0xFFFF9F1C);
    } else if (reveal.isFarkle) {
      message = '💥  ${reveal.playerName} — FARKLE!';
      color = const Color(0xFFEF4444);
    } else if (reveal.isCeilingBust) {
      message = '💥  ${reveal.playerName} — BUST! Over 10,000';
      color = const Color(0xFFEF4444);
    } else if (reveal.isWin) {
      message = '🏆  ${reveal.playerName} wins!';
      color = const Color(0xFFFFD700);
    } else {
      return _buildTurnRow();
    }

    return Text(
      message,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ── Win banner ─────────────────────────────────────────────────────────────

  Widget _buildWinRow() {
    final winner = game.winner!;
    return Row(
      children: [
        const Text('🏆 ', style: TextStyle(fontSize: 20)),
        Text(
          '${winner.displayName} wins!',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_formatScore(winner.currentScore)} pts',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  // ── Normal turn info ───────────────────────────────────────────────────────

  Widget _buildTurnRow() {
    final scoreLabel = game.phase == GamePhase.stealWindow
        ? 'Available to steal: '
        : 'Turn score: ';
    final score = game.phase == GamePhase.stealWindow
        ? game.pendingTheftContext?.inheritedScore
        : game.activeTurn?.temporaryScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('▶ ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
            Text(
              '${game.currentPlayer.displayName}\'s turn',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((game.activeTurn?.hotDiceCount ?? 0) > 0) ...[
              const SizedBox(width: 8),
              const Text('🔥', style: TextStyle(fontSize: 16)),
            ],
            const Spacer(),
            // Persistent restart button (Bug #9)
            if (onNewGame != null)
              GestureDetector(
                onTap: onNewGame,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.refresh,
                    color: Color(0xFF4B5563),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          Text(
            '$scoreLabel${_formatScore(score)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
        if (_contextMessage != null) ...[
          const SizedBox(height: 2),
          Text(
            _contextMessage!,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ],
    );
  }

  String? get _contextMessage {
    if (game.phase == GamePhase.stealWindow) {
      final n = game.pendingTheftContext?.availableDiceCount;
      return n != null ? '$n dice remaining — steal or skip?' : null;
    }
    return switch (game.activeTurn?.phase) {
      TurnPhase.awaitingSelection => 'Tap scoring dice to select, then confirm',
      TurnPhase.bankingDecision => 'Roll again or bank your score',
      TurnPhase.forcedContinue => 'Score not round — must keep rolling',
      TurnPhase.hotDiceForced => 'All 5 scored! Roll all dice again (+200 bonus)',
      _ => null,
    };
  }

  static String _formatScore(int score) {
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}
