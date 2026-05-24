// =============================================================================
// home_screen.dart
// Kubiyot — Placeholder home screen (replaced in Phase 5)
//
// Shows a "Start Game" button when no game is active,
// or "Continue" / "New Game" when one is saved.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../engine/game_manager.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(gameProvider);
    final game = notifier.state;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'קוביות',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'משחק הקוביות',
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
            const SizedBox(height: 64),
            if (game != null && !game.isComplete) ...[
              _StatusCard(game: game),
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'המשך משחק',
                onPressed: () {}, // replaced in Phase 5
              ),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: 'משחק חדש',
                onPressed: () => _startNewGame(context, ref),
              ),
            ] else ...[
              _PrimaryButton(
                label: 'התחל משחק',
                onPressed: () => _startNewGame(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startNewGame(BuildContext context, WidgetRef ref) {
    // Placeholder: start a 2-player game — replaced by a setup dialog in Phase 5
    final notifier = ref.read(gameProvider);
    notifier.createGame(['שחקן 1', 'שחקן 2']);
    notifier.startGame();
  }
}

// -----------------------------------------------------------------------------
// Internal widgets
// -----------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final GameState game;
  const _StatusCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final current = game.currentPlayer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'תור: ${current.displayName}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'ניקוד: ${current.currentScore}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
