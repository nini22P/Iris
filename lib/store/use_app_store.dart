import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/store/persistent_store.dart';
import 'package:iris/globals.dart' as globals;
import 'package:iris/utils/check_content_type.dart';
import 'package:iris/utils/path_conv.dart';

class AppStore extends PersistentStore<AppState> {
  AppStore() : super(AppState());

  Future<void> updateAutoPlay(bool autoPlay) async =>
      set(state.copyWith(autoPlay: autoPlay));

  Future<void> updateShuffle(bool shuffle) async {
    set(state.copyWith(shuffle: shuffle));
    await save(state);
  }

  Future<void> updateRepeat(Repeat repeat) async {
    set(state.copyWith(repeat: repeat));
    await save(state);
  }

  Future<void> toggleRepeat() async {
    switch (state.repeat) {
      case Repeat.none:
        set(state.copyWith(repeat: Repeat.one));
        break;
      case Repeat.one:
        set(state.copyWith(repeat: Repeat.all));
        break;
      case Repeat.all:
        set(state.copyWith(repeat: Repeat.none));
        break;
    }
    await save(state);
  }

  Future<void> updateFit(BoxFit fit) async {
    set(state.copyWith(fit: fit));
    await save(state);
  }

  Future<void> toggleFit() async {
    switch (state.fit) {
      case BoxFit.contain:
        set(state.copyWith(fit: BoxFit.fill));
        break;
      case BoxFit.fill:
        set(state.copyWith(fit: BoxFit.cover));
        break;
      case BoxFit.cover:
        set(state.copyWith(fit: BoxFit.none));
        break;
      case BoxFit.none:
        set(state.copyWith(fit: BoxFit.contain));
        break;
      default:
        break;
    }
    await save(state);
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    set(state.copyWith(themeMode: themeMode));
    await save(state);
  }

  Future<void> updateLanguage(String language) async {
    set(state.copyWith(language: language));
    await save(state);
  }

  Future<void> toggleAutoResize() async {
    set(state.copyWith(autoResize: !state.autoResize));
    await save(state);
  }

  @override
  Future<AppState?> load() async {
    log('Loading AppState');
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      String? appState = await storage.read(key: 'app_state');

      if (appState != null) {
        return AppState.fromJson(json.decode(appState)).copyWith(
          autoPlay: false,
        );
      }
    } catch (e) {
      log('Error loading AppState: $e');
    }
    return null;
  }

  @override
  Future<void> save(AppState state) async {
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      await storage.write(key: 'app_state', value: json.encode(state.toJson()));
    } catch (e) {
      log('Error saving AppState: $e');
    }
  }
}

AppStore useAppStore() => create(() => AppStore());
