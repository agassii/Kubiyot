import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../providers/game_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/help_modal.dart';
import '../widgets/lang_toggle.dart';
import 'game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _playerCount = 2;
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _playerCount; i++) {
      _controllers.add(TextEditingController(text: 'Player ${i + 1}'));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _setPlayerCount(int count) {
    final s = ref.read(stringsProvider);
    setState(() {
      if (count > _playerCount) {
        for (int i = _playerCount; i < count; i++) {
          _controllers.add(TextEditingController(text: s.playerDefault(i + 1)));
        }
      } else {
        for (int i = count; i < _playerCount; i++) {
          _controllers[i].dispose();
        }
        _controllers.removeRange(count, _playerCount);
      }
      _playerCount = count;
    });
  }

  void _continueSavedGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _startGame() {
    final s = ref.read(stringsProvider);
    final names = [
      for (int i = 0; i < _controllers.length; i++)
        _controllers[i].text.trim().isEmpty
            ? s.playerDefault(i + 1)
            : _controllers[i].text.trim(),
    ];
    ref.read(gameProvider).createGame(names);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final savedGame = ref.watch(gameProvider).state;
    final hasSavedGame = savedGame != null && !savedGame.isComplete;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: help + language toggle ────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => HelpModal.show(context),
                    child: const Icon(
                      Icons.help_outline,
                      color: Color(0xFF4B5563),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const LangToggle(),
                ],
              ),
              const SizedBox(height: 16),

              // ── Title ───────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text(
                      'קוביות',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.appSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Saved game banner ───────────────────────────────────────
              if (hasSavedGame) ...[
                _SavedGameBanner(
                  game: savedGame!,
                  s: s,
                  onContinue: _continueSavedGame,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF2A2A4A))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        s.orStartNew,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF2A2A4A))),
                  ],
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 8),

              // ── Player count ────────────────────────────────────────────
              _sectionLabel(s.numPlayers),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final n in [2, 3, 4, 5, 6]) ...[
                    _CountChip(
                      count: n,
                      isSelected: _playerCount == n,
                      onTap: () => _setPlayerCount(n),
                    ),
                    if (n < 6) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // ── Player names ────────────────────────────────────────────
              _sectionLabel(s.playerNames),
              const SizedBox(height: 10),
              for (int i = 0; i < _playerCount; i++) ...[
                _NameField(
                  controller: _controllers[i],
                  label: s.playerLabel(i + 1),
                ),
                if (i < _playerCount - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 28),

              // ── Game mode ───────────────────────────────────────────────
              _sectionLabel(s.gameMode),
              const SizedBox(height: 10),
              _ModeRow(label: s.modeLocal, isSelected: true),
              const SizedBox(height: 8),
              _ModeRow(
                label: s.modeComputer,
                isSelected: false,
                comingSoon: true,
                comingSoonLabel: s.comingSoon,
              ),
              const SizedBox(height: 8),
              _ModeRow(
                label: s.modeOnline,
                isSelected: false,
                comingSoon: true,
                comingSoonLabel: s.comingSoon,
              ),
              const SizedBox(height: 44),

              // ── Start button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    s.startGame,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Player count chip ─────────────────────────────────────────────────────────

class _CountChip extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountChip({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A86FF) : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3A86FF)
                : const Color(0xFF2A2A4A),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Saved game banner ─────────────────────────────────────────────────────────

class _SavedGameBanner extends StatelessWidget {
  final dynamic game;
  final AppStrings s;
  final VoidCallback onContinue;

  const _SavedGameBanner({
    required this.game,
    required this.s,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final players = game.players as List;
    final playerNames =
        players.map((p) => p.displayName as String).join(s.vsSeparator);
    final current = game.currentPlayer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A86FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.save_rounded,
                  color: Color(0xFF3A86FF), size: 16),
              const SizedBox(width: 8),
              Text(
                s.savedGame,
                style: const TextStyle(
                  color: Color(0xFF3A86FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            playerNames,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            s.savedTurnInfo(
                current.displayName as String, current.currentScore as int),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                s.continueGame,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player name text field ────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NameField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF16213E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A86FF), width: 2),
        ),
      ),
    );
  }
}

// ── Game mode row ─────────────────────────────────────────────────────────────

class _ModeRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool comingSoon;
  final String comingSoonLabel;
  final VoidCallback? onTap;

  const _ModeRow({
    super.key,
    required this.label,
    required this.isSelected,
    this.comingSoon = false,
    this.comingSoonLabel = 'Coming Soon',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: comingSoon ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3A86FF)
                : const Color(0xFF2A2A4A),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF3A86FF)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3A86FF)
                      : const Color(0xFF4B5563),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 10, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: comingSoon ? const Color(0xFF4B5563) : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            if (comingSoon)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  comingSoonLabel,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
