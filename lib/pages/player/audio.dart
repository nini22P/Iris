import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/hooks/use_player_core.dart';

class Audio extends HookWidget {
  const Audio({
    super.key,
    required this.playerCore,
  });

  final PlayerCore playerCore;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            color: Colors.grey[800],
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: playerCore.cover != null
                ? playerCore.cover?.storageId == 'local'
                    ? Image.file(
                        File(playerCore.cover!.uri),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        playerCore.cover!.uri,
                        headers: playerCore.cover!.auth != null
                            ? {'authorization': playerCore.cover!.auth!}
                            : null,
                        fit: BoxFit.cover,
                      )
                : null,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: MediaQuery.of(context).size.width > 800
                ? MediaQuery.of(context).size.width / 2
                : 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: playerCore.cover != null
                      ? playerCore.cover!.storageId == 'local'
                          ? Image.file(
                              File(playerCore.cover!.uri),
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              playerCore.cover!.uri,
                              headers: playerCore.cover!.auth != null
                                  ? {'authorization': playerCore.cover!.auth!}
                                  : null,
                              fit: BoxFit.contain,
                            )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
