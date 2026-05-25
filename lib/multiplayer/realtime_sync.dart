import 'package:supabase_flutter/supabase_flutter.dart';
import 'room_player.dart';
import 'supabase_service.dart';

class RealtimeSync {
  RealtimeChannel? _playersChannel;
  RealtimeChannel? _gameStateChannel;

  void subscribeToPlayers(
    String roomId,
    void Function(List<RoomPlayer>) onUpdate,
  ) {
    _playersChannel?.unsubscribe();
    _playersChannel = Supabase.instance.client
        .channel('room_players:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (_) async {
            final players = await SupabaseService.getRoomPlayers(roomId);
            onUpdate(players);
          },
        )
        .subscribe();
  }

  void subscribeToGameState(
    String roomId,
    void Function(String stateJson, int version, String updatedBy) onUpdate,
  ) {
    _gameStateChannel?.unsubscribe();
    _gameStateChannel = Supabase.instance.client
        .channel('game_state:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_state',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isEmpty) return;
            final stateJson = SupabaseService.rawJsonToString(rec['state_json']);
            final version = (rec['version'] as num).toInt();
            final updatedBy = (rec['updated_by'] as String?) ?? '';
            onUpdate(stateJson, version, updatedBy);
          },
        )
        .subscribe();
  }

  void dispose() {
    _playersChannel?.unsubscribe();
    _gameStateChannel?.unsubscribe();
    _playersChannel = null;
    _gameStateChannel = null;
  }
}
