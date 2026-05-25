class RoomPlayer {
  final String playerId;
  final String playerName;
  final int seatIndex;
  final DateTime? lastSeen;

  const RoomPlayer({
    required this.playerId,
    required this.playerName,
    required this.seatIndex,
    this.lastSeen,
  });

  bool get isConnected {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inSeconds < 60;
  }

  static RoomPlayer fromMap(Map<String, dynamic> map) => RoomPlayer(
        playerId: map['player_id'] as String,
        playerName: map['player_name'] as String,
        seatIndex: map['seat_index'] as int,
        lastSeen: map['last_seen'] != null
            ? DateTime.tryParse(map['last_seen'] as String)
            : null,
      );
}
