import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go/playfield/game.dart';
import 'package:go/models/game_match.dart';
import 'package:share/share.dart';

import 'package:go/gameplay/middleware/game_data.dart';
import 'package:go/gameplay/middleware/multiplayer_data.dart';
class BackgroundScreenWithDialog extends StatelessWidget {
  @override
  final Widget child;
  BackgroundScreenWithDialog({required this.child});

  Widget build(BuildContext context) {
    return Positioned.fill(
        child: Container(
      child: FractionallySizedBox(
        widthFactor: 0.9,
        heightFactor: 0.6,
        child: Dialog(backgroundColor: Colors.blue, child: child),
      ),
      decoration: BoxDecoration(color: Colors.green),
    ));
  }
}

/// This reads match from database and assigns it to match if all conditions of entering game are met returns true;
Stream<bool> checkGameEnterable(BuildContext context, GameMatch match, StreamController<bool> controller) {
  if (match.isComplete()) {
    bool gameEnterable = false;
    var changeStream = MultiplayerData.of(context)?.getCurGameRef(match.id).child('uid').onValue.listen((event) {
      match.uid = GameMatch.uidFromJson(event.snapshot.value);
      if (match.bothPlayers.contains(null) == false) {
        // gameEnterable = true;
        controller.add(true);
      } else {
        // gameEnterable = false;
        controller.add(false);
      }
    });
  }
  return controller.stream;
}
