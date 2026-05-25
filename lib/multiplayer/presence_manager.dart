import 'dart:async';
import 'supabase_service.dart';

class PresenceManager {
  Timer? _heartbeatTimer;
  Timer? _disconnectTimer;
  String? _roomId;
  String? _playerId;
  void Function(int seatIndex)? _onDisconnected;

  void start({
    required String roomId,
    required String playerId,
    required void Function(int seatIndex) onPlayerDisconnected,
  }) {
    _roomId = roomId;
    _playerId = playerId;
    _onDisconnected = onPlayerDisconnected;

    // Immediate first heartbeat
    SupabaseService.updateLastSeen(roomId: roomId, playerId: playerId);

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      SupabaseService.updateLastSeen(roomId: roomId, playerId: playerId);
    });

    _disconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDisconnections();
    });
  }

  Future<void> _checkDisconnections() async {
    if (_roomId == null || _playerId == null) return;
    try {
      final players = await SupabaseService.getRoomPlayers(_roomId!);
      final now = DateTime.now();
      for (final player in players) {
        if (player.playerId == _playerId) continue;
        if (player.lastSeen != null &&
            now.difference(player.lastSeen!).inSeconds > 60) {
          _onDisconnected?.call(player.seatIndex);
        }
      }
    } catch (_) {}
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _disconnectTimer?.cancel();
    _heartbeatTimer = null;
    _disconnectTimer = null;
  }
}
