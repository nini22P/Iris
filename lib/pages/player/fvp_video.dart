import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/player.dart';
import 'package:iris/store/use_app_store.dart';

class FvpVideo extends HookWidget {
  const FvpVideo({super.key, required this.player});

  final FvpPlayer player;

  @override
  Widget build(context) {
    final fit = useAppStore().select(context, (state) => state.fit);

    final id = useValueListenable(player.player.textureId);

    return id == null
        ? SizedBox.shrink()
        : FittedBox(
            fit: fit,
            child: SizedBox(
              width: player.width,
              height: player.height,
              child: Texture(textureId: id),
            ),
          );
  }
}
