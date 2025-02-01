import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/globals.dart' as globals;
import 'package:iris/models/file.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/models/store/storage_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/store/use_storage_store.dart';
import 'package:iris/utils/files_filter.dart';
import 'package:iris/utils/file_size_convert.dart';
import 'package:iris/utils/files_sort.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/request_storage_permission.dart';
import 'package:iris/widgets/custom_chip.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:permission_handler/permission_handler.dart';

class Files extends HookWidget {
  const Files({super.key, required this.storage});

  final Storage storage;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final refreshState = useState(false);
    void refresh() => refreshState.value = !refreshState.value;

    final sortBy = useAppStore().select(context, (state) => state.sortBy);
    final sortOrder = useAppStore().select(context, (state) => state.sortOrder);
    final folderFirst =
        useAppStore().select(context, (state) => state.folderFirst);

    final favorites =
        useStorageStore().select(context, (state) => state.favorites);
    final currentPath =
        useStorageStore().select(context, (state) => state.currentPath);

    final currentFavorite = useMemoized(
        () => favorites.firstWhereOrNull((favorite) =>
            favorite.storageId == storage.id &&
            favorite.path.join('/') == currentPath.join('/')),
        [favorites, currentPath]);

    useEffect(() {
      if (currentPath.isEmpty) {
        useStorageStore().updateCurrentPath(storage.basePath);
      }
      return null;
    }, []);

    final getFiles = useMemoized(
        () async => await storage.getFiles(currentPath),
        [currentPath, refreshState.value]);

    final result = useFuture(getFiles);
    final isLoading = useMemoized(
        () => result.connectionState == ConnectionState.waiting,
        [result.connectionState]);
    final isError = result.error != null;

    final filteredFiles = useMemoized(
        () => filesFilter(result.data ?? [],
            [ContentType.dir, ContentType.video, ContentType.audio]),
        [result.data]);

    final files = useMemoized(
        () => filesSort(
              files: filteredFiles,
              sortBy: sortBy,
              sortOrder: sortOrder,
              folderFirst: folderFirst,
            ),
        [filteredFiles, sortBy, sortOrder, folderFirst]);

    ItemScrollController itemScrollController = ItemScrollController();
    ScrollOffsetController scrollOffsetController = ScrollOffsetController();
    ItemPositionsListener itemPositionsListener =
        ItemPositionsListener.create();
    ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

    void play(List<FileItem> files, int index) async {
      final clickedFile = files[index];
      final List<FileItem> filteredFiles =
          filesFilter(files, [ContentType.video, ContentType.audio]);
      final List<PlayQueueItem> playQueue = filteredFiles
          .asMap()
          .entries
          .map((entry) => PlayQueueItem(file: entry.value, index: entry.key))
          .toList();
      final newIndex = filteredFiles.indexOf(clickedFile);

      await useAppStore().updateAutoPlay(true);
      await useAppStore().updateShuffle(false);
      await usePlayQueueStore().update(playQueue: playQueue, index: newIndex);
    }

    void back() {
      if (currentPath.length > storage.basePath.length) {
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
          child: Platform.isAndroid &&
                  globals.storagePermissionStatus != PermissionStatus.granted &&
                  storage is LocalStorage
              ? Center(
                  child: ElevatedButton(
                      onPressed: () async {
                        await requestStoragePermission();
                        refresh();
                      },
                      child: Text(t.grant_storage_permission)),
                )
              : isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isError
                      ? Center(child: Text(t.unable_to_fetch_files))
                      : files.isEmpty
                          ? const Center()
                          : Card(
                              color: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ScrollablePositionedList.builder(
                                itemScrollController: itemScrollController,
                                scrollOffsetController: scrollOffsetController,
                                itemPositionsListener: itemPositionsListener,
                                scrollOffsetListener: scrollOffsetListener,
                                itemCount: files.length,
                                itemBuilder: (context, index) => ListTile(
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(16, 0, 8, 0),
                                  visualDensity: const VisualDensity(
                                      horizontal: 0, vertical: -4),
                                  leading: () {
                                    switch (files[index].type) {
                                      case ContentType.dir:
                                        return const Icon(Icons.folder_rounded);
                                      case ContentType.video:
                                        return const Icon(Icons.movie_rounded);
                                      case ContentType.audio:
                                        return const Icon(
                                            Icons.audiotrack_rounded);
                                      case ContentType.image:
                                        return const Icon(Icons.image_rounded);
                                      case ContentType.other:
                                        return const Icon(
                                            Icons.file_copy_rounded);
                                    }
                                  }(),
                                  title: Text(
                                    files[index].name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textBaseline: TextBaseline.ideographic,
                                    children: [
                                      if (files[index].size != 0)
                                        Text(
                                          "${fileSizeConvert(files[index].size)} MB",
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      if (files[index].size != 0)
                                        const SizedBox(width: 8),
                                      if (files[index].lastModified != null)
                                        Expanded(
                                          child: Text(
                                            files[index]
                                                .lastModified
                                                .toString()
                                                .split('.')[0],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                              fontWeight: FontWeight.w400,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      if (files[index].size != 0)
                                        const SizedBox(width: 8),
                                      () {
                                        final Progress? progress =
                                            useHistoryStore()
                                                .findById(files[index].getID());
                                        if (progress != null &&
                                            progress.file.type ==
                                                ContentType.video) {
                                          if ((progress
                                                      .duration.inMilliseconds -
                                                  progress.position
                                                      .inMilliseconds) <=
                                              5000) {
                                            return CustomChip(text: '100%');
                                          }
                                          final String progressString =
                                              (progress.position
                                                          .inMilliseconds /
                                                      progress.duration
                                                          .inMilliseconds *
                                                      100)
                                                  .toStringAsFixed(0);
                                          return CustomChip(
                                              text: '$progressString %');
                                        } else {
                                          return const SizedBox();
                                        }
                                      }(),
                                      ...files[index]
                                          .subtitles
                                          .map((subtitle) => subtitle.uri
                                              .split('.')
                                              .last
                                              .toUpperCase())
                                          .toSet()
                                          .toList()
                                          .map(
                                            (subtitleType) => Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 4),
                                                CustomChip(
                                                  text: subtitleType,
                                                  primary: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],
                                  ),
                                  trailing: files[index].type ==
                                              ContentType.video ||
                                          files[index].type == ContentType.audio
                                      ? PopupMenuButton<FileOptions>(
                                          clipBehavior: Clip.hardEdge,
                                          constraints: const BoxConstraints(
                                              minWidth: 200),
                                          onSelected: (value) async {
                                            switch (value) {
                                              case FileOptions.addToPlayQueue:
                                                usePlayQueueStore()
                                                    .add([files[index]]);
                                                break;
                                              default:
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: FileOptions.addToPlayQueue,
                                              child: Text(t.add_to_play_queue),
                                            ),
                                          ],
                                        )
                                      : null,
                                  onTap: () {
                                    if (files[index].isDir == true &&
                                        files[index].name.isNotEmpty) {
                                      useStorageStore().updateCurrentPath(
                                          [...currentPath, files[index].name]);
                                    } else {
                                      if (files[index].type ==
                                              ContentType.video ||
                                          files[index].type ==
                                              ContentType.audio) {
                                        play(files, index);
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: BreadCrumb.builder(
            itemCount: currentPath.length,
            overflow: Platform.isAndroid || Platform.isIOS
                ? ScrollableOverflow(reverse: true)
                : const WrapOverflow(),
            builder: (index) {
              return BreadCrumbItem(
                content: TextButton(
                  child: Text([storage.name, ...currentPath.sublist(1)][index]),
                  onPressed: () {
                    useStorageStore()
                        .updateCurrentPath(currentPath.sublist(0, index + 1));
                  },
                ),
              );
            },
            divider: Icon(
              Icons.chevron_right_rounded,
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(222),
            ),
          ),
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          height: 0,
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: t.back,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: back,
              ),
              IconButton(
                tooltip: t.home,
                icon: const Icon(Icons.home_rounded),
                onPressed: () {
                  useStorageStore().updateCurrentStorage(null);
                  useStorageStore().updateCurrentPath([]);
                },
              ),
              IconButton(
                tooltip: t.refresh,
                icon: const Icon(Icons.refresh),
                onPressed: refresh,
              ),
              PopupMenuButton(
                tooltip: t.sort,
                icon: const Icon(Icons.sort_rounded),
                clipBehavior: Clip.hardEdge,
                constraints: const BoxConstraints(minWidth: 200),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: Text(t.name),
                      trailing: sortBy == SortBy.name
                          ? Icon(sortOrder == SortOrder.asc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : null,
                    ),
                    onTap: () {
                      useAppStore().updateSortBy(SortBy.name);
                      useAppStore().updateSortOrder(
                          sortOrder == SortOrder.desc || sortBy != SortBy.name
                              ? SortOrder.asc
                              : SortOrder.desc);
                    },
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: Text(t.size),
                      trailing: sortBy == SortBy.size
                          ? Icon(sortOrder == SortOrder.asc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : null,
                    ),
                    onTap: () {
                      useAppStore().updateSortBy(SortBy.size);
                      useAppStore().updateSortOrder(
                          sortOrder == SortOrder.asc || sortBy != SortBy.size
                              ? SortOrder.desc
                              : SortOrder.asc);
                    },
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: Text(t.last_modified),
                      trailing: sortBy == SortBy.lastModified
                          ? Icon(sortOrder == SortOrder.asc
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded)
                          : null,
                    ),
                    onTap: () {
                      useAppStore().updateSortBy(SortBy.lastModified);
                      useAppStore().updateSortOrder(
                          sortOrder == SortOrder.asc ||
                                  sortBy != SortBy.lastModified
                              ? SortOrder.desc
                              : SortOrder.asc);
                    },
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      title: Text(t.folder_first),
                      trailing: Checkbox(
                          value: folderFirst,
                          onChanged: (_) {
                            useAppStore().updateFolderFirst(!folderFirst);
                            Navigator.pop(context);
                          }),
                    ),
                    onTap: () => useAppStore().updateFolderFirst(!folderFirst),
                  ),
                ],
              ),
              IconButton(
                tooltip: currentFavorite != null
                    ? t.remove_favorite
                    : t.add_favorite,
                icon: Icon(currentFavorite != null
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded),
                onPressed: () {
                  if (currentFavorite != null) {
                    useStorageStore().removeFavorite(currentFavorite);
                  } else {
                    useStorageStore().addFavorite(
                      Favorite(storageId: storage.id, path: currentPath),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentPath.length > 1 ? currentPath.last : storage.name,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '${t.close} ( Escape )',
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
