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

class History extends HookWidget {
  const History({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final Map<String, Progress> history =
        useHistoryStore().select(context, (state) => state.history);

    final List<MapEntry<String, Progress>> historyList = useMemoized(() {
      final entries = history.entries.toList();
      entries.sort((a, b) => b.value.dateTime.compareTo(a.value.dateTime));
      return entries;
    }, [history]);

    Future<void> play(int index) async {
      await useAppStore().updateAutoPlay(true);

      final playQueue = historyList
          .asMap()
          .map((index, entry) => MapEntry(
              index, PlayQueueItem(file: entry.value.file, index: index)))
          .values
          .toList();

      usePlayQueueStore().update(playQueue: playQueue, index: index);
    }

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
              itemCount: historyList.length,
              itemBuilder: (context, index) => ListTile(
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
                  historyList[index].value.file.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    if (historyList[index].value.file.size > 0)
                      Text(
                          "${fileSizeConvert(historyList[index].value.file.size)} MB"),
                    const Spacer(),
                    () {
                      final Progress? progress = useHistoryStore()
                          .findById(historyList[index].value.file.getID());
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
                    ...historyList[index]
                        .value
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
                      case FileOptions.addToPlayQueue:
                        usePlayQueueStore()
                            .add([historyList[index].value.file]);
                        break;
                      case FileOptions.remove:
                        useHistoryStore().remove(historyList[index].value);
                        break;
                      case FileOptions.openInFolder:
                        await openInFolder(
                            context, historyList[index].value.file);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: FileOptions.addToPlayQueue,
                      child: Text(t.add_to_play_queue),
                    ),
                    PopupMenuItem(
                      value: FileOptions.remove,
                      child: Text(t.remove),
                    ),
                    if (historyList[index].value.file.path.isNotEmpty)
                      PopupMenuItem(
                        value: FileOptions.openInFolder,
                        child: Text(t.open_in_folder),
                      ),
                  ],
                ),
                onTap: () {
                  play(index);
                  Navigator.of(context).pop();
                },
              ),
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
                t.history,
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
