import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fvp/mdk.dart';
import 'package:iris/models/player.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/logger.dart';
import 'package:media_kit/media_kit.dart';

class SubtitleList extends HookWidget {
  const SubtitleList({super.key, required this.player});

  final MediaPlayer player;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final focusNode = useFocusNode();

    useEffect(() {
      focusNode.requestFocus();
      return () => focusNode.unfocus();
    }, []);

    if (player is MediaKitPlayer) {
      return ListView(
        children: [
          ...(player as MediaKitPlayer).subtitles.map(
                (subtitle) => ListTile(
                  focusNode: (player as MediaKitPlayer).subtitle == subtitle
                      ? focusNode
                      : null,
                  title: Text(
                    subtitle == SubtitleTrack.no()
                        ? t.off
                        : subtitle.title ?? subtitle.language ?? subtitle.id,
                    style: (player as MediaKitPlayer).subtitle == subtitle
                        ? TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  onTap: () {
                    logger(
                        'Set subtitle: ${subtitle.title ?? subtitle.language ?? subtitle.id}');
                    (player as MediaKitPlayer)
                        .player
                        .setSubtitleTrack(subtitle);
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ...(player as MediaKitPlayer).externalSubtitles.map(
                (subtitle) => ListTile(
                  title: Text(
                    subtitle.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    logger('Set external subtitle: ${subtitle.name}');
                    (player as MediaKitPlayer).player.setSubtitleTrack(
                          SubtitleTrack.uri(
                            subtitle.uri,
                            title: subtitle.name,
                          ),
                        );
                    Navigator.of(context).pop();
                  },
                ),
              ),
        ],
      );
    }

    if (player is FvpPlayer) {
      final subtitles = (player as FvpPlayer).player.mediaInfo.subtitle ?? [];
      final activeSubtitles = (player as FvpPlayer).player.activeSubtitleTracks;
      return ListView(
        children: [
          ListTile(
            focusNode: (player as FvpPlayer).externalSubtitle.value == null &&
                    activeSubtitles.isEmpty
                ? focusNode
                : null,
            title: Text(
              t.off,
              style: (player as FvpPlayer).externalSubtitle.value == null &&
                      activeSubtitles.isEmpty
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            onTap: () {
              logger('Set subtitle: ${t.off}');
              (player as FvpPlayer).externalSubtitle.value = null;
              (player as FvpPlayer).player.setMedia('', MediaType.subtitle);
              (player as FvpPlayer)
                  .player
                  .setActiveTracks(MediaType.subtitle, []);
              Navigator.of(context).pop();
            },
          ),
          ...subtitles.map(
            (subtitle) => ListTile(
              focusNode: (player as FvpPlayer).externalSubtitle.value == null &&
                      activeSubtitles.contains(subtitles.indexOf(subtitle))
                  ? focusNode
                  : null,
              title: Text(
                subtitle.metadata['title'] ??
                    subtitle.metadata['language'] ??
                    subtitle.index.toString(),
                style: (player as FvpPlayer).externalSubtitle.value == null &&
                        activeSubtitles.contains(subtitles.indexOf(subtitle))
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              onTap: () {
                logger(
                    'Set subtitle: ${subtitle.metadata['title'] ?? subtitle.metadata['language'] ?? subtitle.index.toString()}');
                (player as FvpPlayer).externalSubtitle.value = null;
                (player as FvpPlayer).player.setMedia('', MediaType.subtitle);
                (player as FvpPlayer).player.setActiveTracks(
                    MediaType.subtitle, [subtitles.indexOf(subtitle)]);
                Navigator.of(context).pop();
              },
            ),
          ),
          ...(player as FvpPlayer).externalSubtitles.map(
                (subtitle) => ListTile(
                  focusNode: (player as FvpPlayer).externalSubtitle.value ==
                          (player as FvpPlayer)
                              .externalSubtitles
                              .indexOf(subtitle)
                      ? focusNode
                      : null,
                  title: (player as FvpPlayer).externalSubtitle.value ==
                          (player as FvpPlayer)
                              .externalSubtitles
                              .indexOf(subtitle)
                      ? Text(
                          subtitle.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        )
                      : Text(
                          subtitle.name,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                  onTap: () {
                    logger('Set external subtitle: ${subtitle.name}');
                    (player as FvpPlayer).externalSubtitle.value =
                        (player as FvpPlayer)
                            .externalSubtitles
                            .indexOf(subtitle);
                    (player as FvpPlayer)
                        .player
                        .setMedia(subtitle.uri, MediaType.subtitle);
                    Navigator.of(context).pop();
                  },
                ),
              ),
        ],
      );
    }

    return Container();
  }
}
