import 'dart:async';

import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/lan.dart';
import 'package:granboard_proto/online/live.dart';
import 'package:granboard_proto/tv/screen_cam.dart';
import 'package:granboard_proto/ui/award.dart';
import 'package:granboard_proto/ui/boot_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/turn_banner.dart';
import 'package:granboard_proto/ui/tile_fx.dart';
import 'package:granboard_proto/ui/game_intro.dart';
import 'package:granboard_proto/ui/wallpaper.dart';

/// Lancé avant chaque fichier de test : pas de lecteur vidéo en test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AwardPlayer.enabled = false;
  AudioService.loopPlayer = false;
  BootGate.enabled = false;
  SkinBackground.animate = false;
  TurnBanner.enabled = false;
  TileFx.enabled = false;
  GameIntro.enabled = false; // remis dans intro_test
  Wallpaper.storage = false;
  Lan.enabled = false;
  ScreenCam.enabled = false;
  LiveCast.enabled = false; // remis dans online_test
  await testMain();
}
