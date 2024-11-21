import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/store/app_store.dart';
import 'package:iris/utils/is_desktop.dart';
import 'package:iris/widgets/title_bar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

class VideoPageArguments {
  final List<FileItem> playQueue;
  final int index;

  VideoPageArguments(this.playQueue, this.index);
}

class VideoPage extends HookWidget {
  const VideoPage({super.key, required this.playQueue, required this.index});

  final List<FileItem> playQueue;
  final int index;

  @override
  Widget build(BuildContext context) {
    final player = useMemoized(() => Player());
    final controller = useMemoized(() => VideoController(player));

    final position = useState(Duration.zero);
    final duration = useState(Duration.zero);
    final sliderisChanging = useState(false);
    final isPlaying = useState(false);
    final showControls = useState(false);
    final hideTimer = useRef<Timer?>(null);

    final positionStream = useStream(player.stream.position);
    final durationStream = useStream(player.stream.duration);
    final playlist = useStream(player.stream.playlist);

    final title = useMemoized(
        () => playlist.data != null && playlist.data!.index >= 0
            ? "[${playlist.data!.index + 1}/${playQueue.length}] ${playQueue[playlist.data!.index].name}"
            : '',
        [
          playlist.data?.index,
        ]);

    if (positionStream.hasData) {
      if (!sliderisChanging.value) {
        position.value = positionStream.data!;
      }
    }

    if (durationStream.hasData) {
      duration.value = durationStream.data!;
    }

    void startHideTimer() {
      hideTimer.value = Timer(const Duration(seconds: 5), () {
        if (showControls.value) {
          showControls.value = false;
        }
      });
    }

    void resetHideTimer() {
      hideTimer.value?.cancel();
      startHideTimer();
    }

    useEffect(() {
      startHideTimer();
      return () => hideTimer.value?.cancel();
    }, []);

    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      return () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }, []);

    useEffect(() {
      if (!showControls.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
      return null;
    }, [showControls.value]);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
      return () =>
          SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ));
    });

    useEffect(() {
      if (isDesktop()) {
        windowManager.setTitle(title);
      }
      return null;
    }, [title]);

    useEffect(() {
      if (!isPlaying.value) {
        final autoPlay =
            useAppStore().select(context, (state) => state.autoPlay);
        player.open(
          Playlist(
            playQueue
                .map((item) => item.path != null
                    ? Media(item.path!,
                        httpHeaders: item.auth!.isNotEmpty
                            ? {'authorization': item.auth!}
                            : {})
                    : Media(''))
                .toList(),
            index: index,
          ),
          play: autoPlay,
        );
        isPlaying.value = true;
      }
      return player.dispose;
    }, []);

    const bgColor = Colors.black45;
    const iconColor = Colors.white;
    const textColor = Colors.white;

    return Scaffold(
        body: MouseRegion(
      onEnter: (_) {
        showControls.value = true;
        resetHideTimer();
      },
      onExit: (_) {
        showControls.value = false;
      },
      onHover: (_) {
        showControls.value = true;
        resetHideTimer();
      },
      child: Stack(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: GestureDetector(
              onTap: () {
                isDesktop() && player.state.playing == true
                    ? player.pause()
                    : player.play();
                showControls.value = true;
                resetHideTimer();
              },
              onDoubleTap: () async => isDesktop()
                  ? await windowManager.isFullScreen() == true
                      ? windowManager.setFullScreen(false)
                      : windowManager.setFullScreen(true)
                  : player.state.playing == true
                      ? player.pause()
                      : player.play(),
              onPanUpdate: (_) {
                if (isDesktop()) windowManager.startDragging();
              },
              child: Video(
                controller: controller,
                controls: NoVideoControls,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: const TextStyle(
                      height: 1.6,
                      fontSize: 44.0,
                      letterSpacing: 0.0,
                      wordSpacing: 0.0,
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontWeight: FontWeight.normal,
                      backgroundColor: Color.fromARGB(0, 0, 0, 0),
                      shadows: [
                        Shadow(
                          color: Color.fromARGB(255, 0, 0, 0),
                          offset: Offset(2.0, 2.0),
                          blurRadius: 3.0,
                        ),
                      ]),
                  textAlign: TextAlign.center,
                  padding: EdgeInsets.fromLTRB(
                      0, 0, 0, showControls.value ? 128 : 24),
                ),
              ),
            ),
          ),
          if (showControls.value) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TitleBar(
                title: title,
                bgColor: bgColor,
                textColor: textColor,
                iconColor: iconColor,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                color: bgColor,
                // padding: const EdgeInsets.all(10),
                child: Column(children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white54,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: position.value.inSeconds.toDouble(),
                          min: 0,
                          max: duration.value.inSeconds.toDouble(),
                          onChanged: (value) {
                            sliderisChanging.value = true;
                            position.value = Duration(seconds: value.toInt());
                          },
                          onChangeEnd: (value) {
                            sliderisChanging.value = false;
                            position.value = Duration(seconds: value.toInt());
                            player.seek(Duration(seconds: value.toInt()));
                          },
                        )),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 0, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          position.value.toString().split('.')[0],
                          style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              decoration: TextDecoration.none),
                        ),
                        IconButton(
                            onPressed: () => player.previous(),
                            icon: const Icon(
                              Icons.skip_previous,
                              color: iconColor,
                              size: 32,
                            )),
                        IconButton(
                          icon: StreamBuilder(
                            stream: player.stream.playing,
                            builder: (context, playing) => Icon(
                              player.state.playing == true
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: iconColor,
                              size: 32,
                            ),
                          ),
                          onPressed: () => player.state.playing == true
                              ? player.pause()
                              : player.play(),
                        ),
                        IconButton(
                            onPressed: () => player.next(),
                            icon: const Icon(
                              Icons.skip_next,
                              color: iconColor,
                              size: 32,
                            )),
                        Text(
                          duration.value.toString().split('.')[0],
                          style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}
