import 'package:flutter/material.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';

// ── Die display model ─────────────────────────────────────────────────────────

enum _DieStatus { blank, setAside, scoring, nonScoring, invisible }

class _DieData {
  final int index;
  final int faceValue; // 0 = blank
  final _DieStatus status;
  const _DieData(this.index, this.faceValue, this.status);
}

// ── DiceBoard ─────────────────────────────────────────────────────────────────

class DiceBoard extends StatelessWidget {
  final TurnState? turn;
  final GamePhase gamePhase;
  final TheftContext? theftContext;
  final Set<int> selectedIndices;
  final void Function(int index) onDieTapped;

  const DiceBoard({
    super.key,
    required this.turn,
    required this.gamePhase,
    required this.theftContext,
    required this.selectedIndices,
    required this.onDieTapped,
  });

  @override
  Widget build(BuildContext context) {
    final dice = _computeDice();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (gamePhase == GamePhase.stealWindow) ...[
            const Text(
              'Dice available to steal',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          // Row of 3
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++) ...[
                _SingleDie(
                  data: dice[i],
                  isSelected: selectedIndices.contains(dice[i].index),
                  onTap: dice[i].status == _DieStatus.scoring
                      ? () => onDieTapped(dice[i].index)
                      : null,
                ),
                if (i < 2) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Row of 2 (centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 3; i < 5; i++) ...[
                _SingleDie(
                  data: dice[i],
                  isSelected: selectedIndices.contains(dice[i].index),
                  onTap: dice[i].status == _DieStatus.scoring
                      ? () => onDieTapped(dice[i].index)
                      : null,
                ),
                if (i < 4) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<_DieData> _computeDice() {
    // Steal window: show N blank dice as "available to steal"
    if (gamePhase == GamePhase.stealWindow && theftContext != null) {
      final n = theftContext!.availableDiceCount;
      return List.generate(
        5,
        (i) => _DieData(i, 0, i < n ? _DieStatus.blank : _DieStatus.invisible),
      );
    }

    if (turn == null) {
      return List.generate(5, (i) => _DieData(i, 0, _DieStatus.blank));
    }

    final setAsideByIndex = {for (final d in turn!.setAsideDice) d.index: d};
    final currentRollByIndex = {for (final d in turn!.currentRoll) d.index: d};
    final scoringIndices = turn!.rollHistory.isNotEmpty
        ? turn!.rollHistory.last.scoringDice.map((d) => d.index).toSet()
        : <int>{};

    // In theft turns, the first (5 - availableDiceCount) entries in setAsideDice
    // are sentinels — render them as invisible placeholders.
    final sentinelCount = turn!.isTheftTurn
        ? (5 - (turn!.theftContext?.availableDiceCount ?? 5))
        : 0;

    return List.generate(5, (i) {
      if (i < sentinelCount) return _DieData(i, 0, _DieStatus.invisible);

      if (setAsideByIndex.containsKey(i)) {
        return _DieData(i, setAsideByIndex[i]!.face.value, _DieStatus.setAside);
      }

      if (turn!.phase == TurnPhase.hotDiceForced) {
        return _DieData(i, 0, _DieStatus.blank);
      }

      if (currentRollByIndex.containsKey(i) &&
          turn!.phase == TurnPhase.awaitingSelection) {
        final die = currentRollByIndex[i]!;
        return _DieData(
          i,
          die.face.value,
          scoringIndices.contains(i) ? _DieStatus.scoring : _DieStatus.nonScoring,
        );
      }

      return _DieData(i, 0, _DieStatus.blank);
    });
  }
}

// ── SingleDie ─────────────────────────────────────────────────────────────────

class _SingleDie extends StatelessWidget {
  final _DieData data;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SingleDie({required this.data, required this.isSelected, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (data.status == _DieStatus.invisible) {
      return const SizedBox(width: 70, height: 70);
    }

    return AnimatedSlide(
      offset: isSelected ? const Offset(0, -0.09) : Offset.zero,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: isSelected ? 3 : 1.5),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: isSelected ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: data.faceValue > 0
                ? Text(
                    '${data.faceValue}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Color get _bgColor => switch (data.status) {
        _DieStatus.blank => const Color(0xFF2A2A4A),
        _DieStatus.setAside => const Color(0xFFFFF8E7),
        _DieStatus.scoring => const Color(0xFFFFF8E7),
        _DieStatus.nonScoring => const Color(0xFF2A2A4A),
        _DieStatus.invisible => Colors.transparent,
      };

  Color get _borderColor {
    if (isSelected) return const Color(0xFFFFD700);
    return switch (data.status) {
      _DieStatus.setAside => const Color(0xFFFFD700).withValues(alpha: 0.7),
      _DieStatus.scoring => const Color(0xFFBBBBBB),
      _DieStatus.nonScoring => const Color(0xFF3A3A5A),
      _DieStatus.blank => const Color(0xFF3A3A5A),
      _DieStatus.invisible => Colors.transparent,
    };
  }

  Color get _textColor => switch (data.status) {
        _DieStatus.setAside || _DieStatus.scoring => const Color(0xFF1A1A2E),
        _DieStatus.nonScoring => const Color(0xFF555577),
        _DieStatus.blank || _DieStatus.invisible => Colors.transparent,
      };
}
