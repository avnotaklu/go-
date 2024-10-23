// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:go/models/cluster.dart';
import 'package:go/models/position.dart';
import 'package:go/playfield/stone_widget.dart';

class Stone {
  final Position position;
  final int player;
  final Cluster cluster;

  Stone({required this.position, required this.player, required this.cluster});

  Stone copyWith({
    Position? position,
    int? player,
    Cluster? cluster,
  }) {
    return Stone(
      position: position ?? this.position,
      player: player ?? this.player,
      cluster: cluster ?? this.cluster,
    );
  }
}
