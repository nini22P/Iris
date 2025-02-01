import 'dart:io';
import 'package:android_x_storage/android_x_storage.dart';
import 'package:collection/collection.dart';
import 'package:disks_desktop/disks_desktop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/models/store/play_queue_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/utils/files_filter.dart';
import 'package:iris/utils/files_sort.dart';
import 'package:iris/utils/find_subtitle.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/is_desktop.dart';
import 'package:iris/utils/logger.dart';
import 'package:iris/utils/path_conv.dart';
import 'package:path/path.dart' as p;
import 'package:iris/models/file.dart';
import 'package:iris/utils/check_content_type.dart';
import 'package:saf_util/saf_util.dart';

Future<List<FileItem>> getLocalFiles(
    LocalStorage storage, List<String> path) async {
  final directory = Directory(path.join('/'));

  List<FileItem> files = [];
  try {
    final entities = directory.list();

    await for (final entity in entities) {
      final isDir = entity is Directory;
      int size = 0;
      DateTime? lastModified;
      if (!isDir) {
        final file = File(entity.path);
        try {
          size = await file.length();
          lastModified = await file.lastModified();
        } on PathAccessException catch (e) {
          logger(
              'PathAccessException when getting file info for ${entity.path}: $e');
        } catch (e) {
          logger('Error getting file info for ${entity.path}: $e');
        }
      }

      if (isDir) {
        final dir = Directory(entity.path);
        try {
          final stat = await dir.stat();
          lastModified = stat.modified;
        } on PathAccessException catch (e) {
          logger(
              'PathAccessException when getting directory info for ${entity.path}: $e');
        } catch (e) {
          logger('Error getting directory info for ${entity.path}: $e');
        }
      }

      final subtitles = await findLocalSubtitle(
        directory,
        p.basename(entity.path),
        entity.path,
      );

      files.add(FileItem(
          storageId: storage.id,
          storageType: storage.type,
          name: p.basename(entity.path),
          uri: pathConv(entity.path).join('/'),
          path: [...path, p.basename(entity.path)],
          isDir: isDir,
          size: size,
          lastModified: lastModified,
          type: isDir
              ? ContentType.dir
              : checkContentType(p.basename(entity.path)),
          subtitles: subtitles));
    }
  } catch (e) {
    logger('Error reading directory $path : $e');
    return [];
  }

  return files;
}

Future<List<LocalStorage>> getLocalStorages(
  BuildContext context,
) async {
  final t = getLocalizations(context);
  if (isDesktop) {
    final repository = DisksRepository();
    final disks = await repository.query;
    List<LocalStorage> storages = [];
    for (var disk in disks) {
      for (var mountpoint in disk.mountpoints) {
        final storage = LocalStorage(
          type: StorageType.internal,
          name: '${t.local_storage} (${mountpoint.path.replaceAll('\\', '')})',
          basePath: [mountpoint.path.replaceAll('\\', '')],
        );
        storages.add(storage);
      }
    }
    return storages.sorted((a, b) => a.name.compareTo(b.basePath[0]));
  } else if (Platform.isAndroid) {
    final androidXStorage = AndroidXStorage();
    final external = await androidXStorage.getExternalStorageDirectory();
    final sdcard = await androidXStorage.getSDCardStorageDirectory();
    final usbs = await androidXStorage.getUSBStorageDirectories();
    List<LocalStorage> storages = [];
    if (external != null) {
      final storage = LocalStorage(
        type: StorageType.internal,
        name: t.local_storage,
        basePath: [external],
      );
      storages.add(storage);
    }
    if (sdcard != null) {
      final storage = LocalStorage(
        type: StorageType.sdcard,
        name: 'SD Card',
        basePath: [sdcard],
      );
      storages.add(storage);
    }
    for (var usb in usbs) {
      if (usb != null) {
        final storage = LocalStorage(
          type: StorageType.usb,
          name: t.usb_storage,
          basePath: [usb],
        );
        storages.add(storage);
      }
    }

    return storages;
  }
  return [];
}

Future<PlayQueueState?> getLocalPlayQueue(List<String> filePath) async {
  final type = checkContentType(filePath.last);

  if (type != ContentType.video && type != ContentType.audio) {
    return null;
  }

  final dirPath = filePath.sublist(0, filePath.length - 1);
  final files = await LocalStorage(
    type: StorageType.internal,
    name: filePath.last,
    basePath: dirPath,
  ).getFiles(dirPath);
  final List<FileItem> sortedFiles = filesSort(files: files);
  final List<FileItem> filteredFiles =
      filesFilter(sortedFiles, [ContentType.video, ContentType.audio]);
  final List<PlayQueueItem> playQueue = filteredFiles
      .asMap()
      .entries
      .map((entry) => PlayQueueItem(file: entry.value, index: entry.key))
      .toList();

  final clickedFile = filteredFiles
      .where((file) => file.path.join('/') == filePath.join('/'))
      .first;
  final index = filteredFiles.indexOf(clickedFile);
  return PlayQueueState(
    playQueue: playQueue,
    currentIndex: index < 0 || index >= playQueue.length ? 0 : index,
  );
}

Future<void> pickLocalFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [...Formats.video, ...Formats.audio],
  );

  if (result != null) {
    final filePath = pathConv(result.files.first.path!);
    final playQueue = await getLocalPlayQueue(filePath);

    if (playQueue == null || playQueue.playQueue.isEmpty) return;

    await useAppStore().updateAutoPlay(true);
    await usePlayQueueStore().update(
      playQueue: playQueue.playQueue,
      index: playQueue.currentIndex,
    );
  }
}

Future<void> pickAndroidFile() async {
  final file = await SafUtil().pickFile(mimeTypes: ['video/*', 'audio/*']);
  if (file != null) {
    await useAppStore().updateAutoPlay(true);
    await usePlayQueueStore().update(
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
      index: 0,
    );
  }
}
