import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go/gameplay/logic.dart';
import 'package:go/ui/gameui/time_watch.dart';
import 'package:go/constants/constants.dart' as Constants;

class PlayerDataUi extends StatefulWidget {
  int player;
  @override
  State<PlayerDataUi> createState() => _PlayerDataUiState();
  PlayerDataUi({required pplayer}) : player = pplayer;
}

class _PlayerDataUiState extends State<PlayerDataUi> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.5),
            color: Constants.players[widget.player].mColor,
          ),
          child: Column(
            children: [
              GameData.of(context)?.match.uid[widget.player] == null
                  ? Center(child: CircularProgressIndicator())
                  : TimeWatch(
                      GameData.of(context)?.timerController[widget.player],
                      pplayer: widget.player,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
