import 'dart:convert';
import 'dart:developer';
import 'package:iris/utils/check_file_type.dart';
import 'package:iris/utils/find_sub_title.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/storage.dart';

class WebdavStorage implements Storage {
  @override
  String id;
  @override
  String type = 'webdav';
  @override
  String name;
  String url;
  @override
  List<String> basePath;
  String port;
  String username;
  String password;
  bool https;

  WebdavStorage({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    required this.basePath,
    required this.port,
    required this.username,
    required this.password,
    required this.https,
  });

  @override
  WebdavStorage copyWith({
    String? name,
    String? url,
    List<String>? basePath,
    String? port,
    String? username,
    String? password,
    bool? https,
  }) =>
      WebdavStorage(
        id: id,
        type: type,
        name: name ?? this.name,
        url: url ?? this.url,
        basePath: basePath ?? this.basePath,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        https: https ?? this.https,
      );

  Future<bool> test() async {
    try {
      var client = webdav.newClient(
        "http${https ? 's' : ''}://$url:$port",
        user: username,
        password: password,
        debug: false,
      );

      client.setHeaders({'accept-charset': 'utf-8'});
      client.setConnectTimeout(4000);
      client.setSendTimeout(4000);
      client.setReceiveTimeout(4000);

      await client.ping();
      await client.readDir(basePath.join('/'));
      return true;
    } catch (e) {
      log(e.toString());
      return false;
    }
  }

  @override
  Future<List<FileItem>> getFiles(List<String> path) async {
    var client = webdav.newClient(
      "http${https ? 's' : ''}://$url:$port",
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
        'http${https ? 's' : ''}://$url:$port/${path.join('/')}';

    return files
        .map((file) => FileItem(
              storageId: id,
              name: '${file.name}',
              uri: '$baseUri/${file.name}',
              path: [...path, '${file.name}'],
              isDir: file.isDir ?? false,
              size: file.size ?? 0,
              type: file.isDir ?? false ? 'dir' : checkFileType(file.name!),
              auth: auth,
              subtitles: findSubTitle(
                  files.map((file) => file.name as String).toList(),
                  file.name as String,
                  baseUri),
            ))
        .toList();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'url': url,
      'basePath': basePath,
      'port': port,
      'username': username,
      'password': password,
      'https': https,
    };
  }

  factory WebdavStorage.fromJson(Map<String, dynamic> json) {
    return WebdavStorage(
      id: json['id'] ?? const Uuid().v4(),
      type: json['type'],
      name: json['name'],
      url: json['url'],
      basePath: List<String>.from(json['basePath']),
      port: json['port'],
      username: json['username'],
      password: json['password'],
      https: json['https'] ?? false,
    );
  }
}
