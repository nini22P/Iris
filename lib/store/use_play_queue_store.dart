import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/local.dart';
import 'package:iris/models/store/play_queue_state.dart';
import 'package:iris/store/persistent_store.dart';
import 'package:iris/globals.dart' as globals;
import 'package:iris/store/use_app_store.dart';
import 'package:iris/utils/check_content_type.dart';
import 'package:iris/utils/get_shuffle_play_queue.dart';
import 'package:iris/utils/is_desktop.dart';
import 'package:iris/utils/logger.dart';
import 'package:iris/utils/path_conv.dart';
import 'package:saf_util/saf_util.dart';

class PlayQueueStore extends PersistentStore<PlayQueueState> {
  PlayQueueStore() : super(PlayQueueState());

  Future<void> update({
    required List<PlayQueueItem> playQueue,
    int? index,
  }) async {
    set(state.copyWith(
      playQueue: playQueue,
      currentIndex: index ?? state.currentIndex,
    ));
    if (Platform.isAndroid &&
        state.playQueue.any((e) => e.file.uri.startsWith('content://'))) {
      return;
    }
    await save(state);
  }

  Future<void> updateCurrentIndex(int index) async {
    set(state.copyWith(currentIndex: index));
    if (Platform.isAndroid &&
        state.playQueue.any((e) => e.file.uri.startsWith('content://'))) {
      return;
    }
    await save(state);
  }

  Future<void> add(List<FileItem> files) async {
    final int startIndex = state.playQueue.isEmpty
        ? 0
        : state.playQueue
                .sorted((a, b) => a.index.compareTo(b.index))
                .last
                .index +
            1;

    final List<PlayQueueItem> playQueue = files
        .asMap()
        .entries
        .map((entry) =>
            PlayQueueItem(file: entry.value, index: startIndex + entry.key))
        .toList();

    set(state.copyWith(playQueue: [...state.playQueue, ...playQueue]));
    if (Platform.isAndroid &&
        state.playQueue.any((e) => e.file.uri.startsWith('content://'))) {
      return;
    }
    await save(state);
  }

  Future<void> remove(PlayQueueItem item) async {
    if (state.playQueue.length <= 1) {
      set(state.copyWith(playQueue: [], currentIndex: 0));
    } else {
      final index = state.playQueue.indexOf(item);
      if (state.playQueue[index].index == state.currentIndex) {
        if (index + 1 < state.playQueue.length) {
          set(state.copyWith(
            playQueue: [...state.playQueue]..remove(item),
            currentIndex: state.playQueue[index + 1].index,
          ));
        } else {
          set(state.copyWith(
            playQueue: [...state.playQueue]..remove(item),
            currentIndex: state.playQueue[index - 1].index,
          ));
        }
      } else {
        set(state.copyWith(
          playQueue: [...state.playQueue]..remove(item),
        ));
      }
    }
    if (Platform.isAndroid &&
        state.playQueue.any((e) => e.file.uri.startsWith('content://'))) {
      return;
    }
    await save(state);
  }

  Future<void> previous() async {
    final int currentPlayIndex = state.playQueue
        .indexWhere((element) => element.index == state.currentIndex);
    if (currentPlayIndex <= 0) return;
    await updateCurrentIndex(state.playQueue[currentPlayIndex - 1].index);
  }

  Future<void> next() async {
    final int currentPlayIndex = state.playQueue
        .indexWhere((element) => element.index == state.currentIndex);
    if (currentPlayIndex >= state.playQueue.length - 1) return;
    await updateCurrentIndex(state.playQueue[currentPlayIndex + 1].index);
  }

  Future<void> shuffle() async => update(
        playQueue: getShufflePlayQueue(state.playQueue, state.currentIndex),
        index: state.currentIndex,
      );

  Future<void> sort() async => update(
        playQueue: [...state.playQueue]
          ..sort((a, b) => a.index.compareTo(b.index)),
        index: state.currentIndex,
      );

  @override
  Future<PlayQueueState?> load() async {
    logger('Loading PlayQueueState');
    try {
      if (isDesktop && globals.arguments.isNotEmpty) {
        String uri = globals.arguments[0];
        // 在线播放
        if (RegExp(r'^(http://|https://)').hasMatch(uri)) {
          final state = PlayQueueState(
            playQueue: [
              PlayQueueItem(
                file: FileItem(
                  name: uri,
                  uri: uri,
                ),
                index: 0,
              )
            ],
            currentIndex: 0,
          );
          await useAppStore().updateAutoPlay(true);
          save(state);
          return state;
        }

        // 本地播放
        final filePath = pathConv(uri);
        if (isMediaFile(filePath.last)) {
          final state = await getLocalPlayQueue(filePath);
          if (state != null && state.playQueue.isNotEmpty) {
            await useAppStore().updateAutoPlay(true);
            save(state);
            return state;
          }
        }
      }

      final uri = globals.initUri;

      // Android
      if (uri != null && Platform.isAndroid) {
        final file = await SafUtil().documentFileFromUri(uri, false);
        if (file != null) {
          await useAppStore().updateAutoPlay(true);
          return PlayQueueState(
            playQueue: [
              PlayQueueItem(
                file: FileItem(
                  name: file.name,
                  uri: file.uri,
                  size: file.length,
                ),
                index: 0,
              ),
            ],
            currentIndex: 0,
          );
        }
      }

      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      String? appState = await storage.read(key: 'playQueue_state');
      if (appState != null) {
        return PlayQueueState.fromJson(json.decode(appState));
      }
    } catch (e) {
      logger('Error loading PlayQueueState: $e');
    }
    return null;
  }

  @override
  Future<void> save(PlayQueueState state) async {
    try {
      AndroidOptions getAndroidOptions() => const AndroidOptions(
            encryptedSharedPreferences: true,
          );
      final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

      await storage.write(
          key: 'playQueue_state', value: json.encode(state.toJson()));
    } catch (e) {
      logger('Error saving PlayQueueState: $e');
    }
  }
}

PlayQueueStore usePlayQueueStore() => create(() => PlayQueueStore());
