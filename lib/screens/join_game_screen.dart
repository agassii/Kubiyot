import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'online_lobby_screen.dart';

class JoinGameScreen extends ConsumerStatefulWidget {
  const JoinGameScreen({super.key});

  @override
  ConsumerState<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends ConsumerState<JoinGameScreen> {
  final _nameCtrl = TextEditingController(text: 'Player');
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _joining = true);
    await ref.read(multiplayerProvider.notifier).createRoom(name);
    if (!mounted) return;
    setState(() => _joining = false);
    final phase = ref.read(multiplayerProvider).phase;
    if (phase == MultiplayerPhase.inLobby) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
      );
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty || code.isEmpty) return;
    setState(() => _joining = true);
    await ref.read(multiplayerProvider.notifier).joinRoom(code, name);
    if (!mounted) return;
    setState(() => _joining = false);
    final phase = ref.read(multiplayerProvider).phase;
    if (phase == MultiplayerPhase.inLobby) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final mpState = ref.watch(multiplayerProvider);
    final isError = mpState.phase == MultiplayerPhase.error;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(s.modeOnline,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(s.yourName),
              const SizedBox(height: 10),
              _textField(controller: _nameCtrl, hint: s.yourName),
              const SizedBox(height: 32),

              if (isError) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    mpState.errorMessage ?? 'Error',
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Create room ───────────────────────────────────────────────
              _label(s.createRoom.toUpperCase()),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _joining ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(s.createRoom,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),

              // ── Divider ───────────────────────────────────────────────────
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFF2A2A4A))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR',
                      style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0)),
                ),
                const Expanded(child: Divider(color: Color(0xFF2A2A4A))),
              ]),
              const SizedBox(height: 32),

              // ── Join room ─────────────────────────────────────────────────
              _label(s.joinRoom.toUpperCase()),
              const SizedBox(height: 10),
              _textField(
                controller: _codeCtrl,
                hint: s.enterRoomCode,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _joining ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06D6A0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(s.joinRoom,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) =>
      TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF16213E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide:
                const BorderSide(color: Color(0xFF3A86FF), width: 2),
          ),
        ),
      );
}
