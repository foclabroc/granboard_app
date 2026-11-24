// Écran des jeux « arcade » : la scène du jeu à la place de la cible et
// des scores (la cible reste en petit à droite, avec le joueur en cours).

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import 'bowls_scene.dart';
import 'conqueror_scene.dart';
import 'connect4_scene.dart';
import 'fight_scene.dart';
import 'pool_scene.dart';
import 'snakes_scene.dart';
import 'snooker_scene.dart';
import 'test_match_scene.dart';
import 'tug_scene.dart';
import 'vault_scene.dart';
import 'zombies_scene.dart';

/// Scène du jeu, ou null si le jeu se joue sur la cible classique.
Widget? arcadeScene(PracticeGame g, Color Function(int) colorOf) {
  final key = ValueKey('arcade-${g.settings.kind.name}');
  return switch (g.settings.kind) {
    PracticeKind.tugOfWar => TugScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.vault => VaultScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.fightClub => FightScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.connect4 => Connect4Scene(key: key, game: g, colorOf: colorOf),
    PracticeKind.snakesLadders =>
      SnakesScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.bowls => BowlsScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.conqueror =>
      ConquerorScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.testMatch =>
      TestMatchScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.snooker => SnookerScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.pool => PoolScene(key: key, game: g, colorOf: colorOf),
    PracticeKind.zombies => ZombiesScene(key: key, game: g, colorOf: colorOf),
    _ => null,
  };
}
