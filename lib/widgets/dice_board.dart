import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../engine/scoring_calculator.dart';
import '../models/roll_reveal.dart';
import '../providers/language_provider.dart';

// ── Die display model ─────────────────────────────────────────────────────────

enum _DieStatus { blank, setAside, scoring, nonScoring, invisible }

class _DieData {
  final int index;
  final int faceValue; // 0 = show placeholder "?"
  final _DieStatus status;
  const _DieData(this.index, this.faceValue, this.status);
}

// ── DiceBoard ─────────────────────────────────────────────────────────────────

class DiceBoard extends ConsumerWidget {
  final TurnState? turn;
  final GamePhase gamePhase;
  final TheftContext? theftContext;
  final Set<int> selectedIndices;
  final void Function(int index) onDieTapped;
  final RollReveal? rollReveal;
  final String? previousPlayerName; // for "Inherited from X" label in steal window

  const DiceBoard({
    super.key,
    required this.turn,
    required this.gamePhase,
    required this.theftContext,
    required this.selectedIndices,
    required this.onDieTapped,
    this.rollReveal,
    this.previousPlayerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final zone1 = _computeZone1();
    final zone2 = _computeZone2();

    final isStealWindow = gamePhase == GamePhase.stealWindow && rollReveal == null;
    final zone1Label = isStealWindow
        ? s.inheritedFrom(previousPlayerName ?? '')
        : s.locked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (zone1.isNotEmpty) ...[
            _buildZoneLabel(zone1Label, const Color(0xFFFFD700)),
            const SizedBox(height: 6),
            _buildDiceRow(zone1, selectable: false),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF2A2A4A), height: 1),
            const SizedBox(height: 14),
          ],
          if (isStealWindow && zone2.isNotEmpty) ...[
            _buildZoneLabel(
              s.yourDice(zone2.length),
              const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 6),
          ],
          _buildDiceRow(zone2, selectable: true),
        ],
      ),
    );
  }

  // ── Zone 1: locked set-aside dice ─────────────────────────────────────────

  List<_DieData> _computeZone1() {
    // During steal window: show the dice Player A set aside (from inheritedTriples).
    if (gamePhase == GamePhase.stealWindow && rollReveal == null) {
      final triples = theftContext?.inheritedTriples ?? {};
      final dice = <_DieData>[];
      int idx = 0;
      for (final entry in triples.entries) {
        for (int i = 0; i < 3 * entry.value; i++) {
          dice.add(_DieData(idx++, entry.key.value, _DieStatus.setAside));
        }
      }
      return dice;
    }
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
    if (gamePhase == GamePhase.stealWindow && rollReveal == null) {
      final n = theftContext?.availableDiceCount ?? 0;
      return List.generate(n, (i) => _DieData(i, 0, _DieStatus.blank));
    }
    if (rollReveal != null) {
      final scoringIndices =
          rollReveal!.scoringResult.scoringDice.map((d) => d.index).toSet();
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
    if (turn!.phase == TurnPhase.awaitingSelection) {
      final scoringIndices = turn!.rollHistory.isNotEmpty
          ? turn!.rollHistory.last.scoringDice.map((d) => d.index).toSet()
          : <int>{};
      return turn!.currentRoll
          .map((d) => _DieData(
                d.index,
                d.face.value,
                scoringIndices.contains(d.index)
                    ? _DieStatus.scoring
                    : _DieStatus.nonScoring,
              ))
          .toList();
    }
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
            key: ValueKey('die_${data[i].index}'),
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

// ── Single die with pseudo-3D spin animation ──────────────────────────────────

class _SingleDie extends StatefulWidget {
  final _DieData data;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SingleDie({
    super.key,
    required this.data,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_SingleDie> createState() => _SingleDieState();
}

class _SingleDieState extends State<_SingleDie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: 1.0, // start settled (flat) so blank dice don't appear rotated
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_SingleDie old) {
    super.didUpdateWidget(old);
    // Animate only when transitioning from blank → a result face.
    if (old.data.faceValue == 0 && widget.data.faceValue > 0) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.status == _DieStatus.invisible) {
      return const SizedBox(width: 60, height: 60);
    }

    return AnimatedSlide(
      offset: widget.isSelected ? const Offset(0, -0.10) : Offset.zero,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          // child is cached — rebuilt only on widget rebuild (e.g. isSelected change),
          // not on every animation frame.
          child: _buildFace(),
          builder: (context, child) {
            final t = _anim.value; // 0 → 1 over 1.1 s
            final rotY = (1 - t) * 4 * pi; // 2 full Y rotations → 0
            final rotX = (1 - t) * pi * 0.35; // slight forward tilt → 0
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.003) // perspective depth
                ..rotateX(rotX)
                ..rotateY(rotY),
              child: child,
            );
          },
        ),
      ),
    );
  }

  Widget _buildFace() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: widget.isSelected ? 3 : 1.5),
        boxShadow: [
          BoxShadow(
            color: widget.isSelected
                ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: widget.isSelected ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final face = widget.data.faceValue;
    if (face > 0) {
      return CustomPaint(
        size: const Size(44, 44),
        painter: _DotPainter(face: face, dotColor: _dotColor),
      );
    }
    if (widget.data.status == _DieStatus.blank) {
      return const Text(
        '?',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A3A6A),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Color get _bgColor => switch (widget.data.status) {
        _DieStatus.blank => const Color(0xFF2A2A4A),
        _DieStatus.setAside => const Color(0xFFFFF8E7),
        _DieStatus.scoring => const Color(0xFFFFF8E7),
        _DieStatus.nonScoring => const Color(0xFF2A2A4A),
        _DieStatus.invisible => Colors.transparent,
      };

  Color get _borderColor {
    if (widget.isSelected) return const Color(0xFFFFD700);
    return switch (widget.data.status) {
      _DieStatus.setAside => const Color(0xFFFFD700).withValues(alpha: 0.7),
      _DieStatus.scoring => const Color(0xFFBBBBBB),
      _DieStatus.nonScoring => const Color(0xFF3A3A5A),
      _DieStatus.blank => const Color(0xFF3A3A5A),
      _DieStatus.invisible => Colors.transparent,
    };
  }

  Color get _dotColor => switch (widget.data.status) {
        _DieStatus.setAside || _DieStatus.scoring => const Color(0xFF1A1A2E),
        _DieStatus.nonScoring => const Color(0xFF4A4A6A),
        _ => Colors.transparent,
      };
}

// ── Dot painter ───────────────────────────────────────────────────────────────

class _DotPainter extends CustomPainter {
  final int face;
  final Color dotColor;

  const _DotPainter({required this.face, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (face < 1 || face > 6) return;
    final paint = Paint()..color = dotColor;
    final r = size.width * 0.115;
    for (final p in _positions(size)) {
      canvas.drawCircle(p, r, paint);
    }
  }

  List<Offset> _positions(Size s) {
    final w = s.width;
    final h = s.height;
    final l = w * 0.28;
    final cx = w * 0.50;
    final r = w * 0.72;
    final t = h * 0.24;
    final cy = h * 0.50;
    final b = h * 0.76;

    return switch (face) {
      1 => [Offset(cx, cy)],
      2 => [Offset(r, t), Offset(l, b)],
      3 => [Offset(r, t), Offset(cx, cy), Offset(l, b)],
      4 => [Offset(l, t), Offset(r, t), Offset(l, b), Offset(r, b)],
      5 => [Offset(l, t), Offset(r, t), Offset(cx, cy), Offset(l, b), Offset(r, b)],
      6 => [
          Offset(l, t), Offset(r, t),
          Offset(l, cy), Offset(r, cy),
          Offset(l, b), Offset(r, b),
        ],
      _ => [],
    };
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.face != face || old.dotColor != dotColor;
}
