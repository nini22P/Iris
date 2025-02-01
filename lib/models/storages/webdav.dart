import 'dart:convert';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/utils/check_content_type.dart';
import 'package:iris/utils/find_subtitle.dart';
import 'package:iris/utils/logger.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:iris/models/file.dart';

Future<bool> testWebDAV(WebDAVStorage storage) async {
  final host = storage.host;
  final port = storage.port;
  final username = storage.username;
  final password = storage.password;
  final https = storage.https;
  final basePath = storage.basePath;

  try {
    var client = webdav.newClient(
      "http${https ? 's' : ''}://$host:$port",
      user: username,
      password: password,
      debug: false,
    );

    client.setHeaders({'accept-charset': 'utf-8'});
    client.setConnectTimeout(4000);
    client.setSendTimeout(4000);
    client.setReceiveTimeout(4000);

    // await client.ping();
    await client.readDir(basePath.join('/'));
    return true;
  } catch (e) {
    logger(e.toString());
    return false;
  }
}

Future<List<FileItem>> getWebDAVFiles(
    WebDAVStorage storage, List<String> path) async {
  final id = storage.id;
  final host = storage.host;
  final port = storage.port;
  final username = storage.username;
  final password = storage.password;
  final https = storage.https;

  var client = webdav.newClient(
    "http${https ? 's' : ''}://$host:$port",
    user: username,
    password: password,
    debug: false,
  );

  final String auth =
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  client.setHeaders({'accept-charset': 'utf-8'});
  client.setConnectTimeout(8000);
  client.setSendTimeout(8000);
  client.setReceiveTimeout(8000);

  var files = await client.readDir(path.join('/'));

  final String baseUri =
      'http${https ? 's' : ''}://$host:$port${path.join('/')}';

  return await Future.wait(files.map((file) async => FileItem(
        storageId: id,
        storageType: StorageType.webdav,
        name: '${file.name}',
        uri: '$baseUri/${file.name}',
        path: [...path, '${file.name}'],
        isDir: file.isDir ?? false,
        size: file.size ?? 0,
        lastModified: file.mTime,
        type: file.isDir ?? false
            ? ContentType.dir
            : checkContentType(file.name!),
        auth: auth,
        subtitles: await findSubtitle(
            files.map((file) => file.name as String).toList(),
            file.name as String,
            baseUri),
      )));
}
