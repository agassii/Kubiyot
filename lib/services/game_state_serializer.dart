// =============================================================================
// game_state_serializer.dart
// Kubiyot — GameState ↔ JSON serializer
//
// Pure Dart — zero Flutter/Hive dependencies.
// Converts the full GameState object tree to/from Map<String, dynamic>.
// The HiveService (or any other persistence layer) calls encode/decode.
// =============================================================================

import 'dart:convert';
import '../engine/game_manager.dart';
import '../engine/turn_state_machine.dart';
import '../engine/player_manager.dart';
import '../engine/scoring_calculator.dart';

class GameStateSerializer {
  // ── Public API ─────────────────────────────────────────────────────────────

  static String encode(GameState state) => jsonEncode(toMap(state));

  static GameState decode(String json) =>
      fromMap(jsonDecode(json) as Map<String, dynamic>);

  // ── GameState ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> toMap(GameState state) => {
        'gameId': state.gameId,
        'players': state.players.map(_playerToMap).toList(),
        'settings': _settingsToMap(state.settings),
        'phase': state.phase.name,
        'currentPlayerIndex': state.currentPlayerIndex,
        'activeTurn':
            state.activeTurn != null ? _turnStateToMap(state.activeTurn!) : null,
        'stealWindowOpen': state.stealWindowOpen,
        'pendingTheftContext': state.pendingTheftContext != null
            ? _theftContextToMap(state.pendingTheftContext!)
            : null,
        'winnerId': state.winnerId,
        'eventLog': state.eventLog.map(_scoreChangeResultToMap).toList(),
      };

  static GameState fromMap(Map<String, dynamic> map) => GameState(
        gameId: map['gameId'] as String,
        players: (map['players'] as List)
            .map((p) => _playerFromMap(p as Map<String, dynamic>))
            .toList(),
        settings: _settingsFromMap(map['settings'] as Map<String, dynamic>),
        phase: GamePhase.values.byName(map['phase'] as String),
        currentPlayerIndex: map['currentPlayerIndex'] as int,
        activeTurn: map['activeTurn'] != null
            ? _turnStateFromMap(map['activeTurn'] as Map<String, dynamic>)
            : null,
        stealWindowOpen: map['stealWindowOpen'] as bool,
        pendingTheftContext: map['pendingTheftContext'] != null
            ? _theftContextFromMap(
                map['pendingTheftContext'] as Map<String, dynamic>)
            : null,
        winnerId: map['winnerId'] as String?,
        eventLog: (map['eventLog'] as List)
            .map((e) => _scoreChangeResultFromMap(e as Map<String, dynamic>))
            .toList(),
      );

  // ── Player ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _playerToMap(Player p) => {
        'id': p.id,
        'displayName': p.displayName,
        'scoreTiers': p.scoreTiers.toList(),
        'consecutiveXCount': p.consecutiveXCount,
        'isEntered': p.isEntered,
      };

  static Player _playerFromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as String,
        displayName: map['displayName'] as String,
        scoreTiers: (map['scoreTiers'] as List).cast<int>(),
        consecutiveXCount: map['consecutiveXCount'] as int,
        isEntered: map['isEntered'] as bool,
      );

  // ── GameSettings ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _settingsToMap(GameSettings s) => {
        'winTarget': s.winTarget,
        'entryThreshold': s.entryThreshold,
        'hotDiceBonus': s.hotDiceBonus,
        'ceilingBustCountsAsX': s.ceilingBustCountsAsX,
      };

  static GameSettings _settingsFromMap(Map<String, dynamic> map) => GameSettings(
        winTarget: map['winTarget'] as int,
        entryThreshold: map['entryThreshold'] as int,
        hotDiceBonus: map['hotDiceBonus'] as int,
        ceilingBustCountsAsX: map['ceilingBustCountsAsX'] as bool,
      );

  // ── TurnState ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _turnStateToMap(TurnState t) => {
        'playerId': t.playerId,
        'isTheftTurn': t.isTheftTurn,
        'theftContext':
            t.theftContext != null ? _theftContextToMap(t.theftContext!) : null,
        'phase': t.phase.name,
        'currentRoll': t.currentRoll.map(_scoredDieToMap).toList(),
        'setAsideDice': t.setAsideDice.map(_scoredDieToMap).toList(),
        'temporaryScore': t.temporaryScore,
        'setAsideTriples': _triplesToList(t.setAsideTriples),
        'hotDiceCount': t.hotDiceCount,
        'rollNumber': t.rollNumber,
        'rollHistory': t.rollHistory.map(_scoringResultToMap).toList(),
        'endReason': t.endReason?.name,
        'finalBankedScore': t.finalBankedScore,
      };

  static TurnState _turnStateFromMap(Map<String, dynamic> map) {
    final theftCtxMap = map['theftContext'] as Map<String, dynamic>?;
    return TurnState(
      playerId: map['playerId'] as String,
      isTheftTurn: map['isTheftTurn'] as bool,
      theftContext: theftCtxMap != null ? _theftContextFromMap(theftCtxMap) : null,
      phase: TurnPhase.values.byName(map['phase'] as String),
      currentRoll: (map['currentRoll'] as List)
          .map((d) => _scoredDieFromMap(d as Map<String, dynamic>))
          .toList(),
      setAsideDice: (map['setAsideDice'] as List)
          .map((d) => _scoredDieFromMap(d as Map<String, dynamic>))
          .toList(),
      temporaryScore: map['temporaryScore'] as int,
      setAsideTriples: _triplesFromList(map['setAsideTriples'] as List),
      hotDiceCount: map['hotDiceCount'] as int,
      rollNumber: map['rollNumber'] as int,
      rollHistory: (map['rollHistory'] as List)
          .map((r) => _scoringResultFromMap(r as Map<String, dynamic>))
          .toList(),
      endReason: map['endReason'] != null
          ? TurnEndReason.values.byName(map['endReason'] as String)
          : null,
      finalBankedScore: map['finalBankedScore'] as int?,
    );
  }

  // ── TheftContext ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _theftContextToMap(TheftContext ctx) => {
        'inheritedScore': ctx.inheritedScore,
        'inheritedTriples': _triplesToList(ctx.inheritedTriples),
        'availableDiceCount': ctx.availableDiceCount,
      };

  static TheftContext _theftContextFromMap(Map<String, dynamic> map) =>
      TheftContext(
        inheritedScore: map['inheritedScore'] as int,
        inheritedTriples: _triplesFromList(map['inheritedTriples'] as List),
        availableDiceCount: map['availableDiceCount'] as int,
      );

  // ── ScoredDie ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _scoredDieToMap(ScoredDie d) => {
        'index': d.index,
        'faceValue': d.face.value,
      };

  static ScoredDie _scoredDieFromMap(Map<String, dynamic> map) => ScoredDie(
        index: map['index'] as int,
        face: DiceFace.fromInt(map['faceValue'] as int),
      );

  // ── Map<DiceFace, int> ───────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _triplesToList(Map<DiceFace, int> triples) =>
      triples.entries
          .map((e) => {'face': e.key.value, 'count': e.value})
          .toList();

  static Map<DiceFace, int> _triplesFromList(List<dynamic> list) => {
        for (final entry in list.cast<Map<String, dynamic>>())
          DiceFace.fromInt(entry['face'] as int): entry['count'] as int,
      };

  // ── ScoringResult ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _scoringResultToMap(ScoringResult r) => {
        'contributions': r.contributions.map(_contributionToMap).toList(),
        'scoringDice': r.scoringDice.map(_scoredDieToMap).toList(),
        'nonScoringDice': r.nonScoringDice.map(_scoredDieToMap).toList(),
        'rollPoints': r.rollPoints,
        'isFarkle': r.isFarkle,
        'isHotDice': r.isHotDice,
      };

  static ScoringResult _scoringResultFromMap(Map<String, dynamic> map) =>
      ScoringResult(
        contributions: (map['contributions'] as List)
            .map((c) => _contributionFromMap(c as Map<String, dynamic>))
            .toList(),
        scoringDice: (map['scoringDice'] as List)
            .map((d) => _scoredDieFromMap(d as Map<String, dynamic>))
            .toList(),
        nonScoringDice: (map['nonScoringDice'] as List)
            .map((d) => _scoredDieFromMap(d as Map<String, dynamic>))
            .toList(),
        rollPoints: map['rollPoints'] as int,
        isFarkle: map['isFarkle'] as bool,
        isHotDice: map['isHotDice'] as bool,
      );

  // ── ScoringContribution ──────────────────────────────────────────────────────

  static Map<String, dynamic> _contributionToMap(ScoringContribution c) => {
        'dice': c.dice.map(_scoredDieToMap).toList(),
        'pattern': c.pattern.name,
        'points': c.points,
      };

  static ScoringContribution _contributionFromMap(Map<String, dynamic> map) =>
      ScoringContribution(
        dice: (map['dice'] as List)
            .map((d) => _scoredDieFromMap(d as Map<String, dynamic>))
            .toList(),
        pattern: ScoringPattern.values.byName(map['pattern'] as String),
        points: map['points'] as int,
      );

  // ── ScoreChangeResult & PlayerEvent ─────────────────────────────────────────

  static Map<String, dynamic> _scoreChangeResultToMap(ScoreChangeResult r) => {
        'events': r.events.map(_playerEventToMap).toList(),
        'gameWon': r.gameWon,
        'winnerId': r.winnerId,
      };

  static ScoreChangeResult _scoreChangeResultFromMap(Map<String, dynamic> map) =>
      ScoreChangeResult(
        events: (map['events'] as List)
            .map((e) => _playerEventFromMap(e as Map<String, dynamic>))
            .toList(),
        gameWon: map['gameWon'] as bool,
        winnerId: map['winnerId'] as String?,
      );

  static Map<String, dynamic> _playerEventToMap(PlayerEvent e) => {
        'playerId': e.playerId,
        'type': e.type.name,
        'scoreBefore': e.scoreBefore,
        'scoreAfter': e.scoreAfter,
        'triggeredByPlayerId': e.triggeredByPlayerId,
      };

  static PlayerEvent _playerEventFromMap(Map<String, dynamic> map) =>
      PlayerEvent(
        playerId: map['playerId'] as String,
        type: PlayerEventType.values.byName(map['type'] as String),
        scoreBefore: map['scoreBefore'] as int,
        scoreAfter: map['scoreAfter'] as int,
        triggeredByPlayerId: map['triggeredByPlayerId'] as String?,
      );
}
