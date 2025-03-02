import 'package:flutter_test/flutter_test.dart';
import 'package:go/constants/constants.dart';
import 'package:go/modules/gameplay/middleware/stone_logic.dart';
import 'package:go/models/game.dart';
import 'package:go/models/position.dart';
import 'package:go/modules/gameplay/middleware/board_utility/stone.dart';
import 'package:go/modules/gameplay/middleware/board_utility/board_utilities.dart';

void main() {
  List<List<int>> _5x5BasicBoard() {
    return [
      [0, 0, 0, 1, 0],
      [0, 0, 1, 1, 1],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ];
  }

  Map<String, StoneType> _5x5BasicBoardHighLevelRepr() {
    return {
      "0 3": StoneType.black,
      "1 3": StoneType.black,
      "2 3": StoneType.black,
      "1 2": StoneType.black,
      "1 4": StoneType.black
    };
  }

  List<List<int>> _5x5DeathBoard() {
    return [
      [0, 0, 2, 1, 0],
      [0, 2, 0, 2, 1],
      [0, 0, 2, 1, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ];
  }

  // Position from https://senseis.xmp.net/?Cycles
  List<List<int>> _3_move_cycle_6x6_DeathBoard() {
    return [
      [0, 1, 0, 2, 1, 0],
      [2, 1, 2, 2, 1, 0],
      [0, 2, 2, 1, 1, 0],
      [2, 2, 1, 0, 0, 0],
      [1, 1, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0],
    ];
  }

  bool _2DArrayEqual<T>(List<List<T>> array1, List<List<T>> array2) {
    if (array1.length != array2.length ||
        array1[0].length != array2[0].length) {
      return false;
    }

    for (var i = 0; i < array1.length; i++) {
      for (var j = 0; j < array1[0].length; j++) {
        if (array1[i][j] != array2[i][j]) {
          return false;
        }
      }
    }

    return true;
  }

  group('StoneLogic tests', () {
    test('TestGetClusters', () {
      var board = _5x5BasicBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(board);

      expect(clusters.length, equals(1));
      expect(clusters.first.data.length, equals(5));
      expect(clusters.first.freedoms, equals(6));
      expect(clusters.first.player, equals(0));
    });

    test('TestGetStones', () {
      var board = _5x5BasicBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(board);
      var stones = boardCons.getStones(clusters);

      expect(stones.length, equals(5));
    });

    test('TestAddition', () {
      var basicBoard = _5x5BasicBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(basicBoard);
      var stones = boardCons.getStones(clusters);
      var stoneLogic = StoneLogic.fromBoardState(
        BoardState.simplePositionalBoard(5, 5, stones),
      );

      var movePos = const Position(0, 4);
      var res = stoneLogic.handleStoneUpdate(
        movePos,
        StoneType.black,
      );

      expect(res.result, isTrue);
      expect(res.board.playgroundMap.containsKey(movePos), isTrue);
      expect(res.board.playgroundMap.length, equals(6));
      expect(res.board.playgroundMap[movePos]?.cluster.data.length, equals(6));
      expect(res.board.playgroundMap[movePos]?.cluster.freedoms, equals(5));
    });

    test('TestUnplayableDueToNoFreedoms', () {
      var board = _5x5BasicBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(board);
      var stones = boardCons.getStones(clusters);
      var stoneLogic = StoneLogic.fromBoardState(
          BoardState.simplePositionalBoard(5, 5, stones));

      var movePos = const Position(0, 4);
      var updateResult = stoneLogic.handleStoneUpdate(movePos, StoneType.white);

      expect(updateResult.result, isFalse);
      expect(updateResult.board.playgroundMap.containsKey(movePos), isFalse);
      expect(updateResult.board.playgroundMap.length, equals(5));
    });

    test('TestKillStone', () {
      var board = _5x5DeathBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(board);
      var stones = boardCons.getStones(clusters);
      var boardState = BoardState.simplePositionalBoard(5, 5, stones);
      var stoneLogic = StoneLogic.fromBoardState(boardState);

      var movePos = Position(1, 2);
      var killPosition = Position(1, 3);

      expect(boardState.playgroundMap.containsKey(killPosition), isTrue);
      expect(
          boardState.playgroundMap[killPosition]?.cluster.freedoms, equals(1));

      var updateResult = stoneLogic.handleStoneUpdate(movePos, StoneType.black);

      expect(updateResult.result, isTrue);
      expect(updateResult.board.playgroundMap.containsKey(movePos), isTrue);
      expect(
          updateResult.board.playgroundMap.containsKey(killPosition), isFalse);
      expect(updateResult.board.playgroundMap.length, equals(7));
    });

    test('TestKoInsert', () {
      var board = _5x5DeathBoard();
      var boardCons = BoardStateUtilities(5, 5);
      var clusters = boardCons.getClusters(board);
      var stones = boardCons.getStones(clusters);
      var boardState = BoardState.simplePositionalBoard(5, 5, stones);
      var stoneLogic = StoneLogic.fromBoardState(boardState);

      var movePos = Position(1, 2);
      var killPosition = Position(1, 3);

      var updateResult = stoneLogic.handleStoneUpdate(movePos, StoneType.black);

      expect(updateResult.result, isTrue);
      expect(updateResult.board.playgroundMap.containsKey(movePos), isTrue);
      expect(
          updateResult.board.playgroundMap.containsKey(killPosition), isFalse);

      var movePos2 = Position(1, 3);
      var killPosition2 = Position(1, 2);

      var updateResult2 =
          stoneLogic.handleStoneUpdate(movePos2, StoneType.white);

      expect(updateResult2.result, isFalse);
      expect(updateResult2.board.playgroundMap.containsKey(movePos2), isFalse);
      expect(
          updateResult2.board.playgroundMap.containsKey(killPosition2), isTrue);
    });

    test('Test Three Move Cycle', () {
      final pos = _3_move_cycle_6x6_DeathBoard();

      final boardCons = BoardStateUtilities(6, 6);
      const boardSize = BoardSizeData(6, 6);
      final clusters = boardCons.getClusters(pos);
      final stones = boardCons.getStones(clusters);
      final stoneLogic =
          StoneLogic.fromBoardState(BoardState.simplePositionalBoard(
        6,
        6,
        stones,
      ));

      final m1 = Position(0, 0);
      final m2 = Position(2, 0);
      final m3 = Position(1, 0);

      final r1 = stoneLogic.handleStoneUpdate(m1, StoneType.white);
      expect(r1.result, isTrue);

      final r2 = stoneLogic.handleStoneUpdate(m2, StoneType.black);
      expect(r2.result, isTrue);

      final lastValid = BoardState(
        rows: 6,
        cols: 6,
        playgroundMap: Map.from(r2.board.playgroundMap),
        prisoners: [],
      );

      final r3 = stoneLogic.handleStoneUpdate(
        m3,
        StoneType.white,
      );

      expect(r3.result, isFalse);

      expect(
        _2DArrayEqual(
          r3.board.playgroundMap
              .toHighLevelBoardRepresentation()
              .toLowLevelBoardRepresentation(boardSize),
          lastValid.playgroundMap
              .toHighLevelBoardRepresentation()
              .toLowLevelBoardRepresentation(boardSize),
        ),
        isTrue,
      );
    });
  });
}
