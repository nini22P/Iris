import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'package:iris/models/file.dart';
import 'package:iris/models/player.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';

FvpPlayer useFvpPlayer(BuildContext context) {
  final autoPlay = useAppStore().select(context, (state) => state.autoPlay);
  final repeat = useAppStore().select(context, (state) => state.repeat);
  final playQueue =
      usePlayQueueStore().select(context, (state) => state.playQueue);
  final currentIndex =
      usePlayQueueStore().select(context, (state) => state.currentIndex);
  final bool alwaysPlayFromBeginning =
      useAppStore().select(context, (state) => state.alwaysPlayFromBeginning);
  final history = useHistoryStore().select(context, (state) => state.history);
  final int currentPlayIndex = useMemoized(
      () => playQueue.indexWhere((element) => element.index == currentIndex),
      [playQueue, currentIndex]);

  final PlayQueueItem? currentPlay = useMemoized(
      () => playQueue.isEmpty || currentPlayIndex < 0
          ? null
          : playQueue[currentPlayIndex],
      [playQueue, currentPlayIndex]);
  final file = useMemoized(() => currentPlay?.file, [currentPlay]);

  final player = useMemoized(() => mdk.Player(), [file]);

  final mediaInfo = useState<mdk.MediaInfo?>(null);
  final Duration duration = useMemoized(
      () => Duration(milliseconds: mediaInfo.value?.duration ?? 0),
      [mediaInfo.value]);
  final position = useState(Duration.zero);
  final buffer = useState(Duration.zero);
  final rate = useState(1.0);
  final size = useState<Size?>(null);
  final isPlaying = useState(false);
  final isCompleted = useState(false);
  final looping =
      useMemoized(() => repeat == Repeat.one ? true : false, [repeat]);
  final seeking = useState(false);
  final externalSubtitle = useState<int?>(null);
  final List<Subtitle> externalSubtitles = useMemoized(
      () => currentPlay?.file.subtitles ?? [], [currentPlay?.file.subtitles]);
  final double aspect = useMemoized(
      () => size.value != null &&
              size.value?.height != 0 &&
              size.value?.width != 0
          ? size.value!.width / size.value!.height
          : 0,
      [size.value]);

  useEffect(() {
    try {
      () async {
        if (Platform.isAndroid) {
          player.setProperty('audio.renderer', 'AudioTrack');
        }
        player.setProperty('video.decoder', 'shader_resource=0');
        player.setProperty('avformat.strict', 'experimental');
        player.setProperty('avio.reconnect', '1');
        player.setProperty('avio.reconnect_delay_max', '7');
        player.setProperty('avio.protocol_whitelist',
            'file,rtmp,http,https,tls,rtp,tcp,udp,crypto,httpproxy,data,concatf,concat,subfile');
        player.setProperty('avformat.rtsp_transport', 'tcp');
        player.setProperty('buffer', '2000+100000');
        // player.setProperty('demux.buffer.ranges', '8');

        player.onMediaStatus((oldValue, newValue) {
          logger('onMediaStatus: $oldValue -> $newValue');
          return true;
        });

        player.onEvent((ev) async {
          logger('onEvent: ${ev.category} - ${ev.detail} - ${ev.error}');
          if (ev.category == 'metadata' && ev.error == 0) {
            mediaInfo.value = player.mediaInfo;
            size.value = await player.textureSize;
          }
        });

        player.onStateChanged((oldValue, newValue) {
          logger('onStateChanged: $oldValue -> $newValue');
          if (duration != Duration.zero &&
              oldValue == mdk.PlaybackState.playing &&
              newValue == mdk.PlaybackState.stopped) {
            isCompleted.value = true;
          }

          if (newValue == mdk.PlaybackState.playing) {
            isPlaying.value = true;
          } else {
            isPlaying.value = false;
          }
        });

        if (file != null) {
          if (file.auth != null) {
            player.setProperty(
                'avio.headers', 'authorization: ${file.auth}\r\n');
          }

          player.media = file.uri;
          player.loop = repeat == Repeat.one ? -1 : 0;

          final Progress? progress = history[file.getID()];

          if (!alwaysPlayFromBeginning &&
              file.type == ContentType.video &&
              progress != null &&
              (progress.duration.inMilliseconds -
                      progress.position.inMilliseconds) >
                  5000) {
            logger(
                'Resume progress: ${file.name} position: ${progress.position} duration: ${progress.duration}');
            await player.prepare(position: progress.position.inMilliseconds);
          } else {
            await player.prepare();
          }

          player.updateTexture();

          if (autoPlay) {
            player.state = mdk.PlaybackState.playing;
          }

          if (externalSubtitles.isNotEmpty) {
            externalSubtitle.value = 0;
            player.setMedia(externalSubtitles[0].uri, mdk.MediaType.subtitle);
          }

          mediaInfo.value = player.mediaInfo;
          size.value = await player.textureSize;
        }
      }();
    } catch (e) {
      logger(e.toString());
    }
    return () {
      mediaInfo.value = null;
      size.value = null;
      isPlaying.value = false;
      isCompleted.value = false;
      position.value = Duration.zero;
      buffer.value = Duration.zero;
      rate.value = 1.0;
      externalSubtitle.value = null;
      player.onMediaStatus(null);
      player.onEvent(null);
      player.onStateChanged(null);
      player.dispose();
    };
  }, [player]);

  Future<void> seekTo(Duration newPosition) async {
    logger('Seek to: $newPosition');
    if (duration == Duration.zero) return;
    if (player.state == mdk.PlaybackState.stopped) {
      player.state = mdk.PlaybackState.playing;
      player.state = mdk.PlaybackState.paused;
    }
    newPosition.inSeconds < 0
        ? await player.seek(position: 0)
        : newPosition.inSeconds > duration.inSeconds
            ? await player.seek(position: duration.inMilliseconds)
            : await player.seek(position: newPosition.inMilliseconds);
  }

  Future<void> play() async {
    await useAppStore().updateAutoPlay(true);
    if (player.state == mdk.PlaybackState.stopped) {
      await seekTo(Duration.zero);
    }
    player.state = mdk.PlaybackState.playing;
  }

  Future<void> pause() async {
    await useAppStore().updateAutoPlay(false);
    player.state = mdk.PlaybackState.paused;
  }

  useEffect(() {
    Timer? timer;
    timer = file == null || seeking.value || !isPlaying.value
        ? null
        : Timer.periodic(Duration(milliseconds: 500),
            (_) => position.value = Duration(milliseconds: player.position));
    return () => timer?.cancel();
  }, [player, seeking.value, isPlaying.value]);

  useEffect(() {
    Timer? timer;
    timer = file == null
        ? null
        : Timer.periodic(
            Duration(milliseconds: 500),
            (_) {
              buffer.value =
                  Duration(milliseconds: player.position + player.buffered());
              rate.value = player.playbackRate;
            },
          );
    return () => timer?.cancel();
  }, [player]);

  useEffect(() {
    () async {
      if (seeking.value) {
        await seekTo(Duration(milliseconds: position.value.inMilliseconds));
      }
    }();
    return;
  }, [position.value, seeking.value]);

  useEffect(() {
    () async {
      if (currentPlay != null &&
          isCompleted.value &&
          player.position != 0 &&
          player.mediaInfo.duration != 0) {
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
  }, [isCompleted.value]);

  useEffect(() {
    logger('Set looping: $looping');
    player.loop = (repeat == Repeat.one ? -1 : 0);
    return;
  }, [looping]);

  useEffect(() {
    return () {
      if (currentPlay != null && player.mediaInfo.duration != 0) {
        if (Platform.isAndroid &&
            currentPlay.file.uri.startsWith('content://')) {
          return;
        }
        logger(
            'Save progress: ${currentPlay.file.name}, position: ${Duration(milliseconds: player.position)}, duration: ${Duration(milliseconds: player.mediaInfo.duration)}');
        useHistoryStore().add(Progress(
          dateTime: DateTime.now().toUtc(),
          position: Duration(milliseconds: player.position),
          duration: Duration(milliseconds: player.mediaInfo.duration),
          file: currentPlay.file,
        ));
      }
    };
  }, [currentPlay?.file]);

  useEffect(() {
    if (isPlaying.value == true) {
      logger('Enable wakelock');
      WakelockPlus.enable();
    } else {
      logger('Disable wakelock');
      WakelockPlus.disable();
    }
    return;
  }, [isPlaying.value]);

  Future<void> saveProgress() async {
    if (file != null && player.mediaInfo.duration != 0) {
      if (Platform.isAndroid && file.uri.startsWith('content://')) {
        return;
      }
      logger(
          'Save progress: ${file.name}, position: ${Duration(milliseconds: player.position)}, duration: ${Duration(milliseconds: player.mediaInfo.duration)}');
      useHistoryStore().add(Progress(
        dateTime: DateTime.now().toUtc(),
        position: Duration(milliseconds: player.position),
        duration: Duration(milliseconds: player.mediaInfo.duration),
        file: file,
      ));
    }
  }

  useEffect(() => saveProgress, []);

  return FvpPlayer(
    player: player,
    isPlaying: isPlaying.value,
    externalSubtitle: externalSubtitle,
    externalSubtitles: externalSubtitles,
    position: duration == Duration.zero ? Duration.zero : position.value,
    duration: duration,
    buffer: duration == Duration.zero ? Duration.zero : buffer.value,
    aspect: aspect,
    width: size.value?.width ?? 0,
    height: size.value?.height ?? 0,
    rate: rate.value,
    play: play,
    pause: pause,
    backward: (seconds) =>
        seekTo(Duration(seconds: position.value.inSeconds - seconds)),
    forward: (seconds) =>
        seekTo(Duration(seconds: position.value.inSeconds + seconds)),
    updateRate: (value) async => player.playbackRate = value,
    seekTo: seekTo,
    saveProgress: saveProgress,
    seeking: seeking.value,
    updatePosition: (value) => position.value = value,
    updateSeeking: (value) => seeking.value = value,
  );
}
