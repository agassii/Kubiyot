// =============================================================================
// hive_service_test.dart
// Kubiyot — Tests for HiveService (save / load / clear)
//
// Hive is initialized with a temp directory so tests never touch the real DB.
// Run with: dart test test/hive_service_test.dart
// =============================================================================

import 'dart:io';
import 'package:test/test.dart';
import 'package:hive/hive.dart';
import '../lib/engine/game_manager.dart';
import '../lib/engine/turn_state_machine.dart';
import '../lib/services/hive_service.dart';

void main() {
  late Directory tempDir;
  late HiveService service;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kubiyot_hive_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    service = HiveService();
    await service.init();
  });

  tearDown(() async {
    await service.close();
    await Hive.deleteBoxFromDisk(HiveService.boxName);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  // ===========================================================================
  // HV — HiveService CRUD
  // ===========================================================================
  group('HV — HiveService', () {

    test('HV-01: loadGame returns null when nothing saved', () {
      expect(service.loadGame(), isNull);
    });

    test('HV-02: saveGame then loadGame restores equivalent state', () async {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);

      await service.saveGame(game);
      final loaded = service.loadGame();

      expect(loaded, isNotNull);
      expect(loaded!.gameId, game.gameId);
      expect(loaded.phase, GamePhase.inProgress);
      expect(loaded.players.length, 2);
      expect(loaded.players[0].displayName, 'Alice');
      expect(loaded.players[1].displayName, 'Bob');
      expect(loaded.activeTurn, isNotNull);
      expect(loaded.activeTurn!.phase, TurnPhase.waitingToRoll);
    });

    test('HV-03: second saveGame overwrites first', () async {
      final gm = GameManager();
      final game1 = gm.createGame(playerNames: ['Alice', 'Bob']);
      final game2 = gm.createGame(playerNames: ['Charlie', 'Dave']);

      await service.saveGame(game1);
      await service.saveGame(game2);
      final loaded = service.loadGame();

      expect(loaded!.players[0].displayName, 'Charlie');
      expect(loaded.players[1].displayName, 'Dave');
    });

    test('HV-04: clearGame then loadGame returns null', () async {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      await service.saveGame(game);
      await service.clearGame();

      expect(service.loadGame(), isNull);
    });

    test('HV-05: mid-turn state survives save/load cycle', () async {
      final gm = GameManager();
      final game = gm.createGame(playerNames: ['Alice', 'Bob']);
      gm.startGame(game);
      // Roll and select to get a specific turn state
      gm.processRoll(game: game, rolledFaces: [1, 1, 1, 2, 3]);
      gm.processSelection(game: game, selectedDiceIndices: [0, 1, 2]);

      await service.saveGame(game);
      final loaded = service.loadGame()!;

      expect(loaded.activeTurn!.temporaryScore, 1000);
      expect(loaded.activeTurn!.setAsideDice.length, 3);
      expect(loaded.activeTurn!.phase, TurnPhase.bankingDecision);

      // Loaded game must be functional — can bank successfully
      expect(() => gm.processBank(loaded), returnsNormally);
      expect(loaded.players[0].currentScore, 1000);
    });
  });
}
