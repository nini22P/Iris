import 'dart:ui';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/models/player.dart';
import 'package:iris/utils/logger.dart';

void useAppLifecycle(MediaPlayer player) {
  AppLifecycleState? appLifecycleState = useAppLifecycleState();

  useEffect(() {
    try {
      if (appLifecycleState == AppLifecycleState.paused) {
        logger('App lifecycle state: paused');
        player.pause();
        player.saveProgress();
      }
    } catch (e) {
      logger('App lifecycle state error: $e');
    }
    return;
  }, [appLifecycleState]);
}
