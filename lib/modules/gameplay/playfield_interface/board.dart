import 'package:go/constants/constants.dart' as Constants;
import 'package:flutter/material.dart';
import 'package:go/models/game.dart';
import 'stone_widget.dart';
import '../../../models/position.dart';

import 'cell.dart';

class Board extends StatefulWidget {
  late int rows, cols;
  Map<Position?, StoneWidget?> playgroundMap = {};

  Board(this.rows, this.cols, Map<Position, StoneType> stonePos, {super.key}) {
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        // playgroundMap[Position(i, j)] = Player(Colors.black);
        var tmpPos = Position(i, j);
        if (stonePos.keys.contains(tmpPos)) {
          final stoneType = stonePos[tmpPos]!;
          playgroundMap[Position(i, j)] = StoneWidget(
            stoneType == StoneType.black ? Colors.black : Colors.white,
            tmpPos,
          );
        } else {
          playgroundMap[Position(i, j)] = null;
        }
      }
    }
  }

  @override
  State<Board> createState() => _BoardState();
}

GlobalKey _boardKey = GlobalKey();

class _BoardState extends State<Board> {
  @override
  Widget build(BuildContext context) {
    double stoneInset = 10;
    double stoneSpacing =
        2; // Don't make spacing so large that to get that spacing Stones start to move out of position

    //double boardInset = stoneInsetstoneSpacing;
    return InteractiveViewer( 
      child: Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // return StatefulBuilder(
            //   builder: (BuildContext context, StateSetter setState) {
            //     print("${constraints.maxHeight}, ${constraints.maxWidth}");
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 5, right: 5, top: 5),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      //color: Colors.black,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                            image: AssetImage(Constants.assets['board']!),
                            fit: BoxFit.fill),
                      ),
                    ),
                  ),
                ),
                BorderGrid(GridInfo(constraints, stoneSpacing, widget.rows,
                    widget.cols, stoneInset)),
                StoneLayoutGrid(
                  GridInfo(constraints, stoneSpacing, widget.rows, widget.cols,
                      stoneInset,),
                ),
              ],
            );
          },
          //   ),
          // ),
          // );
          // },
        ),
      ),
    );
  }
}

class GridInfo {
  BoxConstraints constraints;
  double stoneSpacing;
  double stoneInset;
  int rows;
  int cols;
  GridInfo(this.constraints, this.stoneSpacing, this.rows, this.cols,
      this.stoneInset);
}

class BorderGrid extends StatelessWidget {
  GridInfo info;
  BorderGrid(this.info, {super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: /*EdgeInsets.all(0)*/ EdgeInsets.all(info.stoneInset +
          (((info.constraints.maxWidth / info.rows) / 2) - info.stoneSpacing)),
      itemCount: (info.rows - 1) * (info.cols - 1),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: (info.rows - 1),
          childAspectRatio: 1,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0),
      itemBuilder: (context, index) => Container(
        height: 10,
        width: 10,
        decoration: BoxDecoration(
            /*color: Colors.transparent,*/ border:
                Border.all(width: 0.1, color: Colors.black)),
      ),
    );
  }
}

class StoneLayoutGrid extends StatefulWidget {
  final GridInfo info;

  const StoneLayoutGrid(this.info, {super.key} /*, this.playgroundMap*/);
  @override
  State<StoneLayoutGrid> createState() => _StoneLayoutGridState();
}

class _StoneLayoutGridState extends State<StoneLayoutGrid> {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.all(widget.info.stoneInset),
      itemCount: (widget.info.rows) * (widget.info.cols),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (widget.info.rows),
        childAspectRatio: 1,
        crossAxisSpacing: widget.info.stoneSpacing,
        mainAxisSpacing: widget.info.stoneSpacing,
      ),
      itemBuilder: (context, index) => SizedBox(
        height: 10,
        width: 10,
        child: Stack(
          children: [
            Constants.boardCircleDecoration[
                        "${widget.info.rows}x${widget.info.rows}"]!
                    .contains(Position(((index) ~/ widget.info.cols),
                        ((index) % widget.info.rows).toInt()))
                ? Center(
                    child: FractionallySizedBox(
                      heightFactor: 0.3,
                      widthFactor: 0.3,
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Colors.black, shape: BoxShape.circle),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            Cell(Position(((index) ~/ widget.info.cols),
                ((index) % widget.info.rows).toInt())),
          ],
        ),
      ),
    );
  }
}
