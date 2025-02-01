import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/store/use_storage_store.dart';
import 'package:iris/utils/files_filter.dart';

FileItem? useCover(BuildContext context) {
  final playQueue =
      usePlayQueueStore().select(context, (state) => state.playQueue);
  final currentIndex =
      usePlayQueueStore().select(context, (state) => state.currentIndex);

  final int currentPlayIndex = useMemoized(
      () => playQueue.indexWhere((element) => element.index == currentIndex),
      [playQueue, currentIndex]);

  final PlayQueueItem? currentPlay = useMemoized(
      () => playQueue.isEmpty || currentPlayIndex < 0
          ? null
          : playQueue[currentPlayIndex],
      [playQueue, currentPlayIndex]);

  final localStorages =
      useStorageStore().select(context, (state) => state.localStorages);
  final storages = useStorageStore().select(context, (state) => state.storages);

  final List<String> dir = useMemoized(
    () => currentPlay?.file == null || currentPlay!.file.path.isEmpty
        ? []
        : ([...currentPlay.file.path]..removeLast()),
    [currentPlay?.file],
  );

  final Storage? storage = useMemoized(
      () => currentPlay?.file == null
          ? null
          : [...localStorages, ...storages].firstWhereOrNull(
              (storage) => storage.id == currentPlay?.file.storageId),
      [currentPlay?.file, localStorages, storages]);

  final getCover = useMemoized(() async {
    if (currentPlay?.file.type != ContentType.audio) return null;

    final files = await storage?.getFiles(dir);

    if (files == null) return null;

    final images = filesFilter(files, [ContentType.image]);

    return images.firstWhereOrNull(
            (image) => image.name.split('.').first.toLowerCase() == 'cover') ??
        images.firstOrNull;
  }, [currentPlay?.file, dir]);

  final cover = useFuture(getCover).data;

  return cover;
}
