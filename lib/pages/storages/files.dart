import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/hooks/use_get_files.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/store/use_storage_store.dart';
import 'package:iris/utils/file_size_convert.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class Files extends HookWidget {
  const Files({super.key, required this.storage});

  final Storage storage;

  @override
  Widget build(BuildContext context) {
    final basePath = storage.basePath;

    final currentPath =
        useStorageStore().select(context, (state) => state.currentPath);

    useEffect(() {
      if (currentPath.isEmpty) {
        useStorageStore().updateCurrentPath(basePath);
      }
      return null;
    }, []);

    final title = storage.name;

    final result = useGetFiles(currentPath, storage.getFiles);
    final List<FileItem> files = result.data ?? [];
    final isLoading = result.isLoading;
    final error = result.error;

    final filteredFiles = useMemoized(
        () =>
            files.where((file) => file.isDir || file.type == 'video').toList(),
        [files]);

    ItemScrollController itemScrollController = ItemScrollController();
    ScrollOffsetController scrollOffsetController = ScrollOffsetController();
    ItemPositionsListener itemPositionsListener =
        ItemPositionsListener.create();
    ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

    void play(List<FileItem> files, int index) async {
      final clickedFile = files[index];
      final playQueue = files.where((file) => file.type == 'video').toList();
      final newIndex = playQueue.indexOf(clickedFile);

      await useAppStore().updateAutoPlay(true);
      await usePlayQueueStore().updatePlayQueue(playQueue, newIndex);
    }

    final refreshState = useState(false);

    final isFavorited = useMemoized(
        () => useStorageStore().state.favoriteStorages.any((favoriteStorage) =>
            favoriteStorage.basePath.join('/') == currentPath.join('/')),
        [currentPath, refreshState.value]);

    void refresh() => refreshState.value = !refreshState.value;

    void back() {
      if (currentPath.length > basePath.length) {
        useStorageStore()
            .updateCurrentPath(currentPath.sublist(0, currentPath.length - 1));
      } else {
        useStorageStore().updateCurrentStorage(null);
        useStorageStore().updateCurrentPath([]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error
                  ? const Center(child: Text('Error fetching files.'))
                  : filteredFiles.isEmpty
                      ? const Center(child: Text('No files found.'))
                      : ScrollablePositionedList.builder(
                          itemScrollController: itemScrollController,
                          scrollOffsetController: scrollOffsetController,
                          itemPositionsListener: itemPositionsListener,
                          scrollOffsetListener: scrollOffsetListener,
                          itemCount: filteredFiles.length,
                          itemBuilder: (context, index) => ListTile(
                            contentPadding:
                                const EdgeInsets.fromLTRB(16, 0, 8, 0),
                            leading: filteredFiles[index].isDir == true
                                ? const Icon(Icons.folder_rounded)
                                : const Icon(Icons.video_file_rounded),
                            title: Text(
                              filteredFiles[index].name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              // style: const TextStyle(
                              //   fontWeight: FontWeight.w500,
                              // ),
                            ),
                            subtitle: filteredFiles[index].size != 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          "${fileSizeConvert(filteredFiles[index].size)} MB"),
                                      const Spacer(),
                                      const SizedBox(width: 16),
                                      ...filteredFiles[index]
                                          .subtitles!
                                          .map((subtitle) => subtitle.uri
                                              .split('.')
                                              .last
                                              .toUpperCase())
                                          .toSet()
                                          .toList()
                                          .map((subTitleType) => Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .inversePrimary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    padding: const EdgeInsets
                                                        .fromLTRB(8, 4, 8, 4),
                                                    child: Text(
                                                      subTitleType,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              )),
                                    ],
                                  )
                                : null,
                            onTap: () {
                              if (filteredFiles[index].isDir == true &&
                                  filteredFiles[index].name.isNotEmpty) {
                                useStorageStore().updateCurrentPath([
                                  ...currentPath,
                                  filteredFiles[index].name
                                ]);
                              } else {
                                play(filteredFiles, index);
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: BreadCrumb.builder(
            itemCount: currentPath.length - basePath.length + 1,
            builder: (index) {
              return BreadCrumbItem(
                content: TextButton(
                  child: Text(
                      ['/', ...currentPath.sublist(basePath.length)][index]),
                  onPressed: () {
                    useStorageStore().updateCurrentPath(
                        currentPath.sublist(0, index + basePath.length));
                  },
                ),
              );
            },
            divider: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
          height: 0,
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: back,
              ),
              IconButton(
                icon: const Icon(Icons.home_rounded),
                onPressed: () {
                  useStorageStore().updateCurrentStorage(null);
                  useStorageStore().updateCurrentPath([]);
                },
              ),
              IconButton(
                icon: Icon(isFavorited
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded),
                onPressed: () async {
                  if (isFavorited) {
                    await useStorageStore().removeFavoriteStorage(
                        useStorageStore().state.favoriteStorages.indexWhere(
                            (storage) =>
                                storage.basePath.join('/') ==
                                currentPath.join('/')));
                    refresh();
                    return;
                  }
                  await useStorageStore().addFavoriteStorage(storage.copyWith(
                      name: currentPath.length == 1 ? title : currentPath.last,
                      basePath: currentPath));
                  refresh();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
