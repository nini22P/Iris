import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_state.freezed.dart';
part 'app_state.g.dart';

enum PlayerBackend {
  mediaKit,
  fvp,
}

enum Repeat {
  none,
  all,
  one,
}

enum SortBy {
  name,
  size,
  lastModified,
}

enum SortOrder {
  asc,
  desc,
}

@freezed
class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool autoPlay,
    @Default(false) bool shuffle,
    @Default(Repeat.none) Repeat repeat,
    @Default(BoxFit.contain) BoxFit fit,
    @Default(100) int volume,
    @Default(false) bool isMuted,
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default('none') String preferedSubtitleLanguage,
    @Default('system') String language,
    @Default(false) bool autoCheckUpdate,
    @Default(false) bool autoResize,
    @Default(false) bool alwaysPlayFromBeginning,
    @Default(PlayerBackend.mediaKit) PlayerBackend playerBackend,
    @Default(SortBy.name) SortBy sortBy,
    @Default(SortOrder.asc) SortOrder sortOrder,
    @Default(true) bool folderFirst,
  }) = _AppState;

  factory AppState.fromJson(Map<String, dynamic> json) =>
      _$AppStateFromJson(json);
}
