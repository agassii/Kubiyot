import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../multiplayer/room_player.dart';
import '../providers/language_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'game_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  bool _starting = false;
  bool _codeCopied = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final mpState = ref.watch(multiplayerProvider);

    // Navigate to game when host starts
    ref.listen<MultiplayerState>(multiplayerProvider, (_, next) {
      if (next.phase == MultiplayerPhase.inGame && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    });

    final players = mpState.roomPlayers;
    final canStart = mpState.isHost && players.length >= 2 && !_starting;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(s.modeOnline,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(multiplayerProvider.notifier).leave();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Room code ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      s.roomCode.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF3A86FF), width: 2),
                        ),
                        child: Text(
                          mpState.roomCode ?? '----',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _codeCopied
                          ? Text(
                              s.codeCopied,
                              key: const ValueKey('copied'),
                              style: const TextStyle(
                                  color: Color(0xFF06D6A0), fontSize: 12),
                            )
                          : Text(
                              s.shareCode,
                              key: const ValueKey('share'),
                              style: const TextStyle(
                                  color: Color(0xFF4B5563), fontSize: 12),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Players list ───────────────────────────────────────────
              Row(
                children: [
                  Text(
                    s.playersInRoom(players.length).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (!mpState.isHost)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(
                6,
                (i) => _PlayerSlot(
                  player: i < players.length ? players[i] : null,
                  seatIndex: i,
                  isLocal: i < players.length &&
                      players[i].playerId == mpState.localPlayerId,
                ),
              ),

              const Spacer(),

              // ── Action button ──────────────────────────────────────────
              if (mpState.isHost)
                Column(
                  children: [
                    if (players.length < 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          s.minPlayersNeeded,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canStart ? _startGame : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canStart
                              ? const Color(0xFF3A86FF)
                              : const Color(0xFF3A86FF).withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _starting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                s.startOnlineGame,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Text(
                    s.waitingForHost,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _copyCode() {
    final code = ref.read(multiplayerProvider).roomCode ?? '';
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  Future<void> _startGame() async {
    setState(() => _starting = true);
    await ref.read(multiplayerProvider.notifier).startGame();
    if (mounted) setState(() => _starting = false);
  }
}

// ── Per-seat slot ─────────────────────────────────────────────────────────────

class _PlayerSlot extends StatelessWidget {
  final RoomPlayer? player;
  final int seatIndex;
  final bool isLocal;

  const _PlayerSlot({this.player, required this.seatIndex, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    final isEmpty = player == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocal
              ? const Color(0xFF3A86FF)
              : isEmpty
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFF2A2A4A),
          width: isLocal ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isEmpty
                  ? const Color(0xFF0F1929)
                  : const Color(0xFF2A3A5A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isEmpty ? '${seatIndex + 1}' : _initial(player!.playerName),
                style: TextStyle(
                  color: isEmpty ? const Color(0xFF4B5563) : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEmpty ? '...' : player!.playerName,
              style: TextStyle(
                color: isEmpty ? const Color(0xFF2A2A4A) : Colors.white,
                fontSize: 14,
                fontWeight: isLocal ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isLocal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'YOU',
                style: TextStyle(
                  color: Color(0xFF3A86FF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';
}
