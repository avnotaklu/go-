import 'package:flutter/material.dart';
import 'package:go/gameplay/middleware/game_data.dart';
import 'package:go/gameplay/stages/before_start_stage.dart';
import 'package:go/gameplay/stages/game_end_stage.dart';
import 'package:go/gameplay/stages/gameplay_stage.dart';
import 'package:go/gameplay/stages/score_calculation_stage.dart';
import 'package:go/playfield/stone_widget.dart';
import 'package:go/providers/game_state_bloc.dart';
import 'package:go/ui/gameui/game_ui.dart';
import 'package:go/models/position.dart';

enum StageType { BeforeStart, Gameplay, GameEnd, ScoreCalculation }

extension Constructor on StageType {
  Stage stageConstructor(BuildContext context, GameStateBloc gameStateBloc) => switch (this) {
        StageType.BeforeStart => BeforeStartStage(),
        StageType.Gameplay => GameplayStage(context),
        StageType.GameEnd => GameEndStage(gameStateBloc),
        StageType.ScoreCalculation => ScoreCalculationStage(),
      };
}

abstract class Stage extends ChangeNotifier {
  //<Derived extends Stage<Derived>> {
  // Derived child;
  Stage? get stage;
  Stage() {
    notifyListeners();
  }

  onClickCell(Position? position, BuildContext context);

  Widget drawCell(Position position, StoneWidget? stone, BuildContext context);

  disposeStage();

  List<Widget> buttons();

  void initializeWhenAllMiddlewareAvailable(BuildContext context);

  StageType get getType;
}
