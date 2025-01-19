import 'dart:convert';
import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/store/history_state.dart';
import 'package:iris/store/persistent_store.dart';

class HistoryStore extends PersistentStore<HistoryState> {
  HistoryStore() : super(HistoryState());

  Progress? findByID(String id) => state.history[id];

  void add(Progress progress) {
    set(state.copyWith(
      history: {
        ...state.history,
        progress.file.getID(): progress,
      },
    ));
    save(state);
  }

  void remove(Progress progress) {
    set(state.copyWith(
        history: {...state.history}..remove(progress.file.getID())));
    save(state);
  }

  void clear() {
    set(state.copyWith(history: {}));
    save(state);
  }

  @override
  Future<HistoryState?> load() async {
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      String? historyState = await storage.read(key: 'history_state');
      if (historyState != null) {
        return HistoryState.fromJson(json.decode(historyState));
      }
    } catch (e) {
      log('Error loading HistoryState: $e');
    }
    return null;
  }

  @override
  Future<void> save(HistoryState state) async {
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      await storage.write(
          key: 'history_state', value: json.encode(state.toJson()));
    } catch (e) {
      log('Error saving HistoryState: $e');
    }
  }
}

HistoryStore useHistoryStore() => create(() => HistoryStore());
