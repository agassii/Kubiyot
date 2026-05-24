import 'package:flutter/material.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../engine/scoring_calculator.dart';
import '../models/roll_reveal.dart';

// ── Die display model ─────────────────────────────────────────────────────────

enum _DieStatus { blank, setAside, scoring, nonScoring, invisible }

class _DieData {
  final int index;
  final int faceValue; // 0 = show placeholder "?"
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
  final RollReveal? rollReveal;

  const DiceBoard({
    super.key,
    required this.turn,
    required this.gamePhase,
    required this.theftContext,
    required this.selectedIndices,
    required this.onDieTapped,
    this.rollReveal,
  });

  @override
  Widget build(BuildContext context) {
    final zone1 = _computeZone1();
    final zone2 = _computeZone2();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Steal window header
          if (gamePhase == GamePhase.stealWindow && rollReveal == null) ...[
            const Text(
              'Dice available to steal',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          // Zone 1: locked / set-aside dice
          if (zone1.isNotEmpty) ...[
            _buildZoneLabel('LOCKED', const Color(0xFFFFD700)),
            const SizedBox(height: 6),
            _buildDiceRow(zone1, selectable: false),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF2A2A4A), height: 1),
            const SizedBox(height: 14),
          ],

          // Zone 2: active / rolling dice
          _buildDiceRow(zone2, selectable: true),
        ],
      ),
    );
  }

  // ── Zone 1: locked set-aside dice ─────────────────────────────────────────

  List<_DieData> _computeZone1() {
    final source = rollReveal != null ? rollReveal!.setAsideDice : (turn?.setAsideDice ?? []);
    final skip = rollReveal != null
        ? rollReveal!.sentinelCount
        : (turn?.isTheftTurn == true
            ? (5 - (turn!.theftContext?.availableDiceCount ?? 5))
            : 0);

    return source
        .skip(skip)
        .map((d) => _DieData(d.index, d.face.value, _DieStatus.setAside))
        .toList();
  }

  // ── Zone 2: active dice ───────────────────────────────────────────────────

  List<_DieData> _computeZone2() {
    // ── Steal window ─────────────────────────────────────────────────────
    if (gamePhase == GamePhase.stealWindow && rollReveal == null) {
      final n = theftContext?.availableDiceCount ?? 0;
      return List.generate(n, (i) => _DieData(i, 0, _DieStatus.blank));
    }

    // ── Roll reveal ───────────────────────────────────────────────────────
    if (rollReveal != null) {
      final scoringIndices = rollReveal!.scoringResult.scoringDice
          .map((d) => d.index)
          .toSet();
      return rollReveal!.rolledDice.map((d) {
        final status = scoringIndices.contains(d.index)
            ? _DieStatus.scoring
            : _DieStatus.nonScoring;
        return _DieData(d.index, d.face.value, status);
      }).toList();
    }

    if (turn == null) {
      return List.generate(5, (i) => _DieData(i, 0, _DieStatus.blank));
    }

    // ── awaitingSelection: show rolled dice with scoring/nonScoring colors ─
    if (turn!.phase == TurnPhase.awaitingSelection) {
      final scoringIndices = turn!.rollHistory.isNotEmpty
          ? turn!.rollHistory.last.scoringDice.map((d) => d.index).toSet()
          : <int>{};
      return turn!.currentRoll.map((d) => _DieData(
            d.index,
            d.face.value,
            scoringIndices.contains(d.index)
                ? _DieStatus.scoring
                : _DieStatus.nonScoring,
          )).toList();
    }

    // ── All other phases: show N blank placeholder dice ────────────────────
    // N = availableDiceCount (already accounts for hotDiceForced = 5)
    final n = turn!.availableDiceCount;
    return List.generate(n, (i) => _DieData(i, 0, _DieStatus.blank));
  }

  // ── Rendering helpers ─────────────────────────────────────────────────────

  Widget _buildZoneLabel(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDiceRow(List<_DieData> data, {required bool selectable}) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < data.length; i++) ...[
          _SingleDie(
            data: data[i],
            isSelected: selectedIndices.contains(data[i].index),
            onTap: selectable && data[i].status == _DieStatus.scoring
                ? () => onDieTapped(data[i].index)
                : null,
          ),
          if (i < data.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
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
      return const SizedBox(width: 60, height: 60);
    }

    return AnimatedSlide(
      offset: isSelected ? const Offset(0, -0.10) : Offset.zero,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 60,
          height: 60,
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
          child: Center(child: _buildContent()),
        ),
      ),
    );
  }

  Widget? _buildContent() {
    if (data.faceValue > 0) {
      return Text(
        '${data.faceValue}',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      );
    }
    // Blank die: show "?" placeholder
    if (data.status == _DieStatus.blank) {
      return const Text(
        '?',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A3A6A),
        ),
      );
    }
    return null;
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
