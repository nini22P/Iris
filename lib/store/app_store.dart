import 'dart:convert';
import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/app_state.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/store/persistent_store.dart';

class AppStore extends PersistentStore<AppState> {
  AppStore() : super(AppState());

  Future<void> addStorage(Storage storage) async {
    set(state.copyWith(storages: [...state.storages, storage]));
    save(state);
  }

  Future<void> updateStorage(int index, Storage storage) async {
    if (index < 0 || index >= state.storages.length) {
      return;
    }

    final updatedStorages = state.storages
      ..removeAt(index)
      ..insert(index, storage);

    set(state.copyWith(storages: updatedStorages));
    save(state);
  }

  Future<void> removeStorage(int index) async {
    if (index < 0 || index >= state.storages.length) {
      return;
    }

    final updatedStorages = state.storages..removeAt(index);

    set(state.copyWith(storages: updatedStorages));
    save(state);
  }

  Future<void> toggleMaximize() async =>
      set(state.copyWith(isMaximized: !state.isMaximized));

  @override
  Future<AppState?> load() async {
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      String? appState = await storage.read(key: 'appState');
      if (appState != null) {
        return AppState.fromJson(json.decode(appState));
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

      await storage.write(key: 'appState', value: json.encode(state.toJson()));
    } catch (e) {
      log('Error saving AppState: $e');
    }
  }
}

AppStore useAppStore() => create(() => AppStore());
