import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:fvp/fvp.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/player.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/check_data_source_type.dart';
import 'package:iris/utils/logger.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

FvpPlayer useFvpPlayer(BuildContext context) {
  final autoPlay = useAppStore().select(context, (state) => state.autoPlay);
  final volume = useAppStore().select(context, (state) => state.volume);
  final isMuted = useAppStore().select(context, (state) => state.isMuted);
  final repeat = useAppStore().select(context, (state) => state.repeat);
  final playQueue =
      usePlayQueueStore().select(context, (state) => state.playQueue);
  final currentIndex =
      usePlayQueueStore().select(context, (state) => state.currentIndex);
  final bool alwaysPlayFromBeginning =
      useAppStore().select(context, (state) => state.alwaysPlayFromBeginning);

  final history = useHistoryStore().select(context, (state) => state.history);

  final looping =
      useMemoized(() => repeat == Repeat.one ? true : false, [repeat]);

  final int currentPlayIndex = useMemoized(
      () => playQueue.indexWhere((element) => element.index == currentIndex),
      [playQueue, currentIndex]);

  final PlayQueueItem? currentPlay = useMemoized(
      () => playQueue.isEmpty || currentPlayIndex < 0
          ? null
          : playQueue[currentPlayIndex],
      [playQueue, currentPlayIndex]);

  final file = useMemoized(() => currentPlay?.file, [currentPlay]);

  final externalSubtitle = useState<int?>(null);

  final List<Subtitle> externalSubtitles = useMemoized(
      () => currentPlay?.file.subtitles ?? [], [currentPlay?.file.subtitles]);

  final controller = useMemoized(() {
    if (file == null) return VideoPlayerController.networkUrl(Uri.parse(''));
    switch (checkDataSourceType(file)) {
      case DataSourceType.network:
        return VideoPlayerController.networkUrl(
          Uri.parse(file.uri),
          httpHeaders: file.auth != null ? {'authorization': file.auth!} : {},
        );
      case DataSourceType.file:
        return VideoPlayerController.file(
          File(file.uri),
          httpHeaders: file.auth != null ? {'authorization': file.auth!} : {},
        );
      case DataSourceType.contentUri:
        return VideoPlayerController.contentUri(
          Uri.parse(file.uri),
        );
      default:
        return VideoPlayerController.networkUrl(
          Uri.parse(file.uri),
          httpHeaders: file.auth != null ? {'authorization': file.auth!} : {},
        );
    }
  }, [file]);

  useEffect(() {
    () async {
      if (controller.dataSource.isEmpty) return;
      await controller.initialize();
      await controller.setLooping(repeat == Repeat.one ? true : false);
      await controller.setVolume(isMuted ? 0 : volume / 100);
    }();

    return () {
      controller.dispose();
      externalSubtitle.value = null;
    };
  }, [controller]);

  useEffect(() => controller.dispose, []);

  final isPlaying =
      useListenableSelector(controller, () => controller.value.isPlaying);
  final duration =
      useListenableSelector(controller, () => controller.value.duration);
  final position =
      useListenableSelector(controller, () => controller.value.position);
  final buffered =
      useListenableSelector(controller, () => controller.value.buffered);
  final playbackSpeed =
      useListenableSelector(controller, () => controller.value.playbackSpeed);
  final size = useListenableSelector(controller, () => controller.value.size);
  final isCompleted =
      useListenableSelector(controller, () => controller.value.isCompleted);

  final double aspect = useMemoized(
      () => size.width != 0 && size.height != 0 ? size.width / size.height : 0,
      [size.width, size.height]);

  final seeking = useState(false);

  useEffect(() {
    () async {
      if (duration != Duration.zero &&
          currentPlay != null &&
          currentPlay.file.type == ContentType.video) {
        Progress? progress = history[currentPlay.file.getID()];
        if (progress != null) {
          if (!alwaysPlayFromBeginning &&
              (progress.duration.inMilliseconds -
                      progress.position.inMilliseconds) >
                  5000) {
            logger(
                'Resume progress: ${currentPlay.file.name} position: ${progress.position} duration: ${progress.duration}');
            await controller.seekTo(progress.position);
          }
        }
      }

      if (autoPlay) {
        controller.play();
      }

      if (externalSubtitles.isNotEmpty) {
        externalSubtitle.value = 0;
      }
    }();
    return;
  }, [duration]);

  useEffect(() {
    if (externalSubtitle.value == null || externalSubtitles.isEmpty) {
      controller.setExternalSubtitle('');
    } else if (externalSubtitle.value! < externalSubtitles.length) {
      controller
          .setExternalSubtitle(externalSubtitles[externalSubtitle.value!].uri);
    }
    return;
  }, [externalSubtitles, externalSubtitle.value]);

  useEffect(() {
    () async {
      if (currentPlay != null &&
          isCompleted &&
          controller.value.position != Duration.zero &&
          controller.value.duration != Duration.zero) {
        logger('Completed: ${currentPlay.file.name}');
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
    return;
  }, [isCompleted]);

  useEffect(() {
    if (controller.value.isInitialized) {
      controller.setVolume(isMuted ? 0 : volume / 100);
    }
    return;
  }, [volume, isMuted]);

  useEffect(() {
    if (controller.value.isInitialized) {
      logger('Set looping: $looping');
      controller.setLooping(repeat == Repeat.one ? true : false);
    }
    return;
  }, [looping]);

  useEffect(() {
    return () {
      if (currentPlay != null &&
          controller.value.isInitialized &&
          controller.value.duration.inSeconds != 0) {
        if (Platform.isAndroid &&
            currentPlay.file.uri.startsWith('content://')) {
          return;
        }
        logger(
            'Save progress: ${currentPlay.file.name}, position: ${controller.value.position}, duration: ${controller.value.duration}');
        useHistoryStore().add(Progress(
          dateTime: DateTime.now().toUtc(),
          position: controller.value.position,
          duration: controller.value.duration,
          file: currentPlay.file,
        ));
      }
    };
  }, [currentPlay?.file]);

  useEffect(() {
    if (isPlaying) {
      logger('Enable wakelock');
      WakelockPlus.enable();
    } else {
      logger('Disable wakelock');
      WakelockPlus.disable();
    }
    return;
  }, [isPlaying]);

  Future<void> play() async {
    await useAppStore().updateAutoPlay(true);
    controller.play();
  }

  Future<void> pause() async {
    await useAppStore().updateAutoPlay(false);
    controller.pause();
  }

  Future<void> seekTo(Duration newPosition) async {
    logger('Seek to: $newPosition');
    if (duration == Duration.zero) return;
    newPosition.inSeconds < 0
        ? await controller.seekTo(Duration.zero)
        : newPosition.inSeconds > duration.inSeconds
            ? await controller.seekTo(duration)
            : await controller.seekTo(newPosition);
  }

  Future<void> saveProgress() async {
    if (file != null && duration != Duration.zero) {
      if (Platform.isAndroid && file.uri.startsWith('content://')) {
        return;
      }
      logger(
          'Save progress: ${file.name}, position: $position, duration: $duration');
      useHistoryStore().add(Progress(
        dateTime: DateTime.now().toUtc(),
        position: position,
        duration: duration,
        file: file,
      ));
    }
  }

  useEffect(() => saveProgress, []);

  return FvpPlayer(
    controller: controller,
    isPlaying: isPlaying,
    externalSubtitle: externalSubtitle,
    externalSubtitles: externalSubtitles,
    position: duration == Duration.zero ? Duration.zero : position,
    duration: duration,
    buffer: buffered.isEmpty || duration == Duration.zero
        ? Duration.zero
        : buffered.reduce((max, curr) => curr.end > max.end ? curr : max).end,
    aspect: aspect,
    width: size.width,
    height: size.height,
    rate: playbackSpeed,
    play: play,
    pause: pause,
    backward: (seconds) =>
        seekTo(Duration(seconds: position.inSeconds - seconds)),
    forward: (seconds) =>
        seekTo(Duration(seconds: position.inSeconds + seconds)),
    updateRate: (value) => controller.setPlaybackSpeed(value),
    seekTo: seekTo,
    saveProgress: saveProgress,
    seeking: seeking.value,
    updatePosition: seekTo,
    updateSeeking: (value) => seeking.value = value,
  );
}
