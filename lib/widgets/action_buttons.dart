import 'package:flutter/material.dart';
import '../providers/turn_provider.dart';

class ActionButtons extends StatelessWidget {
  final TurnActions actions;
  final bool hasSelection;
  final bool isGameOver;
  final VoidCallback onRoll;
  final VoidCallback onBank;
  final VoidCallback onConfirm;
  final VoidCallback onSteal;
  final VoidCallback onSkip;
  final VoidCallback onNewGame;
  final VoidCallback onDismissReveal;

  const ActionButtons({
    super.key,
    required this.actions,
    required this.hasSelection,
    required this.isGameOver,
    required this.onRoll,
    required this.onBank,
    required this.onConfirm,
    required this.onSteal,
    required this.onSkip,
    required this.onNewGame,
    required this.onDismissReveal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions.isRollReveal)
            _Btn(
              label: 'Continue ▶',
              color: const Color(0xFF374151),
              onPressed: onDismissReveal,
            )
          else if (isGameOver)
            _Btn(label: 'New Game', color: Colors.indigo, onPressed: onNewGame)
          else if (actions.isStealWindow)
            _buildStealRow()
          else if (actions.mustSelect)
            _buildConfirmBtn()
          else
            _buildPlayRow(),
        ],
      ),
    );
  }

  Widget _buildPlayRow() {
    return Row(
      children: [
        if (actions.canRoll)
          Expanded(
            child: _Btn(
              label: 'Roll 🎲',
              color: const Color(0xFF3A86FF),
              onPressed: onRoll,
            ),
          ),
        if (actions.canRoll && actions.canBank) const SizedBox(width: 12),
        if (actions.canBank)
          Expanded(
            child: _Btn(
              label: 'Bank ✓',
              color: const Color(0xFF06D6A0),
              onPressed: onBank,
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmBtn() {
    return _Btn(
      label: hasSelection ? 'Confirm Selection ▶' : 'Select at least one die',
      color: const Color(0xFF7C3AED),
      onPressed: hasSelection ? onConfirm : null,
    );
  }

  Widget _buildStealRow() {
    return Row(
      children: [
        Expanded(
          child: _Btn(
            label: 'Steal ⚡',
            color: const Color(0xFFFF9F1C),
            onPressed: onSteal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Btn(
            label: 'Skip ▶',
            color: const Color(0xFF6B7280),
            onPressed: onSkip,
          ),
        ),
      ],
    );
  }
}

// ── Shared button ─────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _Btn({required this.label, required this.color, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : color.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: enabled ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
