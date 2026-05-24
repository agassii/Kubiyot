import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../l10n/app_strings.dart';
import '../models/roll_reveal.dart';
import '../providers/language_provider.dart';

class TurnIndicator extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: rollReveal != null
          ? _buildRevealRow(s)
          : game.isComplete
              ? _buildWinRow(s)
              : _buildTurnRow(s),
    );
  }

  // ── Roll reveal message ────────────────────────────────────────────────────

  Widget _buildRevealRow(AppStrings s) {
    final reveal = rollReveal!;
    final String message;
    final Color color;

    if (reveal.isHotDice) {
      message = s.hotDice(reveal.playerName);
      color = const Color(0xFFFF9F1C);
    } else if (reveal.isFarkle) {
      message = s.farkle(reveal.playerName);
      color = const Color(0xFFEF4444);
    } else if (reveal.isCeilingBust) {
      message = s.ceilingBust(reveal.playerName);
      color = const Color(0xFFEF4444);
    } else if (reveal.isWin) {
      message = s.winsReveal(reveal.playerName);
      color = const Color(0xFFFFD700);
    } else {
      return _buildTurnRow(s);
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

  Widget _buildWinRow(AppStrings s) {
    final winner = game.winner!;
    return Row(
      children: [
        const Text('🏆 ', style: TextStyle(fontSize: 20)),
        Text(
          s.winsBanner(winner.displayName),
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s.winsScore(winner.currentScore),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  // ── Turn score + context (displayed below the dice board) ─────────────────

  Widget _buildTurnRow(AppStrings s) {
    final scoreLabel = game.phase == GamePhase.stealWindow
        ? s.availableToSteal
        : s.turnScore;
    final score = game.phase == GamePhase.stealWindow
        ? game.pendingTheftContext?.inheritedScore
        : game.activeTurn?.temporaryScore;
    final showScore = score != null && score > 0;
    final msg = _contextMessage(s);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showScore)
                Text(
                  '$scoreLabel${_formatScore(score!)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (msg != null) ...[
                if (showScore) const SizedBox(height: 2),
                Text(
                  msg,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        if (onNewGame != null)
          GestureDetector(
            onTap: onNewGame,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.refresh, color: Color(0xFF4B5563), size: 18),
            ),
          ),
      ],
    );
  }

  String? _contextMessage(AppStrings s) {
    if (game.phase == GamePhase.stealWindow) {
      final n = game.pendingTheftContext?.availableDiceCount;
      return n != null ? s.diceRemaining(n) : null;
    }
    final turn = game.activeTurn;
    return switch (turn?.phase) {
      TurnPhase.awaitingSelection => _selectionMsg(turn!, s),
      TurnPhase.bankingDecision => s.rollAgainOrBank,
      TurnPhase.forcedContinue => s.scoreNotRound,
      TurnPhase.hotDiceForced => s.hotDiceForced,
      _ => null,
    };
  }

  String _selectionMsg(TurnState turn, AppStrings s) {
    if (turn.rollHistory.isEmpty) return s.selectDice;
    final pts = turn.rollHistory.last.rollPoints;
    return s.rollAvailable(pts);
  }

  static String _formatScore(int score) {
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}
