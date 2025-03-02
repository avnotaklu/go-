import 'package:flutter/material.dart';
import 'package:go/constants/constants.dart';
import 'package:go/core/foundation/set.dart';
import 'package:go/core/utils/my_responsive_framework/extensions.dart';
import 'package:go/core/utils/theme_helpers/context_extensions.dart';
import 'package:go/modules/gameplay/game_state/game_entrance_data.dart';
import 'package:go/modules/gameplay/playfield_interface/game_widget.dart';
import 'package:go/modules/gameplay/game_state/oracle/game_state_oracle.dart';
import 'package:go/modules/auth/signalr_bloc.dart';
import 'package:go/modules/gameplay/playfield_interface/live_game_widget.dart';
import 'package:go/modules/homepage/game_card.dart';
import 'package:go/modules/homepage/homepage_bloc.dart';
import 'package:go/modules/stats/stats_repository.dart';
import 'package:go/services/api.dart';
import 'package:go/modules/auth/auth_provider.dart';
import 'package:go/models/signal_r_message.dart';
import 'package:go/models/time_control_dto.dart';
import 'package:go/models/find_match_dto.dart';
import 'package:go/modules/homepage/matchmaking_provider.dart';
import 'package:go/widgets/my_max_width_box.dart';
import 'package:go/widgets/primary_button.dart';
import 'package:go/widgets/selection_badge.dart';
import 'package:go/widgets/my_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:test/test.dart';

class MatchmakingPage extends StatefulWidget {
  const MatchmakingPage({super.key});

  @override
  State<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends State<MatchmakingPage> {
  @override
  void initState() {}

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MatchmakingProvider(
        context.read<SignalRProvider>(),
        context.read<HomepageBloc>(),
      ),
      builder: (context, child) => MyMaxWidthBox(
        maxWidth: context.tabletBreakPoint.end,
        child: Scaffold(
          // backgroundColor: Color(0xff111118),
          // backgroundColor: Colors.red,
          body: Consumer<MatchmakingProvider>(
            builder: (context, provider, child) => Padding(
              padding: const EdgeInsets.all(20.0),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Board Size', style: titleLargeStyle(context)),
                SizedBox(height: 6.0),
                Container(
                  width: double.infinity,
                  child: SegmentedButton(
                    multiSelectionEnabled: true,
                    segments: provider.allBoardSizes
                        .map(
                          (e) => ButtonSegment(
                            value: e,
                            icon: Icon(Icons.close),
                            label: Text(e.boardName),
                          ),
                        )
                        .toList(),
                    onSelectionChanged: (p0) {
                      final newElem = p0
                          .symmetricDifference(
                              provider.selectedBoardSizes.toSet())
                          .first;
                      provider.modifyBoardSize(newElem,
                          !provider.selectedBoardSizes.contains(newElem));
                    },
                    selected: provider.selectedBoardSizes.toSet(),
                  ),
                ),
        
                // SizedBox(
                //     height: MediaQuery.sizeOf(context).width * 0.15,
                //     child: Row(
                //         mainAxisSize: MainAxisSize.max,
                //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //         children: provider.allBoardSizes
                //             .map(
                //               (size) => Expanded(
                //                 child: Padding(
                //                   padding:
                //                       const EdgeInsets.symmetric(horizontal: 8.0),
                //                   child: boardSizeSelector(
                //                     size,
                //                     provider,
                //                   ),
                //                 ),
                //               ),
                //             )
                //             .toList())),
                SizedBox(height: 10),
                Text(
                  'Time Controls',
                  style: titleLargeStyle(context),
                ),
                SizedBox(height: 6.0),
        
                Container(
                  width: double.infinity,
                  child: SegmentedButton(
                    multiSelectionEnabled: true,
                    segments: provider.allTimeControls.indexed
                        .where((rec) => rec.$1 % 2 == 0)
                        .map((rec) => rec.$2)
                        .map(
                          (e) => ButtonSegment(
                            value: e,
                            icon: Icon(Icons.close),
                            label: Text(
                              e.repr(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                    onSelectionChanged: (p0) {
                      final newElem = p0
                          .symmetricDifference(
                              provider.selectedTimeControls.toSet())
                          .first;
                      provider.modifyTimeControl(newElem,
                          !provider.selectedTimeControls.contains(newElem));
                    },
                    selected: provider.selectedTimeControls.toSet(),
                  ),
                ),
                SizedBox(height: 10),
        
                Container(
                  width: double.infinity,
                  child: SegmentedButton(
                    multiSelectionEnabled: true,
                    segments: provider.allTimeControls.indexed
                        .where((rec) => rec.$1 % 2 == 1)
                        .map((rec) => rec.$2)
                        .map(
                          (e) => ButtonSegment(
                            value: e,
                            icon: Icon(Icons.close),
                            label: Text(
                              e.repr(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                    onSelectionChanged: (p0) {
                      final newElem = p0
                          .symmetricDifference(
                              provider.selectedTimeControls.toSet())
                          .first;
                      provider.modifyTimeControl(newElem,
                          !provider.selectedTimeControls.contains(newElem));
                    },
                    selected: provider.selectedTimeControls.toSet(),
                  ),
                ),
        
                // Column(
                //     mainAxisSize: MainAxisSize.max,
                //     children: provider.allTimeControls
                //         .map(
                //           (timeControl) => Container(
                //             height: MediaQuery.sizeOf(context).width * 0.15,
                //             padding: EdgeInsets.symmetric(
                //               vertical: 6.0,
                //               horizontal: 8.0,
                //             ),
                //             child: timeSelector(timeControl, provider),
                //           ),
                //         )
                //         .toList()),
        
                SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    FindButton(),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Text("Ongoing games", style: context.textTheme.headlineSmall),
                const SizedBox(height: 20),
                Expanded(
                  child: Consumer<HomepageBloc>(
                    builder: (context, homeBloc, child) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: homeBloc.myGames.length,
                        itemBuilder: (context, index) {
                          final game = homeBloc.myGames[index];
                          return GameCard(
                            game: game.game,
                            otherPlayerData: game.opposingPlayer,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget boardSizeSelector(
      MatchableBoardSizes size, MatchmakingProvider provider) {
    var selected = provider.selectedBoardSizes.contains(size);
    return SelectionBadge(
      onTap: (v) {
        provider.modifyBoardSize(size, !selected);
      },
      selected: selected,
      label: size.boardName,
      // Card(
      //   color: cardColor,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(5),
      //   ),
      //   child: Padding(
      //     padding: const EdgeInsets.only(right: 25.0, top: 5.0),
      //     child: SelectionBadge(
      //       selected: selected,
      //       child: Center(
      //         child: Text(size.boardName, style: pointTextStyle()),
      //       ),
      //     ),
      //   ),
      // ),
    );
  }

  Widget timeSelector(
      TimeControlDto timeControl, MatchmakingProvider provider) {
    var selected = provider.selectedTimeControls.contains(timeControl);
    return SelectionBadge(
      selected: selected,
      label: timeControl.repr(),
      onTap: (v) => provider.modifyTimeControl(timeControl, !selected),
    );
  }

  TextStyle? titleLargeStyle(BuildContext context) {
    return context.textTheme.titleLarge;
  }
}

class FindButton extends StatelessWidget {
  const FindButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchmakingProvider>(builder: (context, provider, child) {
      return provider.findingMatch
          ? IconButton(
              onPressed: () {
                provider.cancelFind();
              },
              icon: const Icon(Icons.close))
          : PrimaryButton(
              text: "Play",
              onPressed: () {
                provider.findMatch();

                context
                    .read<MatchmakingProvider>()
                    .onMatchmakingUpdated
                    .stream
                    .listen((event) {
                  if (context.mounted) {
                    final statRepo = context.read<IStatsRepository>();
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return LiveGameWidget(event.game,
                          GameEntranceData.fromJoinMessage(event), statRepo);
                    }));
                  }
                });
              });
    });
  }
}

