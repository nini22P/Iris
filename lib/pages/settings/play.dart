import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/store/app_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/utils/is_desktop.dart';

class Play extends HookWidget {
  const Play({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final autoResize =
        useAppStore().select(context, (state) => state.autoResize);
    final bool alwaysPlayFromBeginning =
        useAppStore().select(context, (state) => state.alwaysPlayFromBeginning);
    final playerBackend =
        useAppStore().select(context, (state) => state.playerBackend);

    return SingleChildScrollView(
      child: Column(
        children: [
          ListTile(
              leading: const Icon(Icons.settings_input_component_rounded),
              title: Text(t.player_backend),
              trailing: DropdownButton<PlayerBackend>(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                value: playerBackend,
                onChanged: (value) {
                  if (value != null) useAppStore().updatePlayerBackend(value);
                },
                items: [
                  DropdownMenuItem<PlayerBackend>(
                      value: PlayerBackend.mediaKit, child: Text('Media Kit')),
                  DropdownMenuItem<PlayerBackend>(
                      value: PlayerBackend.fvp,
                      child: Text('FVP (${t.experimental})')),
                ],
              )),
          Visibility(
            visible: isDesktop,
            child: ListTile(
              leading: const Icon(Icons.aspect_ratio_rounded),
              title: Text(t.auto_resize),
              onTap: () => useAppStore().toggleAutoResize(),
              trailing: Checkbox(
                value: autoResize,
                onChanged: (_) => useAppStore().toggleAutoResize(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: Text(t.always_play_from_beginning),
            subtitle: Text(t.always_play_from_beginning_description),
            onTap: () => useAppStore().toggleAlwaysPlayFromBeginning(),
            trailing: Checkbox(
              value: alwaysPlayFromBeginning,
              onChanged: (_) => useAppStore().toggleAlwaysPlayFromBeginning(),
            ),
          ),
        ],
      ),
    );
  }
}
