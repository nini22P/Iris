import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/progress.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/file_size_convert.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/widgets/custom_chip.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PlayQueue extends HookWidget {
  const PlayQueue({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final playQueue =
        usePlayQueueStore().select(context, (state) => state.playQueue);
    final currentIndex =
        usePlayQueueStore().select(context, (state) => state.currentIndex);

    final int currentPlayIndex = useMemoized(
        () => playQueue.indexWhere((element) => element.index == currentIndex),
        [playQueue, currentIndex]);

    ItemScrollController itemScrollController = ItemScrollController();
    ScrollOffsetController scrollOffsetController = ScrollOffsetController();
    ItemPositionsListener itemPositionsListener =
        ItemPositionsListener.create();
    ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (itemScrollController.isAttached && playQueue.isNotEmpty) {
          itemScrollController.jumpTo(
              index: currentPlayIndex - 3 < 0 ? 0 : currentPlayIndex - 1);
        }
      });
      return;
    }, []);

    return Column(
      children: [
        Expanded(
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ScrollablePositionedList.builder(
              itemCount: playQueue.length,
              itemBuilder: (context, index) => ListTile(
                autofocus: currentPlayIndex == index,
                tileColor: currentPlayIndex == index
                    ? Theme.of(context).hoverColor
                    : null,
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                leading: Text(
                  (index + 1).toString(),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                minLeadingWidth: 14,
                title: Text(
                  playQueue[index].file.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: currentPlayIndex == index
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                subtitle: Row(
                  children: [
                    if (playQueue[index].file.size > 0)
                      Text("${fileSizeConvert(playQueue[index].file.size)} MB",
                          style: TextStyle(
                              fontSize: 13,
                              color: currentPlayIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : null)),
                    const Spacer(),
                    () {
                      final Progress? progress = useHistoryStore()
                          .findById(playQueue[index].file.getID());
                      if (progress != null &&
                          progress.file.type == ContentType.video) {
                        if ((progress.duration.inMilliseconds -
                                progress.position.inMilliseconds) <=
                            5000) {
                          return CustomChip(text: '100%');
                        }
                        final String progressString =
                            (progress.position.inMilliseconds /
                                    progress.duration.inMilliseconds *
                                    100)
                                .toStringAsFixed(0);
                        return CustomChip(text: '$progressString %');
                      } else {
                        return const SizedBox();
                      }
                    }(),
                    ...playQueue[index]
                        .file
                        .subtitles
                        .map((subtitle) =>
                            subtitle.uri.split('.').last.toUpperCase())
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
                trailing: PopupMenuButton<FileOptions>(
                  clipBehavior: Clip.hardEdge,
                  constraints: const BoxConstraints(minWidth: 200),
                  onSelected: (value) async {
                    switch (value) {
                      case FileOptions.remove:
                        usePlayQueueStore().remove(playQueue[index]);
                        break;
                      case FileOptions.openInFolder:
                        await openInFolder(context, playQueue[index].file);
                        break;
                      default:
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: FileOptions.remove,
                      child: Text(t.remove),
                    ),
                    if (playQueue[index].file.path.isNotEmpty)
                      PopupMenuItem(
                        value: FileOptions.openInFolder,
                        child: Text(t.open_in_folder),
                      ),
                  ],
                ),
                onTap: () async {
                  await useAppStore().updateAutoPlay(true);
                  usePlayQueueStore()
                      .updateCurrentIndex(playQueue[index].index);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              itemScrollController: itemScrollController,
              scrollOffsetController: scrollOffsetController,
              itemPositionsListener: itemPositionsListener,
              scrollOffsetListener: scrollOffsetListener,
            ),
          ),
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          height: 0,
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Text(
                t.play_queue,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
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
