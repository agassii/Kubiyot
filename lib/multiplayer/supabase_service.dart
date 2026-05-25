import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'room_player.dart';

class SupabaseService {
  static SupabaseClient get _db => Supabase.instance.client;

  static String generateRoomCode() {
    // Avoids ambiguous chars O, I
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '0123456789';
    final r = Random();
    final prefix =
        List.generate(4, (_) => letters[r.nextInt(letters.length)]).join();
    final suffix =
        List.generate(4, (_) => digits[r.nextInt(digits.length)]).join();
    return '$prefix-$suffix';
  }

  static Future<({String roomId, String roomCode})> createRoom({
    required String hostId,
    required String hostName,
  }) async {
    String code = generateRoomCode();
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final room = await _db
            .from('rooms')
            .insert({'code': code, 'host_id': hostId, 'status': 'lobby'})
            .select('id')
            .single();
        final roomId = room['id'] as String;
        await _db.from('room_players').insert({
          'room_id': roomId,
          'player_id': hostId,
          'player_name': hostName,
          'seat_index': 0,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        });
        return (roomId: roomId, roomCode: code);
      } catch (_) {
        code = generateRoomCode();
      }
    }
    throw Exception('Failed to create room');
  }

  static Future<({String roomId, int seatIndex})> joinRoom({
    required String code,
    required String playerId,
    required String playerName,
  }) async {
    final rows = await _db
        .from('rooms')
        .select('id, status')
        .eq('code', code.toUpperCase())
        .limit(1);

    if ((rows as List).isEmpty) {
      throw Exception('Room not found');
    }
    final room = rows.first;
    if (room['status'] != 'lobby') {
      throw Exception('Game already started');
    }
    final roomId = room['id'] as String;

    final existing = await _db
        .from('room_players')
        .select('seat_index')
        .eq('room_id', roomId);
    final usedSeats =
        (existing as List).map((p) => p['seat_index'] as int).toSet();

    // Re-join if already in room
    if (usedSeats.isEmpty) {
      throw Exception('Room has no host');
    }
    // Check if player is already in room
    final alreadyIn = await _db
        .from('room_players')
        .select('seat_index')
        .eq('room_id', roomId)
        .eq('player_id', playerId)
        .limit(1);
    if ((alreadyIn as List).isNotEmpty) {
      return (
        roomId: roomId,
        seatIndex: alreadyIn.first['seat_index'] as int,
      );
    }

    int seatIndex = 1;
    while (usedSeats.contains(seatIndex)) {
      seatIndex++;
    }
    if (seatIndex >= 6) throw Exception('Room is full');

    await _db.from('room_players').insert({
      'room_id': roomId,
      'player_id': playerId,
      'player_name': playerName,
      'seat_index': seatIndex,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    });
    return (roomId: roomId, seatIndex: seatIndex);
  }

  static Future<List<RoomPlayer>> getRoomPlayers(String roomId) async {
    final data = await _db
        .from('room_players')
        .select()
        .eq('room_id', roomId)
        .order('seat_index');
    return (data as List)
        .map((p) => RoomPlayer.fromMap(p as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setRoomStatus(String roomId, String status) async {
    await _db.from('rooms').update({'status': status}).eq('id', roomId);
  }

  static Future<void> updateLastSeen({
    required String roomId,
    required String playerId,
  }) async {
    await _db.from('room_players').update({
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('room_id', roomId).eq('player_id', playerId);
  }

  static Future<bool> pushGameState({
    required String roomId,
    required String stateJson,
    required int version,
    required String updatedBy,
  }) async {
    try {
      await _db.from('game_state').upsert({
        'room_id': roomId,
        'state_json': stateJson,
        'version': version,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': updatedBy,
      }, onConflict: 'room_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteRoom(String roomId) async {
    try {
      await _db.from('rooms').delete().eq('id', roomId);
    } catch (_) {}
  }

  static String rawJsonToString(dynamic rawJson) =>
      rawJson is String ? rawJson : jsonEncode(rawJson);
}
