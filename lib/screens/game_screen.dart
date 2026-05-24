import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../providers/game_provider.dart';
import '../providers/turn_provider.dart';
import '../widgets/dice_board.dart';
import '../widgets/score_panel.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/action_buttons.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final Set<int> _selectedIndices = {};
  int _lastAutoSelectRoll = -1;

  @override
  void initState() {
    super.initState();
    // Create and start a game if none is loaded from Hive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(gameProvider);
      if (notifier.state == null) {
        notifier.createGame(['Player 1', 'Player 2']);
        notifier.startGame();
      } else if (notifier.state!.phase == GamePhase.setup) {
        notifier.startGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(gameProvider);
    final actions = ref.watch(turnActionsProvider);
    final game = notifier.state;

    if (game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Auto-select all scoring dice when a new roll enters awaitingSelection.
    final turn = game.activeTurn;
    if (actions.mustSelect &&
        turn != null &&
        turn.rollHistory.isNotEmpty &&
        turn.rollNumber != _lastAutoSelectRoll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scoringIndices =
            turn.rollHistory.last.scoringDice.map((d) => d.index).toSet();
        setState(() {
          _selectedIndices
            ..clear()
            ..addAll(scoringIndices);
          _lastAutoSelectRoll = turn.rollNumber;
        });
      });
    }

    // Clear selection whenever we leave awaitingSelection.
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
            ScorePanel(
              players: game.players,
              currentPlayerIndex: game.currentPlayerIndex,
            ),
            TurnIndicator(game: game),
            Expanded(
              child: DiceBoard(
                turn: game.activeTurn,
                gamePhase: game.phase,
                theftContext: game.pendingTheftContext,
                selectedIndices: _selectedIndices,
                onDieTapped: _handleDieTap,
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
      _lastAutoSelectRoll = -1;
    });
    ref.read(gameProvider).createGame(['Player 1', 'Player 2']);
    ref.read(gameProvider).startGame();
  }
}
