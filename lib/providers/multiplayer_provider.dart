import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../multiplayer/room_player.dart';
import '../multiplayer/supabase_service.dart';
import '../multiplayer/realtime_sync.dart';
import '../multiplayer/presence_manager.dart';
import '../services/game_state_serializer.dart';
import 'game_provider.dart';

enum MultiplayerPhase { idle, connecting, inLobby, inGame, error }

class MultiplayerState {
  final MultiplayerPhase phase;
  final String localPlayerId;
  final String localPlayerName;
  final String? roomCode;
  final String? roomId;
  final bool isHost;
  final int localSeatIndex;
  final List<RoomPlayer> roomPlayers;
  final int syncVersion;
  final String? errorMessage;

  const MultiplayerState({
    this.phase = MultiplayerPhase.idle,
    this.localPlayerId = '',
    this.localPlayerName = '',
    this.roomCode,
    this.roomId,
    this.isHost = false,
    this.localSeatIndex = 0,
    this.roomPlayers = const [],
    this.syncVersion = 0,
    this.errorMessage,
  });

  bool get isActive =>
      phase != MultiplayerPhase.idle && phase != MultiplayerPhase.error;

  bool isLocalPlayerTurn(int currentPlayerIndex) {
    if (phase != MultiplayerPhase.inGame) return true;
    return localSeatIndex == currentPlayerIndex;
  }

  Set<int> get disconnectedSeatIndices => roomPlayers
      .where((p) => p.playerId != localPlayerId && !p.isConnected)
      .map((p) => p.seatIndex)
      .toSet();

  MultiplayerState copyWith({
    MultiplayerPhase? phase,
    String? localPlayerId,
    String? localPlayerName,
    String? roomCode,
    String? roomId,
    bool? isHost,
    int? localSeatIndex,
    List<RoomPlayer>? roomPlayers,
    int? syncVersion,
    String? errorMessage,
  }) =>
      MultiplayerState(
        phase: phase ?? this.phase,
        localPlayerId: localPlayerId ?? this.localPlayerId,
        localPlayerName: localPlayerName ?? this.localPlayerName,
        roomCode: roomCode ?? this.roomCode,
        roomId: roomId ?? this.roomId,
        isHost: isHost ?? this.isHost,
        localSeatIndex: localSeatIndex ?? this.localSeatIndex,
        roomPlayers: roomPlayers ?? this.roomPlayers,
        syncVersion: syncVersion ?? this.syncVersion,
        errorMessage: errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  final Ref _ref;
  final RealtimeSync _sync = RealtimeSync();
  final PresenceManager _presence = PresenceManager();

  MultiplayerNotifier(this._ref) : super(_loadInitialState());

  static MultiplayerState _loadInitialState() {
    final box = Hive.box('settings');
    var id = box.get('mp_player_id') as String?;
    if (id == null) {
      id = _generateId();
      box.put('mp_player_id', id);
    }
    return MultiplayerState(localPlayerId: id);
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> createRoom(String playerName) async {
    state = state.copyWith(
      phase: MultiplayerPhase.connecting,
      localPlayerName: playerName,
    );
    try {
      final result = await SupabaseService.createRoom(
        hostId: state.localPlayerId,
        hostName: playerName,
      );
      state = state.copyWith(
        phase: MultiplayerPhase.inLobby,
        roomId: result.roomId,
        roomCode: result.roomCode,
        isHost: true,
        localSeatIndex: 0,
        roomPlayers: [
          RoomPlayer(
            playerId: state.localPlayerId,
            playerName: playerName,
            seatIndex: 0,
            lastSeen: DateTime.now(),
          ),
        ],
        syncVersion: 0,
      );
      _startSync(result.roomId);
    } catch (e) {
      state = state.copyWith(
        phase: MultiplayerPhase.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> joinRoom(String code, String playerName) async {
    state = state.copyWith(
      phase: MultiplayerPhase.connecting,
      localPlayerName: playerName,
    );
    try {
      final result = await SupabaseService.joinRoom(
        code: code.trim().toUpperCase(),
        playerId: state.localPlayerId,
        playerName: playerName,
      );
      final players = await SupabaseService.getRoomPlayers(result.roomId);
      state = state.copyWith(
        phase: MultiplayerPhase.inLobby,
        roomId: result.roomId,
        roomCode: code.trim().toUpperCase(),
        isHost: false,
        localSeatIndex: result.seatIndex,
        roomPlayers: players,
        syncVersion: 0,
      );
      _startSync(result.roomId);
    } catch (e) {
      state = state.copyWith(
        phase: MultiplayerPhase.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> startGame() async {
    if (!state.isHost || state.roomPlayers.length < 2) return;

    final sorted = [...state.roomPlayers]
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    final names = sorted.map((p) => p.playerName).toList();

    final gameNotifier = _ref.read(gameProvider);
    gameNotifier.createGame(names);
    gameNotifier.startGame();

    final gameState = gameNotifier.state!;
    final stateJson = GameStateSerializer.encode(gameState);
    await SupabaseService.pushGameState(
      roomId: state.roomId!,
      stateJson: stateJson,
      version: 1,
      updatedBy: state.localPlayerId,
    );
    await SupabaseService.setRoomStatus(state.roomId!, 'playing');

    state = state.copyWith(phase: MultiplayerPhase.inGame, syncVersion: 1);
  }

  Future<void> pushState() async {
    final game = _ref.read(gameProvider).state;
    if (game == null || state.roomId == null) return;
    final stateJson = GameStateSerializer.encode(game);
    final newVersion = state.syncVersion + 1;
    final ok = await SupabaseService.pushGameState(
      roomId: state.roomId!,
      stateJson: stateJson,
      version: newVersion,
      updatedBy: state.localPlayerId,
    );
    if (ok) state = state.copyWith(syncVersion: newVersion);
  }

  void leave() {
    _sync.dispose();
    _presence.stop();
    final roomId = state.roomId;
    if (roomId != null && state.isHost) {
      SupabaseService.deleteRoom(roomId);
    }
    state = MultiplayerState(localPlayerId: state.localPlayerId);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _startSync(String roomId) {
    _sync.subscribeToPlayers(roomId, (players) {
      state = state.copyWith(roomPlayers: players);
    });
    _sync.subscribeToGameState(roomId, _onRemoteState);
    _presence.start(
      roomId: roomId,
      playerId: state.localPlayerId,
      onPlayerDisconnected: _onPlayerDisconnected,
    );
  }

  void _onRemoteState(String stateJson, int version, String updatedBy) {
    if (updatedBy == state.localPlayerId) return;
    if (version <= state.syncVersion) return;
    try {
      final gameState = GameStateSerializer.decode(stateJson);
      _ref.read(gameProvider).loadStateFromRemote(gameState);
      state = state.copyWith(
        syncVersion: version,
        phase: MultiplayerPhase.inGame,
      );
    } catch (_) {}
  }

  void _onPlayerDisconnected(int seatIndex) {
    if (!state.isHost) return;
    final game = _ref.read(gameProvider).state;
    if (game == null || game.isComplete) return;
    if (game.currentPlayerIndex != seatIndex) return;
    _ref.read(gameProvider).forceAdvanceTurn();
    pushState();
  }

  static String _generateId() {
    final r = Random();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void dispose() {
    _sync.dispose();
    _presence.stop();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final multiplayerProvider =
    StateNotifierProvider<MultiplayerNotifier, MultiplayerState>(
  (ref) => MultiplayerNotifier(ref),
);
