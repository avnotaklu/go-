// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:math';

import 'package:barebones_timer/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go/gameplay/middleware/time_calculator.dart';
import 'package:go/models/time_control.dart';
import 'package:go/playfield/board_utilities.dart';
import 'package:ntp/ntp.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:timer_count_down/timer_controller.dart';

import 'package:go/core/error_handling/app_error.dart';
import 'package:go/core/utils/system_utilities.dart';
import 'package:go/gameplay/create/stone_selection_widget.dart';
import 'package:go/gameplay/middleware/score_calculation.dart';
import 'package:go/gameplay/middleware/stone_logic.dart';
import 'package:go/gameplay/stages/score_calculation_stage.dart';
import 'package:go/gameplay/stages/stage.dart';
import 'package:go/models/cluster.dart';
import 'package:go/models/game.dart';
import 'package:go/models/game_move.dart';
import 'package:go/models/position.dart';
import 'package:go/models/stone.dart';
import 'package:go/providers/game_state_bloc.dart';
import 'package:go/providers/signalr_bloc.dart';
import 'package:go/services/api.dart';
import 'package:go/services/app_user.dart';
import 'package:go/services/auth_provider.dart';
import 'package:go/services/edit_dead_stone_dto.dart';
import 'package:go/services/game_over_message.dart';
import 'package:go/services/join_message.dart';
import 'package:go/services/move_position.dart';
import 'package:go/services/public_user_info.dart';
import 'package:go/services/signal_r_message.dart';
import 'package:go/services/user_rating.dart';
import 'package:go/ui/gameui/game_timer.dart';
import 'package:go/utils/player.dart';

// HACK: `GameUpdate` object is a hack as signalR messages don't always give the full game state
extension GameExt on Game {
  GameUpdate toGameUpdate() {
    return GameUpdate(
      game: this,
      curPlayerTimeSnapshot: didStart()
          ? playerTimeSnapshots[
              getStoneFromPlayerId(getPlayerIdWithTurn()!)!.index]
          : null,
      playerWithTurn:
          didStart() ? getStoneFromPlayerId(getPlayerIdWithTurn()!) : null,
    );
  }
}

extension GameUpdateExt on GameUpdate {
  Game makeCopyFromOldGame(Game game) {
    // REVIEW: this works for now,
    // but it might have some nullability issues down the line.
    // e.g. if the new game updated some value to a null value, it would be ignored by `??` operator.
    // In this case the update won't be communicated.
    var newGame = Game(
      gameId: this.game?.gameId ?? game.gameId,
      rows: this.game?.rows ?? game.rows,
      columns: this.game?.columns ?? game.columns,
      timeControl: this.game?.timeControl ?? game.timeControl,
      playgroundMap: this.game?.playgroundMap ?? game.playgroundMap,
      moves: this.game?.moves ?? game.moves,
      players: this.game?.players ?? game.players,
      prisoners: this.game?.prisoners ?? game.prisoners,
      startTime: this.game?.startTime ?? game.startTime,
      koPositionInLastMove:
          this.game?.koPositionInLastMove ?? game.koPositionInLastMove,
      gameState: this.game?.gameState ?? game.gameState,
      deadStones: this.game?.deadStones ?? game.deadStones,
      winnerId: this.game?.winnerId ?? game.winnerId,
      komi: this.game?.komi ?? game.komi,
      finalTerritoryScores:
          this.game?.finalTerritoryScores ?? game.finalTerritoryScores,
      gameOverMethod: this.game?.gameOverMethod ?? game.gameOverMethod,
      endTime: this.game?.endTime ?? game.endTime,
      stoneSelectionType:
          this.game?.stoneSelectionType ?? game.stoneSelectionType,
      gameCreator: this.game?.gameCreator ?? game.gameCreator,
      playerTimeSnapshots:
          this.game?.playerTimeSnapshots ?? game.playerTimeSnapshots,
      playersRatings: this.game?.playersRatings ?? game.playersRatings,
      playersRatingsDiff:
          this.game?.playersRatingsDiff ?? game.playersRatingsDiff,
    );

    var tmpTimes = [...newGame.playerTimeSnapshots];

    if (playerWithTurn != null && curPlayerTimeSnapshot != null) {
      var idx = playerWithTurn!.index;
      tmpTimes[idx] = curPlayerTimeSnapshot!;
    }

    return newGame.copyWith(playerTimeSnapshots: tmpTimes);
  }
}

class GameUpdate {
  final Game? game;
  final PlayerTimeSnapshot? curPlayerTimeSnapshot;
  final StoneType? playerWithTurn;
  final Position? deadStonePosition;
  final DeadStoneState? deadStoneState;

  GameUpdate({
    this.game,
    this.curPlayerTimeSnapshot,
    this.playerWithTurn,
    this.deadStonePosition,
    this.deadStoneState,
  });

  get state => null;
}

abstract class GameInteractor {
  final StreamController<GameUpdate> gameUpdateC = StreamController.broadcast();
  Stream<GameUpdate> get gameUpdate => gameUpdateC.stream;

  DisplayablePlayerData myPlayerData(Game game);
  DisplayablePlayerData otherPlayerData(Game game);

  Future<Either<AppError, Game>> resignGame(Game game);
  Future<Either<AppError, Game>> acceptScores(Game game);
  Future<Either<AppError, Game>> continueGame(Game game);
  Future<Either<AppError, Game>> playMove(Game game, MovePosition move);

  bool isThisAccountsTurn(Game game);
  StoneType thisAccountStone(Game game);
}

class LiveGameInteractor extends GameInteractor {
  final Api api;
  final AuthProvider authBloc;
  final SignalRProvider signalRbloc;
  late final List<StreamSubscription> subscriptions;
  late final Stream<GameJoinMessage> listenForGameJoin;
  late final Stream<EditDeadStoneMessage> listenForEditDeadStone;
  late final Stream<NewMoveMessage> listenFromMove;
  late final Stream<GameOverMessage> listenFromGameOver;
  late final Stream<GameTimerUpdateMessage> listenFromGameTimerUpdate;
  late final Stream<Null> listenFromAcceptScores;
  late final Stream<ContinueGameMessage> listenFromContinueGame;

  void setupStreams() {
    var gameMessageStream = signalRbloc.gameMessageStream;
    listenForGameJoin = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.gameJoin) {
        yield message.data as GameJoinMessage;
      }
    });

    listenForEditDeadStone = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.editDeadStone) {
        yield message.data as EditDeadStoneMessage;
      }
    });
    listenFromMove = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.newMove) {
        yield message.data as NewMoveMessage;
      }
    });

    listenFromContinueGame = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.continueGame) {
        yield message.data as ContinueGameMessage;
      }
    });

    listenFromAcceptScores = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.acceptedScores) {
        yield message.data as Null;
      }
    });

    listenFromGameOver = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.gameOver) {
        yield message.data as GameOverMessage;
      }
    });

    listenFromGameTimerUpdate = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.gameTimerUpdate) {
        yield message.data as GameTimerUpdateMessage;
      }
    });
  }

  LiveGameInteractor({
    required this.api,
    required this.authBloc,
    required this.signalRbloc,
    GameJoinMessage? joiningData,
  }) {
    if (joiningData != null) {
      otherPlayerInfo = joiningData.otherPlayerData;
    }
    setupStreams();

    subscriptions = [
      listenFromGameJoin(),
      listenForMove(),
      listenForContinueGame(),
      listenForAcceptScore(),
      listenForGameOver(),
      listenForGameTimerUpdate()
    ];
  }

  StreamSubscription listenFromGameJoin() {
    return listenForGameJoin.listen((message) {
      otherPlayerInfo = message.otherPlayerData;
      gameUpdateC.add(message.game.toGameUpdate());
    });
  }

  StreamSubscription listenForContinueGame() {
    return listenFromContinueGame.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.continueGame}::\n\t\t${message.toMap()}");
      gameUpdateC.add(message.game.toGameUpdate());
    });
    // signalRbloc.hubConnection.on('gameMove', (data) {});
  }

  StreamSubscription listenForMove() {
    return listenFromMove.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.newMove}::\n\t\t${message.toMap()}");
      // assert(data != null, "Game move data can't be null");
      gameUpdateC.add(message.game.toGameUpdate());
    });
    // signalRbloc.hubConnection.on('gameMove', (data) {});
  }

  StreamSubscription listenForAcceptScore() {
    return listenFromAcceptScores.listen((message) {
      debugPrint("Signal R said, ::${SignalRMessageTypes.acceptedScores}::");
      // TODO: this event isn't transferred over to game state bloc as that does nothing with it
    });
  }

  StreamSubscription listenForGameOver() {
    return listenFromGameOver.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.gameOver}::\n\t\t${message.toMap()}");
      gameUpdateC.add(message.game.toGameUpdate());
    });
  }

  StreamSubscription listenForGameTimerUpdate() {
    return listenFromGameTimerUpdate.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.gameTimerUpdate}::\n\t\t${message.toMap()}");

      gameUpdateC.add(GameUpdate(
        curPlayerTimeSnapshot: message.currentPlayerTime,
        playerWithTurn: message.player,
      ));
    });
  }

  // TODO: listenForGameJoin + update otherPlayerInfo there

  late final PublicUserInfo? otherPlayerInfo;

  PublicUserInfo get myPlayerUserInfo => PublicUserInfo(
      id: authBloc.currentUserRaw!.id,
      email: authBloc.currentUserRaw!.email,
      rating: authBloc.currentUserRating);

  DisplayablePlayerData myPlayerData(Game game) {
    var publicInfo = myPlayerUserInfo;
    var rating = publicInfo.rating.getRatingForGame(game);
    StoneType? stone;

    if (game.didStart()) {
      stone = game.getStoneFromPlayerId(publicInfo.id);
    } else if (game.gameCreator == publicInfo.id) {
      stone = game.stoneSelectionType.type;
    }

    return DisplayablePlayerData(
      displayName: publicInfo.email,
      stoneType: stone,
      rating: rating,
    );
  }

  DisplayablePlayerData otherPlayerData(Game game) {
    var publicInfo = otherPlayerInfo;
    var rating = publicInfo?.rating.getRatingForGame(game);
    StoneType? stone;

    if (game.didStart()) {
      stone = game.getStoneFromPlayerId(publicInfo!.id);
    } else if (game.gameCreator == publicInfo?.id) {
      stone = game.stoneSelectionType.type;
    }

    return DisplayablePlayerData(
      displayName: publicInfo?.email,
      stoneType: stone,
      rating: rating,
    );
  }

  @override
  Future<Either<AppError, Game>> resignGame(Game game) async {
    return (await api.resignGame(authBloc.token!, game.gameId));
  }

  @override
  Future<Either<AppError, Game>> acceptScores(Game game) async {
    return (await api.acceptScores(authBloc.token!, game.gameId));
  }

  @override
  Future<Either<AppError, Game>> continueGame(Game game) async {
    return (await api.continueGame(authBloc.token!, game.gameId));
  }

  @override
  Future<Either<AppError, Game>> playMove(Game game, MovePosition move) async {
    // final sl = StoneLogic(game);

    // if (!move.isPass()) {
    //   sl.handleStoneUpdate(Position(move.x!, move.y!), thisAccountStone(game));
    // }

    return (await api.makeMove(move, authBloc.token!, game.gameId))
        .map((a) => a.game);
  }

  @override
  bool isThisAccountsTurn(Game game) {
    return game.getPlayerIdWithTurn() == authBloc.currentUserRaw.id;
  }

  @override
  StoneType thisAccountStone(Game game) {
    return game.getStoneFromPlayerId(authBloc.currentUserRaw.id)!;
  }
}

// This assumes the game is already started at time of creation
// This assumes the two player's ids are "bottom" and "top"

class FaceToFaceGameInteractor extends GameInteractor {
  final SystemUtilities systemUtilities;

  FaceToFaceGameInteractor(Game game, this.systemUtilities)
      : assert(game.didStart());

  String get myPlayerId => "bottom";
  String get otherPlayerId => "top";

  @override
  DisplayablePlayerData myPlayerData(Game game) {
    StoneType stone = game.getStoneFromPlayerId(myPlayerId)!;

    return DisplayablePlayerData(
      displayName: stone.color,
      stoneType: stone,
      rating: null, // No rating for face to face games
    );
  }

  @override
  DisplayablePlayerData otherPlayerData(Game game) {
    StoneType stone = game.getStoneFromPlayerId(otherPlayerId)!;

    return DisplayablePlayerData(
      displayName: stone.color,
      stoneType: stone,
      rating: null, // No rating for face to face games
    );
  }

  @override
  Future<Either<AppError, Game>> resignGame(Game game) async {
    throw NotImplementedException();
  }

  @override
  Future<Either<AppError, Game>> acceptScores(Game game) async {
    throw NotImplementedException();
  }

  @override
  Future<Either<AppError, Game>> continueGame(Game game) async {
    throw NotImplementedException();
  }

  @override
  Future<Either<AppError, Game>> playMove(Game game, MovePosition move) async {
    final gp = LocalGameplay(game, systemUtilities);
    var newGame = gp.playMove(move, thisAccountStone(game));
    return newGame;
  }

  @override
  bool isThisAccountsTurn(Game game) {
    return true;
  }

  @override
  StoneType thisAccountStone(Game game) {
    return game.getStoneFromPlayerId(game.getPlayerIdWithTurn()!)!;
  }
}

class LocalGameplay {
  final StoneLogic stoneLogic;
  final TimeCalculator timeCalculator;
  final SystemUtilities systemUtilities;
  final Game game;

  DateTime get now => systemUtilities.currentTime;

  LocalGameplay(this.game, this.systemUtilities)
      : stoneLogic = StoneLogic(game),
        timeCalculator = TimeCalculator();

  Either<AppError, Game> playMove(MovePosition move, StoneType stone) {
    if (!move.isPass()) {
      var res = stoneLogic.handleStoneUpdate(Position(move.x!, move.y!), stone);
      if (res.result) {
        return right(putMove(move, game, res.board, stone));
      } else {
        return left(AppError(message: "Couldn't play at position"));
      }
    } else {
      return right(putMove(move, game, null, stone));
    }
  }

  Game putMove(
      MovePosition move, Game game, BoardState? board, StoneType stone) {
    Game newGame = game;

    newGame.moves.add(GameMove(time: now, x: move.x, y: move.y));

    if (board != null) {
      newGame = game.buildWithNewBoardState(board);
    }

    var newTimes = timeCalculator.recalculateTurnPlayerTimeSnapshots(
      StoneType.values[1 - stone.index], // This is the actual current player
      newGame.playerTimeSnapshots,
      newGame.timeControl,
      now,
    );

    newGame = newGame.copyWith(playerTimeSnapshots: newTimes);

    return newGame;
  }
}

// This is for testing only

Game testGameConstructor() {
  var rows = 9;
  var cols = 9;
  var boardState = BoardStateUtilities(rows, cols);

  Position? koPosition;
  var startTime = systemUtils.currentTime;

  return Game(
    gameId: "Test",
    rows: rows,
    columns: cols,
    timeControl: blitz,
    playgroundMap: {},
    moves: [],
    players: {"bottom": StoneType.black, "top": StoneType.white},
    prisoners: [0, 0],
    startTime: startTime,
    koPositionInLastMove: koPosition,
    gameState: GameState.playing,
    deadStones: [],
    winnerId: null,
    komi: 6.5,
    finalTerritoryScores: [],
    endTime: null,
    gameOverMethod: null,
    playerTimeSnapshots: [
      blitz.getStartingSnapshot(startTime, true),
      blitz.getStartingSnapshot(startTime, false),
    ],
    gameCreator: null,
    stoneSelectionType: StoneSelectionType.auto,
    playersRatings: [],
    playersRatingsDiff: [],
  );
}
