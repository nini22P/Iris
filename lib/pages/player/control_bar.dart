import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/hooks/use_player_controller.dart';
import 'package:iris/hooks/use_player_core.dart';
import 'package:iris/models/storages/local_storage.dart';
import 'package:iris/pages/player/subtitles_menu_button.dart';
import 'package:iris/pages/settings/settings.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/is_desktop.dart';
import 'package:iris/pages/player/play_queue.dart';
import 'package:iris/widgets/show_popup.dart';
import 'package:iris/pages/storages/storages.dart';
import 'package:window_manager/window_manager.dart';

String formatDurationToMinutes(Duration duration) {
  int totalMinutes = duration.inHours * 60 + duration.inMinutes.remainder(60);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(totalMinutes);
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "$twoDigitMinutes:$twoDigitSeconds";
}

class ControlBar extends HookWidget {
  const ControlBar({
    super.key,
    required this.playerCore,
    required this.playerController,
    required this.showControl,
  });

  final PlayerCore playerCore;
  final PlayerController playerController;
  final void Function() showControl;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final isFullScreen =
        useAppStore().select(context, (state) => state.isFullScreen);
    final playQueueLength =
        usePlayQueueStore().select(context, (state) => state.playQueue.length);
    final currentIndex =
        usePlayQueueStore().select(context, (state) => state.currentIndex);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
          ),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formatDurationToMinutes(playerCore.position),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            decoration: TextDecoration.none),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(222),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                              disabledThumbRadius: 6,
                              elevation: 0,
                              pressedElevation: 0,
                            ),
                            // overlayColor: iconColor?.withOpacity(0.25),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            activeTrackColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                            inactiveTrackColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: playerCore.duration.inSeconds.toDouble() == 0
                                ? 0
                                : playerCore.position.inSeconds.toDouble(),
                            min: 0,
                            max: playerCore.duration.inSeconds.toDouble(),
                            onChanged: (value) {
                              showControl();
                              playerCore.updateSeeking(true);
                              playerCore.updatePosition(
                                  Duration(seconds: value.toInt()));
                            },
                            onChangeEnd: (value) async {
                              playerCore.updatePosition(
                                  Duration(seconds: value.toInt()));
                              await playerCore.player
                                  .seek(Duration(seconds: value.toInt()));
                              playerCore.updateSeeking(false);
                            },
                          ),
                        ),
                      ),
                      Text(
                        formatDurationToMinutes(playerCore.duration),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            decoration: TextDecoration.none),
                      ),
                    ])),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Visibility(
                          visible: MediaQuery.of(context).size.width > 600,
                          child: IconButton(
                            tooltip: t.open_file,
                            icon: const Icon(Icons.file_open_rounded),
                            iconSize: 18,
                            onPressed: () async {
                              showControl();
                              await pickFile();
                              showControl();
                            },
                          ),
                        ),
                        // Visibility(
                        //   visible: MediaQuery.of(context).size.width > 600,
                        //   child: IconButton(
                        //     tooltip: t.open_link,
                        //     icon: const Icon(Icons.file_present_rounded),
                        //     iconSize: 18,
                        //     onPressed: () async {
                        //       showControl();
                        //       await pickFile();
                        //       showControl();
                        //     },
                        //   ),
                        // ),
                        IconButton(
                          tooltip: t.storages,
                          icon: const Icon(Icons.storage_rounded),
                          iconSize: 18,
                          onPressed: () async {
                            showControl();
                            await showPopup(
                              context: context,
                              child: const Storages(),
                              direction: PopupDirection.left,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Visibility(
                        visible: playQueueLength > 1,
                        child: IconButton(
                          tooltip: t.previous,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 32,
                          ),
                          onPressed: () {
                            showControl();
                            if (playQueueLength > 0 && currentIndex > 0) {
                              playerController.previous();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: playerCore.playing == true ? t.pause : t.play,
                        icon: Icon(
                          playerCore.playing == true
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 42,
                        ),
                        onPressed: () {
                          showControl();
                          if (playQueueLength > 0) {
                            if (playerCore.playing == true) {
                              playerController.pause();
                            } else {
                              if (isDesktop()) {
                                windowManager.setTitle(playerCore.title);
                              }
                              playerController.play();
                            }
                          }
                        },
                      ),
                      Visibility(
                        visible: playQueueLength > 1,
                        child: IconButton(
                          tooltip: t.next,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            size: 32,
                          ),
                          onPressed: () {
                            showControl();
                            if (playQueueLength > 0 &&
                                currentIndex < playQueueLength - 1) {
                              playerController.next();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: t.play_queue,
                          icon: const Icon(Icons.playlist_play_rounded),
                          onPressed: () async {
                            showControl();
                            await showPopup(
                              context: context,
                              child: const PlayQueue(),
                              direction: PopupDirection.right,
                            );
                          },
                        ),
                        Visibility(
                          visible: MediaQuery.of(context).size.width > 600,
                          child: SubtitlesMenuButton(playerCore: playerCore),
                        ),
                        Visibility(
                          visible: isDesktop() &&
                              MediaQuery.of(context).size.width > 600,
                          child: IconButton(
                            tooltip: isFullScreen
                                ? t.exit_fullscreen
                                : t.enter_fullscreen,
                            icon: Icon(
                              isFullScreen
                                  ? Icons.close_fullscreen_rounded
                                  : Icons.open_in_full_rounded,
                              size: 18,
                            ),
                            onPressed: () {
                              showControl();
                              useAppStore().toggleFullScreen();
                            },
                          ),
                        ),
                        Visibility(
                          visible: MediaQuery.of(context).size.width > 600,
                          child: IconButton(
                            tooltip: t.settings,
                            icon: const Icon(Icons.settings_rounded),
                            iconSize: 20,
                            onPressed: () async {
                              showControl();
                              await showPopup(
                                context: context,
                                child: const Settings(),
                                direction: PopupDirection.right,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
