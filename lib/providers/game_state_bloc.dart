import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go/core/error_handling/app_error.dart';
import 'package:go/core/utils/system_utilities.dart';
import 'package:go/gameplay/middleware/score_calculation.dart';
import 'package:go/gameplay/middleware/stone_logic.dart';
import 'package:go/gameplay/stages/score_calculation_stage.dart';
import 'package:go/gameplay/stages/stage.dart';
import 'package:go/models/cluster.dart';
import 'package:go/models/game.dart';
import 'package:go/models/game_move.dart';
import 'package:go/models/position.dart';
import 'package:go/models/stone.dart';
import 'package:go/providers/signalr_bloc.dart';
import 'package:go/services/api.dart';
import 'package:go/services/app_user.dart';
import 'package:go/services/auth_provider.dart';
import 'package:go/services/edit_dead_stone_dto.dart';
import 'package:go/services/game_over_message.dart';
import 'package:go/services/move_position.dart';
import 'package:go/services/join_message.dart';
import 'package:go/services/signal_r_message.dart';
import 'package:go/utils/player.dart';
import 'package:ntp/ntp.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:timer_count_down/timer_controller.dart';

class GameStateBloc extends ChangeNotifier {
  final Api api;
  final AuthProvider authBloc;
  final SignalRProvider signalRbloc;
  final SystemUtilities systemUtilities;
  Game game;
  // Stage curStage;

  late final List<Player> _players;
  List<Player> get players => List.unmodifiable(_players);

  StoneType get myStone => game.players[authBloc.currentUserRaw.id]!;
  StoneType get otherStone => StoneType.values[1 - myStone.index];

  int get turn => game.moves.length;

  int get gametime => game.timeControl.mainTimeSeconds;

  Player get getPlayerWithTurn => _players[turn % 2];
  Player get getPlayerWithoutTurn => _players[turn % 2 == 0 ? 1 : 0];

  StoneType? get getWinnerStone => game.players[game.winnerId];
  StoneType? get getLoserStone => game.players[game.winnerId] == null
      ? null
      : StoneType.values[1 - game.players[game.winnerId]!.index];

  GameOverMethod? get getGameOverMethod => game.gameOverMethod;

  List<double> get getSummedPlayerScores => [
        game.finalTerritoryScores[0].toDouble() +
            game.prisoners[getPlayerIdFromStoneType(StoneType.black)]!,
        game.finalTerritoryScores[1].toDouble() +
            game.prisoners[getPlayerIdFromStoneType(StoneType.white)]! +
            game.komi,
      ];

  String getPlayerIdFromStoneType(StoneType stone) {
    return game.players.entries
        .firstWhere((element) => element.value == stone)
        .key;
  }

  bool iAccepted = false;

  // Join Data

  AppUser myPlayerUserInfo;
  PublicUserInfo? otherPlayerUserInfo;

  List<ValueNotifier<Duration>> times;

  final List<CountdownController> _controller = [
    CountdownController(autoStart: false),
    CountdownController(autoStart: false)
  ];

  List<CountdownController> get timerController => _controller;

  ValueNotifier<StageType> curStageTypeNotifier;
  StageType get curStageType => curStageTypeNotifier.value;
  set curStageType(StageType stage) {
    // cur_stage.disposeStage();
    curStageTypeNotifier.value = stage;
  }
  // Stream<bool> listenForGameEndRequest() {
  //   return signalRbloc.gameMessageController.stream
  //       .where((message) => message.placeholder is bool)
  //       .cast();
  // }

  late final List<StreamSubscription> subscriptions;
  late final Stream<GameJoinMessage> listenForGameJoin;
  late final Stream<bool> listenFromOpponentConfirmation;
  late final Stream<EditDeadStoneMessage> listenForEditDeadStone;
  late final Stream<NewMoveMessage> listenFromMove;
  late final Stream<GameOverMessage> listenFromGameOver;
  late final Stream<Null> listenFromAcceptScores;
  late final Stream<ContinueGameMessage> listenFromContinueGame;

  GameStateBloc(
    this.api,
    this.signalRbloc,
    this.authBloc,
    this.game,
    this.systemUtilities,
    // this.curStage,
    StageType curStageType,
    GameJoinMessage? joiningData,
  )   : times = [
          ValueNotifier(Duration(seconds: game.timeControl.mainTimeSeconds)),
          ValueNotifier(Duration(seconds: game.timeControl.mainTimeSeconds))
        ],
        curStageTypeNotifier = ValueNotifier(curStageType),
        myPlayerUserInfo = authBloc.currentUserRaw {
    setupGame(game, joiningData);
    setupStreams();
    subscriptions = [
      listenFromGameJoin(),
      listenForMove(),
      listenForContinueGame(),
      listenForAcceptScore(),
      listenForGameOver()
    ];
  }

  void setupGame(Game game, GameJoinMessage? joiningData) {
    _players = [Player(0), Player(1)];

    if (joiningData != null) {
      applyJoinMessage(joiningData);
    }
  }

  void setupStreams() {
    var gameMessageStream = signalRbloc.gameMessageStream;
    listenForGameJoin = gameMessageStream.asyncExpand((message) async* {
      if (message.type == SignalRMessageTypes.gameJoin) {
        yield message.data as GameJoinMessage;
      }
    });
    listenFromOpponentConfirmation =
        gameMessageStream.asyncExpand((message) async* {
      if (message.data is bool) {
        yield message.data as bool;
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
  }

  StreamSubscription listenFromGameJoin() {
    return listenForGameJoin.listen((message) {
      applyJoinMessage(message);
      debugPrint("Joined game BAHAHA");
      notifyListeners();
    });
  }

  void applyJoinMessage(GameJoinMessage joinMessage) {
    game = joinMessage.game;
    otherPlayerUserInfo = joinMessage.otherPlayerData;

    if (game.startTime != null && game.gameState == GameState.playing) {
      var now = systemUtilities.currentTime;
      setPlayerTimes();
      times[getPlayerWithTurn.turn].value =
          times[getPlayerWithTurn.turn].value -
              now.difference(
                game.playerTimeSnapshots[getPlayerWithTurn.turn]
                    .snapshotTimestamp,
              );
      startPausedTimerOfActivePlayer();
      curStageType = StageType.Gameplay;
    }
    if (GameState.scoreCalculation == game.gameState) {
      curStageType = StageType.ScoreCalculation;
    }
    if (game.gameState == GameState.ended) {
      curStageType = StageType.GameEnd;
    }
  }

  StreamSubscription listenForContinueGame() {
    return listenFromContinueGame.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.continueGame}::\n\t\t${message.toMap()}");
      applyContinue();
    });
    // signalRbloc.hubConnection.on('gameMove', (data) {});
  }

  StreamSubscription listenForMove() {
    return listenFromMove.listen((message) {
      final game = message.game;
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.newMove}::\n\t\t${message.toMap()}");
      // assert(data != null, "Game move data can't be null");
      applyMoveResult(game);
    });
    // signalRbloc.hubConnection.on('gameMove', (data) {});
  }

  StreamSubscription listenForAcceptScore() {
    return listenFromAcceptScores.listen((message) {
      debugPrint("Signal R said, ::${SignalRMessageTypes.acceptedScores}::");
    });
  }

  StreamSubscription listenForGameOver() {
    return listenFromGameOver.listen((message) {
      debugPrint(
          "Signal R said, ::${SignalRMessageTypes.gameOver}::\n\t\t${message.toMap()}");
      game = message.game;
      applyEndGame();
    });
  }

  Future<Either<AppError, GameMove>> playMove(
      Position? position, StoneLogic stoneLogic) async {
    bool canPlayMove = isMyTurn();
    if (position == null && canPlayMove) {
      canPlayMove = true;
    } else if (position != null && canPlayMove) {
      canPlayMove = (stoneLogic.stoneAt(position) == null) &&
          stoneLogic.checkInsertable(position, myStone);
    }

    if (!canPlayMove) {
      return left(AppError(message: "You can't play here"));
    }

    // If there is no stone at this position and this is users turn, place stone
    final move = MovePosition(
      // playedAt: value,
      x: position?.x,
      y: position?.y,
    );

    var token = authBloc.token!;

    if (!move.isPass()) {
      stoneLogic.handleStoneUpdate(position);
    }

    var updatedGame = await api.makeMove(
      move,
      token,
      game.gameId,
    );

    return updatedGame.fold((l) {
      debugPrint("Move failure ${l.message}");
      return left(AppError(message: l.message));
    }, (r) {
      if (r.result) {
        applyMoveResult(r.game);
        return right(game.moves.last);
      } else {
        return left(AppError(message: "Invalid move"));
      }
    });

    // var tmpMove = GameMove(time: DateTime.now(), x: moveDto.x, y: moveDto.y);
    // var tmpGame = game.copyWith(moves: [...game.moves, tmpMove]);

    // applyMoveResult(tmpGame);
  }

  void applyMoveResult(Game game) {
    this.game = game;

    setTurnTimerAfterMoveWasAdded();

    if (game.gameState == GameState.scoreCalculation) {
      curStageType = StageType.ScoreCalculation;
    }

    notifyListeners();
  }

  // void applyTimesOfDiscreteSections() {
  //   var times = [game.startTime!, ...game.moves.map((e) => e.time)];

  //   var firstPlayerDuration = Duration.zero;

  //   var firstPlayerArrangedTimes = times.take(times.length - times.length % 2);
  //   var firstPlayerTimesBeforeCorrespondingMoveMade = firstPlayerArrangedTimes
  //       .filterWithIndex((time, index) => index % 2 == 0)
  //       .toList();
  //   var firstPlayerMoveMadeTimes = firstPlayerArrangedTimes
  //       .filterWithIndex((time, index) => index % 2 == 1)
  //       .toList();

  //   for (int i = 0; i < (firstPlayerArrangedTimes.length / 2).floor(); i++) {
  //     firstPlayerDuration += firstPlayerMoveMadeTimes[i]
  //         .difference(firstPlayerTimesBeforeCorrespondingMoveMade[i]);
  //   }

  //   this.times[0].value = Duration(seconds: game.timeControl.mainTimeSeconds) -
  //       firstPlayerDuration;

  //   var secondPlayerDuration = Duration.zero;

  //   var secondPlayerArrangedTimes =
  //       times.skip(1).take(times.length - times.length % 2);
  //   var secondPlayerTimesBeforeCorrespondingMoveMade = secondPlayerArrangedTimes
  //       .filterWithIndex((time, index) => index % 2 == 0)
  //       .toList();
  //   var secondPlayerMoveMadeTimes = secondPlayerArrangedTimes
  //       .filterWithIndex((time, index) => index % 2 == 1)
  //       .toList();

  //   for (int i = 0; i < (secondPlayerArrangedTimes.length / 2).floor(); i++) {
  //     secondPlayerDuration += secondPlayerMoveMadeTimes[i]
  //         .difference(secondPlayerTimesBeforeCorrespondingMoveMade[i]);
  //   }

  //   this.times[1].value = Duration(seconds: game.timeControl.mainTimeSeconds) -
  //       secondPlayerDuration;

  //   // If game has ended, apply game end time to player with turn
  //   if (game.gameState == GameState.ended) {
  //     this.times[getPlayerWithTurn.turn].value -=
  //         game.endTime!.difference(times.last);
  //   }
  // }

  void setPlayerTimes() {
    times[0].value = Duration(
        milliseconds: game.playerTimeSnapshots[0].mainTimeMilliseconds);
    times[1].value = Duration(
        milliseconds: game.playerTimeSnapshots[1].mainTimeMilliseconds);
  }

  void setTurnTimerAfterMoveWasAdded() {
    int turn = this.turn;

    setPlayerTimes();

    var turnPlayerTimer = timerController[turn % 2];
    turnPlayerTimer.start();

    // applyTimesOfDiscreteSections();

    var nonTurnPlayerTimer = timerController[1 - turn % 2];
    nonTurnPlayerTimer.pause();

    // Also calculate the lag time and incorporate that for player with turn
    times[getPlayerWithTurn.turn].value -=
        systemUtilities.currentTime.difference(
      game.playerTimeSnapshots[getPlayerWithTurn.turn].snapshotTimestamp,
    );
  }

  String getPlayerIdFromTurn(int turn) {
    for (var e in game.players.entries) {
      if (e.value.index == turn) {
        return e.key;
      }
    }
    throw NotImplementedException();
  }

  void applyEndGame() {
    setPlayerTimes();

    curStageType = StageType.GameEnd;
    timerController[0].pause();
    timerController[1].pause();
    notifyListeners();
  }

  bool isMyTurn() {
    return game.players[authBloc.currentUserRaw.id]!.index == turn % 2;
  }

  bool hasPassedTwice() {
    var prev;
    bool hasPassedTwice = false;
    for (var i in (game.moves).reversed) {
      if (prev == null) {
        prev = i;
        continue;
      }

      if (i.isPass() && prev.isPass()) {
        hasPassedTwice = !hasPassedTwice;
      } else {
        break;
      }
    }
    return hasPassedTwice;
  }

  Future<Either<AppError, Game>> continueGame() async {
    return (await api.continueGame(authBloc.token!, game.gameId))
        .fold((l) => left(AppError.fromApiError(l)), (r) {
      game = r;
      applyContinue();
      return right(r);
    });
  }

  void applyContinue() {
    curStageType = StageType.Gameplay;
    startPausedTimerOfActivePlayer();
  }

  Future<void> acceptScores() async {
    if (iAccepted) return;
    final token = authBloc.token!;
    final gameId = game.gameId;
    final res = await api.acceptScores(token, gameId);

    res.fold((l) {
      debugPrint("Accept scores failed ${l.message}");
    }, (r) {
      game = r;
      if (game.gameOverMethod != null) {
        applyEndGame();
      }
    });
  }

  Future<Either<AppError, Game>> resignGame() async {
    return (await api.resignGame(authBloc.token!, game.gameId))
        .fold((l) => left(AppError.fromApiError(l)), (r) {
      game = r;
      applyEndGame();
      return right(r);
    });
  }

  void startPausedTimerOfActivePlayer() {
    timerController[getPlayerWithTurn.turn].start();
  }

  Set<Cluster> getRemovedClusters() {
    return {};
    // TODO: call api
  }

  Player getRemotePlayer() {
    final stone = game.players[(authBloc.currentUserRaw).id];
    // game.players.indexWhere((k) => k != (authBloc.currentUserRaw)!.id);
    if (stone == null) {
      if (authBloc.currentUserRaw.id == game.gameCreator) {
        return players[1 -
            (game.stoneSelectionType.index %
                2) /* for now just wrapping around */];
      }
      throw ("remote player not found");
    }
    return players[1 - stone.index];
  }

  Player getClientPlayer() {
    final stone = game.players[(authBloc.currentUserRaw).id];
    // final index =
    //     game.players.indexWhere((k) => k == (authBloc.currentUserRaw)!.id);
    if (stone == null) {
      if (authBloc.currentUserRaw.id == game.gameCreator) {
        return players[(game.stoneSelectionType.index %
            2) /* for now just wrapping around */];
      }
      throw ("client player not found");
    }
    return players[stone.index];
  }
}
