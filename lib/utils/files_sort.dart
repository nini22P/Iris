import 'package:iris/models/file.dart';
import 'package:iris/models/store/app_state.dart';

List<FileItem> filesSort({
  required List<FileItem> files,
  SortBy sortBy = SortBy.name,
  SortOrder sortOrder = SortOrder.asc,
  bool folderFirst = true,
}) {
  final dirs_ = files.where((file) => file.isDir).toList();
  final files_ = files.where((file) => !file.isDir).toList();

  int compare(dynamic a, dynamic b) {
    int result;
    if (a is String && b is String) {
      result = a.toLowerCase().compareTo(b.toLowerCase());
    } else if (a is Comparable && b is Comparable) {
      result = a.compareTo(b);
    } else {
      result = 0;
    }

    return sortOrder == SortOrder.asc ? result : -result;
  }

  if (folderFirst) {
    switch (sortBy) {
      case SortBy.name:
        dirs_.sort((a, b) => compare(a.name, b.name));
        files_.sort((a, b) => compare(a.name, b.name));
        break;
      case SortBy.size:
        dirs_.sort((a, b) => compare(a.size, b.size));
        files_.sort((a, b) => compare(a.size, b.size));
        break;
      case SortBy.lastModified:
        dirs_.sort((a, b) => compare(
              a.lastModified ?? DateTime(0),
              b.lastModified ?? DateTime(0),
            ));
        files_.sort((a, b) => compare(
              a.lastModified ?? DateTime(0),
              b.lastModified ?? DateTime(0),
            ));
        break;
    }
    return [...dirs_, ...files_];
  } else {
    switch (sortBy) {
      case SortBy.name:
        files.sort((a, b) => compare(a.name, b.name));
        break;
      case SortBy.size:
        files.sort((a, b) => compare(a.size, b.size));
        break;
      case SortBy.lastModified:
        files.sort((a, b) => compare(
              a.lastModified ?? DateTime(0),
              b.lastModified ?? DateTime(0),
            ));
        break;
    }
    return files;
  }
}
