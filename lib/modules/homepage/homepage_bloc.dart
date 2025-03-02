// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';

import 'package:go/core/error_handling/app_error.dart';
import 'package:go/models/game.dart';
import 'package:go/modules/auth/signalr_bloc.dart';
import 'package:go/modules/gameplay/game_state/game_entrance_data.dart';
import 'package:go/services/api.dart';
import 'package:go/models/user_account.dart';
import 'package:go/modules/auth/auth_provider.dart';
import 'package:go/models/available_game.dart';
import 'package:go/models/game_join_dto.dart';
import 'package:go/models/ongoing_games.dart';
import 'package:go/models/signal_r_message.dart';

class HomepageBloc extends ChangeNotifier {
  List<UserAccount> otherActivePlayers = [];
  List<AvailableGame> availableGames = [];

  List<OnGoingGame> myGames = [];

  final Api api;
  final SignalRProvider signalRProvider;

  HomepageBloc({
    required this.signalRProvider,
    required this.authBloc,
    required this.api,  
  }) {
    listenForNewGame();
  }

  final AuthProvider authBloc;

  Future<Either<AppError, GameEntranceData>> joinGame(String gameId) async {
    var game = await api.joinGame(GameJoinDto(gameId: gameId));

    game.fold((l) {
      myGames.removeWhere((e) => e.game.gameId == gameId);
      availableGames.removeWhere((element) => element.game.gameId == gameId);
      notifyListeners();
    }, (r) {
      availableGames.removeWhere((element) => element.game.gameId == gameId);

      addNewGame(OnGoingGame(
        game: r.game,
        opposingPlayer: r.otherPlayerData,
      ));
    });
    return game;
  }

  Future<void> getAvailableGames() async {
    var game = await api.getAvailableGames();
    game.fold((e) {
      debugPrint("Couldn't get available games");
    }, (games) {
      availableGames.addAll(games.games);
      notifyListeners();
    });
  }

  Future<void> getMyGames() async {
    var game = await api.getMyGames();
    game.fold((e) {
      debugPrint("Couldn't get my games");
    }, (games) {
      myGames.addAll(games.games);
      notifyListeners();
    });
  }

  void listenForNewGame() {
    signalRProvider.userMessagesStream.listen((message) {
      if (message.type == SignalRMessageTypes.newGame) {
        debugPrint("New game was recieved");
        final newGameMessage = (message.data as NewGameCreatedMessage);
        if (newGameMessage.game.creatorInfo.id != authBloc.myId) {
          availableGames.add(newGameMessage.game);
        }
        notifyListeners();
      }
    });
  }

  void addNewGame(OnGoingGame g) {
    if (myGames.any((element) => element.game.gameId == g.game.gameId)) {
      return;
    }

    myGames.add(g);
    notifyListeners();
  }
}
