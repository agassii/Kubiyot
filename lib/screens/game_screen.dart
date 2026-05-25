import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../providers/game_provider.dart';
import '../providers/turn_provider.dart';
import '../widgets/dice_board.dart';
import '../widgets/help_modal.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/compact_score_bar.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/action_buttons.dart';
import 'home_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final Set<int> _selectedIndices = {};
  // Combines playerId + rollNumber so the key is unique across player changes.
  // Fixes the freeze where a new player's rollNumber == 1 matched the prior
  // player's last-seen roll 1, preventing auto-select from firing.
  String _lastAutoSelectKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(gameProvider);
      if (notifier.state == null) {
        // No game loaded — return to setup screen.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (notifier.state!.phase == GamePhase.setup) {
        notifier.startGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(gameProvider);
    final actions = ref.watch(turnActionsProvider);
    final reveal = ref.watch(rollRevealProvider);
    final game = notifier.state;

    if (game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Auto-select all scoring dice when a new roll lands in awaitingSelection.
    // Guard: don't fire during reveal (the reveal covers this roll already).
    final turn = game.activeTurn;
    if (reveal == null && actions.mustSelect && turn != null && turn.rollHistory.isNotEmpty) {
      // Key uses object identity (not just playerId) so a new turn's rollNumber=1
      // never collides with the same player's previous turn's rollNumber=1.
      final key = '${identityHashCode(turn)}:${turn.rollNumber}';
      if (key != _lastAutoSelectKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final scoringIndices =
              turn.rollHistory.last.scoringDice.map((d) => d.index).toSet();
          setState(() {
            _selectedIndices
              ..clear()
              ..addAll(scoringIndices);
            _lastAutoSelectKey = key;
          });
        });
      }
    }

    // Clear selection when leaving awaitingSelection.
    if (!actions.mustSelect && _selectedIndices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndices.clear());
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: help + language toggle ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => HelpModal.show(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.help_outline,
                        color: Color(0xFF4B5563),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const LangToggle(),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            SizedBox(
              height: 80,
              child: CompactScoreBar(
                players: game.players,
                currentPlayerIndex: game.currentPlayerIndex,
              ),
            ),
            SizedBox(
              height: 48,
              child: TurnIndicator(
                game: game,
                rollReveal: reveal,
                onNewGame: _newGame,
              ),
            ),
            Expanded(
              child: DiceBoard(
                turn: game.activeTurn,
                gamePhase: game.phase,
                theftContext: game.pendingTheftContext,
                selectedIndices: _selectedIndices,
                onDieTapped: _handleDieTap,
                rollReveal: reveal,
                previousPlayerName: game.phase == GamePhase.stealWindow
                    ? game.players[
                            (game.currentPlayerIndex - 1 + game.players.length) %
                                game.players.length]
                        .displayName
                    : null,
              ),
            ),
            ActionButtons(
              actions: actions,
              hasSelection: _selectedIndices.isNotEmpty,
              isGameOver: game.isComplete,
              onRoll: () => ref.read(gameProvider).rollDice(),
              onBank: () => ref.read(gameProvider).bank(),
              onConfirm: _confirmSelection,
              onSteal: () => ref.read(gameProvider).decideTheft(true),
              onSkip: () => ref.read(gameProvider).decideTheft(false),
              onNewGame: _newGame,
              onDismissReveal: () => ref.read(gameProvider).dismissRollReveal(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDieTap(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _confirmSelection() {
    if (_selectedIndices.isEmpty) return;
    ref.read(gameProvider).selectDice(_selectedIndices.toList());
    setState(() => _selectedIndices.clear());
  }

  void _newGame() {
    setState(() {
      _selectedIndices.clear();
      _lastAutoSelectKey = '';
    });
    ref.read(gameProvider).dismissRollReveal();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
