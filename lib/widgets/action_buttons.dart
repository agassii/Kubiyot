import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';
import '../providers/turn_provider.dart';

class ActionButtons extends ConsumerWidget {
  final TurnActions actions;
  final bool hasSelection;
  final bool isGameOver;
  final VoidCallback? onRoll;
  final VoidCallback? onBank;
  final VoidCallback? onConfirm;
  final VoidCallback? onSteal;
  final VoidCallback? onSkip;
  final VoidCallback onNewGame;
  final VoidCallback onDismissReveal;

  const ActionButtons({
    super.key,
    required this.actions,
    required this.hasSelection,
    required this.isGameOver,
    this.onRoll,
    this.onBank,
    this.onConfirm,
    this.onSteal,
    this.onSkip,
    required this.onNewGame,
    required this.onDismissReveal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions.isRollReveal)
            _Btn(
              label: s.continueBtn,
              color: const Color(0xFF374151),
              onPressed: onDismissReveal,
            )
          else if (isGameOver)
            _Btn(label: s.newGame, color: Colors.indigo, onPressed: onNewGame)
          else if (actions.isStealWindow)
            _buildStealRow(s)
          else if (actions.mustSelect)
            _buildConfirmBtn(s)
          else
            _buildPlayRow(s),
        ],
      ),
    );
  }

  Widget _buildPlayRow(s) {
    return Row(
      children: [
        if (actions.canRoll)
          Expanded(
            child: _Btn(
              label: s.roll,
              color: const Color(0xFF3A86FF),
              onPressed: onRoll,
            ),
          ),
        if (actions.canRoll && actions.canBank) const SizedBox(width: 12),
        if (actions.canBank)
          Expanded(
            child: _Btn(
              label: s.bank,
              color: const Color(0xFF06D6A0),
              onPressed: onBank,
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmBtn(s) {
    return _Btn(
      label: hasSelection ? s.confirmSelection : s.selectOneDie,
      color: const Color(0xFF7C3AED),
      onPressed: hasSelection ? onConfirm : null,
    );
  }

  Widget _buildStealRow(s) {
    return Row(
      children: [
        Expanded(
          child: _Btn(
            label: s.steal,
            color: const Color(0xFFFF9F1C),
            onPressed: onSteal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Btn(
            label: s.skip,
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
