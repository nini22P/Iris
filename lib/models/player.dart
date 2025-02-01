import 'package:flutter/material.dart';
import 'package:iris/models/file.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:fvp/mdk.dart' as fvp;

class MediaPlayer {
  final bool isPlaying;
  final List<Subtitle> externalSubtitles;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool seeking;
  final double rate;
  final double? aspect;
  final double? width;
  final double? height;
  final void Function(Duration) updatePosition;
  final void Function(bool) updateSeeking;
  final Future<void> Function() saveProgress;
  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function(int) backward;
  final Future<void> Function(int) forward;
  final Future<void> Function(double) updateRate;
  final Future<void> Function(Duration) seekTo;

  MediaPlayer({
    required this.isPlaying,
    required this.externalSubtitles,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.seeking,
    required this.rate,
    required this.aspect,
    required this.width,
    required this.height,
    required this.updatePosition,
    required this.updateSeeking,
    required this.saveProgress,
    required this.play,
    required this.pause,
    required this.backward,
    required this.forward,
    required this.updateRate,
    required this.seekTo,
  });
}

class MediaKitPlayer extends MediaPlayer {
  final media_kit.Player player;
  final media_kit_video.VideoController controller;
  final media_kit.SubtitleTrack subtitle;
  final List<media_kit.SubtitleTrack> subtitles;
  final media_kit.AudioTrack audio;
  final List<media_kit.AudioTrack> audios;

  MediaKitPlayer({
    required this.player,
    required this.controller,
    required this.subtitle,
    required this.subtitles,
    required super.externalSubtitles,
    required this.audio,
    required this.audios,
    required super.isPlaying,
    required super.position,
    required super.duration,
    required super.buffer,
    required super.seeking,
    required super.rate,
    required super.aspect,
    required super.width,
    required super.height,
    required super.updatePosition,
    required super.updateSeeking,
    required super.saveProgress,
    required super.play,
    required super.pause,
    required super.backward,
    required super.forward,
    required super.updateRate,
    required super.seekTo,
  });
}

class FvpPlayer extends MediaPlayer {
  final fvp.Player player;
  final ValueNotifier<int?> externalSubtitle;

  FvpPlayer({
    required this.player,
    required super.isPlaying,
    required this.externalSubtitle,
    required super.externalSubtitles,
    required super.position,
    required super.duration,
    required super.buffer,
    required super.seeking,
    required super.rate,
    required super.aspect,
    required super.width,
    required super.height,
    required super.updatePosition,
    required super.updateSeeking,
    required super.saveProgress,
    required super.play,
    required super.pause,
    required super.backward,
    required super.forward,
    required super.updateRate,
    required super.seekTo,
  });
}
