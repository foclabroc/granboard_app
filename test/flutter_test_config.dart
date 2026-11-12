import 'dart:async';

import 'package:granboard_proto/ui/award.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/turn_banner.dart';

/// Lancé avant chaque fichier de test : pas de lecteur vidéo en test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AwardPlayer.enabled = false;
  SkinBackground.animate = false;
  TurnBanner.enabled = false;
  await testMain();
}
