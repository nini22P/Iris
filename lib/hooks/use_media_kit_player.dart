import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/player.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

MediaKitPlayer useMediaKitPlayer(BuildContext context) {
  final player = useMemoized(
    () => Player(
      configuration: const PlayerConfiguration(
        libass: true,
      ),
    ),
  );

  final controller = useMemoized(() => VideoController(player));

  useEffect(() {
    () async {
      player.setSubtitleTrack(SubtitleTrack.no());

      if (Platform.isAndroid) {
        NativePlayer nativePlayer = player.platform as NativePlayer;

        final appSupportDir = await getApplicationSupportDirectory();
        final String fontsDir = "${appSupportDir.path}/fonts";

        final Directory fontsDirectory = Directory(fontsDir);
        if (!await fontsDirectory.exists()) {
          await fontsDirectory.create(recursive: true);
          logger('fonts directory created');
        }

        final File file = File("$fontsDir/NotoSansCJKsc-Medium.otf");
        if (!await file.exists()) {
          final ByteData data =
              await rootBundle.load("assets/fonts/NotoSansCJKsc-Medium.otf");
          final Uint8List buffer = data.buffer.asUint8List();
          await file.create(recursive: true);
          await file.writeAsBytes(buffer);
          logger('NotoSansCJKsc-Medium.otf copied');
        }

        await nativePlayer.setProperty("sub-fonts-dir", fontsDir);
        await nativePlayer.setProperty("sub-font", "NotoSansCJKsc-Medium");
      }
    }();
    return player.dispose;
  }, []);

  final List<PlayQueueItem> playQueue =
      usePlayQueueStore().select(context, (state) => state.playQueue);
  final int currentIndex =
      usePlayQueueStore().select(context, (state) => state.currentIndex);
  final bool autoPlay =
      useAppStore().select(context, (state) => state.autoPlay);
  final Repeat repeat = useAppStore().select(context, (state) => state.repeat);
  final bool alwaysPlayFromBeginning =
      useAppStore().select(context, (state) => state.alwaysPlayFromBeginning);

  final history = useHistoryStore().select(context, (state) => state.history);

  final int currentPlayIndex = useMemoized(
      () => playQueue.indexWhere((element) => element.index == currentIndex),
      [playQueue, currentIndex]);

  final FileItem? currentFile = useMemoized(
      () => playQueue.isEmpty || currentPlayIndex < 0
          ? null
          : playQueue[currentPlayIndex].file,
      [playQueue, currentPlayIndex]);

  ValueNotifier<bool> seeking = useState(false);

  bool playing = useStream(player.stream.playing).data ?? false;
  VideoParams? videoParams = useStream(player.stream.videoParams).data;
  // AudioParams? audioParams = useStream(player.stream.audioParams).data;
  ValueNotifier<Duration> position = useState(Duration.zero);
  Duration duration = useStream(player.stream.duration).data ?? Duration.zero;
  Duration buffer = useStream(player.stream.buffer).data ?? Duration.zero;
  bool completed = useStream(player.stream.completed).data ?? false;
  double rate = useStream(player.stream.rate).data ?? 1.0;

  Track? track = useStream(player.stream.track).data;
  AudioTrack audio =
      useMemoized(() => track?.audio ?? AudioTrack.no(), [track?.audio]);
  SubtitleTrack subtitle = useMemoized(
      () => track?.subtitle ?? SubtitleTrack.no(), [track?.subtitle]);

  Tracks? tracks = useStream(player.stream.tracks).data;
  List<AudioTrack> audios =
      useMemoized(() => (tracks?.audio ?? []), [tracks?.audio]);
  List<SubtitleTrack> subtitles = useMemoized(
      () => [...(tracks?.subtitle ?? [])]
        ..removeWhere((subtitle) => subtitle == SubtitleTrack.auto()),
      [tracks?.subtitle]);

  final List<Subtitle>? externalSubtitles = useMemoized(
      () => [...currentFile?.subtitles ?? []]..removeWhere(
          (subtitle) => subtitles.any((item) => item.title == subtitle.name)),
      [currentFile?.subtitles, subtitles]);

  final positionStream = useStream(player.stream.position);

  if (positionStream.hasData) {
    if (!seeking.value) {
      position.value = positionStream.data!;
    }
  }

  useEffect(() {
    if (currentFile == null || playQueue.isEmpty) {
      player.stop();
    } else {
      logger('Now playing: ${currentFile.uri}, auto play: $autoPlay');
      player.open(
        Media(currentFile.uri,
            httpHeaders: currentFile.auth != null
                ? {'authorization': currentFile.auth!}
                : {}),
        play: autoPlay,
      );
    }
    return () {
      if (currentFile != null && player.state.duration != Duration.zero) {
        if (Platform.isAndroid && currentFile.uri.startsWith('content://')) {
          return;
        }
        logger(
            'Save progress: ${currentFile.name}, position: ${player.state.position}, duration: ${player.state.duration}');
        useHistoryStore().add(Progress(
          dateTime: DateTime.now().toUtc(),
          position: player.state.position,
          duration: player.state.duration,
          file: currentFile,
        ));
      }
    };
  }, [currentFile]);

  useEffect(() {
    () async {
      if (duration == Duration.zero) {
        await player.setSubtitleTrack(SubtitleTrack.no());
        return;
      }
      // 查询播放进度
      if (currentFile != null && currentFile.type == ContentType.video) {
        Progress? progress = history[currentFile.getID()];
        if (progress != null) {
          if (!alwaysPlayFromBeginning &&
              (progress.duration.inMilliseconds -
                      progress.position.inMilliseconds) >
                  5000) {
            logger(
                'Resume progress: ${currentFile.name} position: ${progress.position} duration: ${progress.duration}');
            await player.seek(progress.position);
          }
        }
      }
      // 设置字幕
      if (externalSubtitles!.isNotEmpty) {
        logger('Set external subtitle: ${externalSubtitles[0].name}');
        await player.setSubtitleTrack(
          SubtitleTrack.uri(
            externalSubtitles[0].uri,
            title: externalSubtitles[0].name,
          ),
        );
      } else if (subtitles.length > 1) {
        logger(
            'Set subtitle: ${subtitles[1].title ?? subtitles[1].language ?? subtitles[1].id}');
        await player.setSubtitleTrack(subtitles[1]);
      } else {
        await player.setSubtitleTrack(SubtitleTrack.no());
      }
    }();
    return;
  }, [duration]);

  useEffect(() {
    () async {
      if (completed) {
        if (repeat == Repeat.one) return;
        if (currentPlayIndex == playQueue.length - 1) {
          if (repeat == Repeat.all) {
            await usePlayQueueStore().updateCurrentIndex(playQueue[0].index);
          }
        } else {
          await usePlayQueueStore()
              .updateCurrentIndex(playQueue[currentPlayIndex + 1].index);
        }
      }
    }();
    return null;
  }, [completed, repeat]);

  useEffect(() {
    logger('$repeat');
    if (repeat == Repeat.one) {
      player.setPlaylistMode(PlaylistMode.loop);
    } else {
      player.setPlaylistMode(PlaylistMode.none);
    }
    return;
  }, [repeat]);

  void updatePosition(Duration newPosition) => position.value = newPosition;

  void updateSeeking(bool value) => seeking.value = value;

  Future<void> saveProgress() async {
    if (currentFile != null && player.state.duration != Duration.zero) {
      if (Platform.isAndroid && currentFile.uri.startsWith('content://')) {
        return;
      }
      logger(
          'Save progress: ${currentFile.name}, position: ${player.state.position}, duration: ${player.state.duration}');
      useHistoryStore().add(Progress(
        dateTime: DateTime.now().toUtc(),
        position: player.state.position,
        duration: player.state.duration,
        file: currentFile,
      ));
    }
  }

  useEffect(() => saveProgress, []);

  Future<void> play() async {
    await useAppStore().updateAutoPlay(true);
    await player.play();
  }

  Future<void> pause() async {
    await useAppStore().updateAutoPlay(false);
    await player.pause();
  }

  Future<void> seekTo(Duration newPosition) async => newPosition.inSeconds < 0
      ? await player.seek(Duration.zero)
      : newPosition.inSeconds > duration.inSeconds
          ? await player.seek(duration)
          : await player.seek(newPosition);

  Future<void> backward(int seconds) async {
    await seekTo(Duration(seconds: position.value.inSeconds - seconds));
  }

  Future<void> forward(int seconds) async {
    await seekTo(Duration(seconds: position.value.inSeconds + seconds));
  }

  Future<void> updateRate(double value) async =>
      player.state.rate == value ? null : await player.setRate(value);

  return MediaKitPlayer(
    player: player,
    controller: controller,
    subtitle: subtitle,
    subtitles: subtitles,
    externalSubtitles: externalSubtitles ?? [],
    audio: audio,
    audios: audios,
    isPlaying: playing,
    position: duration == Duration.zero ? Duration.zero : position.value,
    duration: duration,
    buffer: duration == Duration.zero ? Duration.zero : buffer,
    seeking: seeking.value,
    rate: rate,
    aspect: videoParams?.aspect,
    width: videoParams?.w?.toDouble(),
    height: videoParams?.h?.toDouble(),
    updatePosition: updatePosition,
    updateSeeking: updateSeeking,
    saveProgress: saveProgress,
    play: play,
    pause: pause,
    backward: backward,
    forward: forward,
    updateRate: updateRate,
    seekTo: seekTo,
  );
}
