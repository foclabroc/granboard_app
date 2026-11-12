import 'dart:async';

import 'package:granboard_proto/ui/award.dart';

/// Lancé avant chaque fichier de test : pas de lecteur vidéo en test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AwardPlayer.enabled = false;
  await testMain();
}
