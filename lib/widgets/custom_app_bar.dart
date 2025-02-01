import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/info.dart';
import 'package:iris/models/player.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/is_desktop.dart';
import 'package:iris/utils/resize_window.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends HookWidget {
  const CustomAppBar({
    super.key,
    this.title,
    required this.player,
    this.actions,
  });
  final String? title;
  final MediaPlayer player;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    return Container(
      padding: isDesktop
          ? const EdgeInsets.fromLTRB(12, 4, 4, 8)
          : const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: ExcludeFocus(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/icon.png', width: 24, height: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title!.isEmpty ? INFO.title : title!,
                  maxLines: 1,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 16,
                    overflow: TextOverflow.ellipsis,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Row(
                children: [
                  ...actions ?? [],
                  if (isDesktop) ...[
                    FutureBuilder<Map<String, bool>>(
                      future: () async {
                        final isFullScreen =
                            isDesktop && await windowManager.isFullScreen();
                        final isMaximized =
                            isDesktop && await windowManager.isMaximized();

                        return {
                          'isFullScreen': isFullScreen,
                          'isMaximized': isMaximized,
                        };
                      }(),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<Map<String, bool>> snapshot,
                      ) {
                        final isFullScreen =
                            snapshot.data?['isFullScreen'] ?? false;
                        final isMaximized =
                            snapshot.data?['isMaximized'] ?? false;

                        return Row(
                          children: [
                            Visibility(
                              visible: !isFullScreen,
                              child: FutureBuilder<bool>(
                                future: windowManager.isAlwaysOnTop(),
                                builder: (context, snapshot) {
                                  bool isAlwaysOnTop = snapshot.data ?? false;
                                  return IconButton(
                                    tooltip: isAlwaysOnTop
                                        ? t.always_on_top_on
                                        : t.always_on_top_off,
                                    icon: Icon(
                                      isAlwaysOnTop
                                          ? Icons.push_pin_rounded
                                          : Icons.push_pin_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => windowManager
                                        .setAlwaysOnTop(!isAlwaysOnTop),
                                  );
                                },
                              ),
                            ),
                            Visibility(
                              visible: isFullScreen,
                              child: IconButton(
                                tooltip: isFullScreen
                                    ? '${t.exit_fullscreen} ( Escape, F11, Enter )'
                                    : '${t.enter_fullscreen} ( F11, Enter )',
                                icon: Icon(
                                  isFullScreen
                                      ? Icons.close_fullscreen_rounded
                                      : Icons.open_in_full_rounded,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  if (isFullScreen) {
                                    await windowManager.setFullScreen(false);
                                    await resizeWindow(player.aspect);
                                  } else {
                                    await windowManager.setFullScreen(true);
                                  }
                                },
                              ),
                            ),
                            Visibility(
                              visible: !isFullScreen,
                              child: IconButton(
                                onPressed: () => windowManager.minimize(),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                            ),
                            Visibility(
                              visible: !isFullScreen,
                              child: IconButton(
                                onPressed: () async {
                                  if (isMaximized) {
                                    await windowManager.unmaximize();
                                    await resizeWindow(player.aspect);
                                  } else {
                                    await windowManager.maximize();
                                  }
                                },
                                icon: isMaximized
                                    ? const RotatedBox(
                                        quarterTurns: 2,
                                        child: Icon(
                                          Icons.filter_none_rounded,
                                          size: 18,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.crop_din_rounded,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () async {
                        await player.saveProgress();
                        windowManager.close();
                      },
                      icon: const Icon(Icons.close_rounded),
                      style: ButtonStyle(
                        overlayColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                          if (states.contains(WidgetState.pressed)) {
                            return Colors.red.withValues(alpha: 0.4);
                          } else if (states.contains(WidgetState.hovered)) {
                            return Colors.red.withValues(alpha: 0.5);
                          }
                          return null;
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
