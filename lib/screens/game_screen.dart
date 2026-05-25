import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/game_manager.dart';
import '../engine/ai_player.dart';
import '../engine/turn_state_machine.dart';
import '../models/roll_reveal.dart';
import '../providers/game_provider.dart';
import '../providers/language_provider.dart';
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
  String _lastAutoSelectKey = '';

  // AI automation
  bool _aiThinking = false;
  String _lastAiKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(gameProvider);
      if (notifier.state == null) {
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
    final s = ref.watch(stringsProvider);
    final game = notifier.state;

    // Drive AI turns on every state change.
    ref.listen<GameNotifier>(gameProvider, (_, next) {
      _handleStateChange(next);
    });

    if (game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Auto-select all scoring dice for human players.
    final turn = game.activeTurn;
    if (reveal == null && actions.mustSelect && turn != null &&
        turn.rollHistory.isNotEmpty && !notifier.isCurrentPlayerAi) {
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

    if (!actions.mustSelect && _selectedIndices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndices.clear());
      });
    }

    final isAiTurn = notifier.isCurrentPlayerAi;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
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
            // Thinking indicator shown while AI is computing.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _aiThinking
                  ? Padding(
                      key: const ValueKey('thinking'),
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        s.aiThinking,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
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
              // Disable all interactive buttons during the AI's turn.
              onRoll: isAiTurn ? null : () => ref.read(gameProvider).rollDice(),
              onBank: isAiTurn ? null : () => ref.read(gameProvider).bank(),
              onConfirm: isAiTurn ? null : _confirmSelection,
              onSteal: isAiTurn ? null : () => ref.read(gameProvider).decideTheft(true),
              onSkip: isAiTurn ? null : () => ref.read(gameProvider).decideTheft(false),
              onNewGame: _newGame,
              onDismissReveal: () => ref.read(gameProvider).dismissRollReveal(),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI automation ──────────────────────────────────────────────────────────

  void _handleStateChange(GameNotifier notifier) {
    if (!mounted) return;
    final aiKey = _computeAiKey(notifier.state, notifier.rollReveal, notifier);

    if (aiKey.isEmpty) {
      if (_aiThinking) setState(() => _aiThinking = false);
      return;
    }
    if (aiKey == _lastAiKey) return;

    setState(() {
      _lastAiKey = aiKey;
      _aiThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _lastAiKey != aiKey) return;
      setState(() => _aiThinking = false);
      _executeAiAction();
    });
  }

  String _computeAiKey(GameState? game, RollReveal? reveal, GameNotifier notifier) {
    if (game == null || game.isComplete) return '';
    if (reveal != null) return ''; // wait for roll animation to clear
    if (!notifier.isCurrentPlayerAi) return '';

    if (game.phase == GamePhase.stealWindow) {
      return 'steal:${game.currentPlayerIndex}:${identityHashCode(game.pendingTheftContext)}';
    }

    final turn = game.activeTurn;
    if (turn == null) return '';

    switch (turn.phase) {
      case TurnPhase.waitingToRoll:
      case TurnPhase.forcedContinue:
      case TurnPhase.hotDiceForced:
      case TurnPhase.awaitingSelection:
      case TurnPhase.bankingDecision:
        return '${identityHashCode(turn)}:${turn.phase.index}:${turn.rollNumber}';
      case TurnPhase.turnComplete:
        return '';
    }
  }

  void _executeAiAction() {
    final notifier = ref.read(gameProvider);
    final game = notifier.state;
    if (game == null || game.isComplete) return;

    final difficulty = notifier.currentPlayerAiDifficulty;
    if (difficulty == null) return;

    final decision = AiPlayer().decide(
      game: game,
      turn: game.activeTurn,
      difficulty: difficulty,
    );

    switch (decision.type) {
      case AiDecisionType.roll:
        notifier.rollDice();
      case AiDecisionType.bank:
        notifier.bank();
      case AiDecisionType.selectDice:
        notifier.selectDice(decision.diceIndices!);
      case AiDecisionType.steal:
        notifier.decideTheft(true);
      case AiDecisionType.skipSteal:
        notifier.decideTheft(false);
    }
  }

  // ── Human interaction ──────────────────────────────────────────────────────

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
      _lastAiKey = '';
      _aiThinking = false;
    });
    ref.read(gameProvider).dismissRollReveal();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
