// Check-up : chaque jeu, chaque variante, plusieurs nombres de joueurs,
// téléphone (785 × 392) et écran TV (960 × 540), au début, en cours, à la
// fin et sur l'écran des résultats : aucune erreur d'affichage
// (débordement…) ni exception.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/match.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/ui/cricket_view.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

List<X01Player> players(int n, {bool teams = false}) => [
      for (var i = 0; i < n; i++)
        X01Player(
            id: 'guest-${i + 1}',
            name: i == 0 ? 'Jean-Christophe' : 'Joueur ${i + 1}',
            team: teams ? i % 2 : 0),
    ];

/// Fléchette au hasard, avec une préférence pour les zones visées.
DartHit? randomDart(DartsGame g, Random r) {
  if (r.nextInt(8) == 0) return null;
  if (g is PracticeGame && g.targetZones.isNotEmpty && r.nextBool()) {
    return g.targetZones[r.nextInt(g.targetZones.length)];
  }
  final n = r.nextInt(22);
  if (n >= 20) {
    return n == 20
        ? const DartHit(25, 1, Ring.outerBull)
        : const DartHit(25, 2, Ring.innerBull);
  }
  return switch (r.nextInt(4)) {
    0 => DartHit(n + 1, 3, Ring.triple),
    1 => DartHit(n + 1, 2, Ring.double),
    2 => DartHit(n + 1, 1, Ring.singleInner),
    _ => DartHit(n + 1, 1, Ring.singleOuter),
  };
}

/// Fait avancer la partie de [steps] actions (fléchettes, suivant).
void play(DartsGame g, Random r, int steps) {
  for (var i = 0; i < steps && !g.finished; i++) {
    if (g.turnOver) {
      g.next();
    } else {
      g.throwDart(randomDart(g, r));
    }
  }
}

/// Toutes les parties à essayer : (nom, fabrique).
List<(String, DartsGame Function())> configs() {
  final out = <(String, DartsGame Function())>[];
  for (final n in [1, 2, 4, 8]) {
    out.add(('501 x$n', () => X01Game(const X01Settings(), players(n))));
  }
  out.add((
    'Freeze 4',
    () => X01Game(const X01Settings(freeze: true), players(4, teams: true))
  ));
  out.add((
    'Double 501',
    () => X01Game(const X01Settings(doubles: true), players(4, teams: true))
  ));
  out.add((
    '301 double in, limite 10',
    () => X01Game(
        const X01Settings(
            startScore: 301, inRule: InRule.double, roundLimit: 10),
        players(2))
  ));
  for (final v in CricketVariant.values) {
    for (final n in [2, 4, 10]) {
      out.add((
        'Cricket ${v.name} x$n',
        () => CricketGame(CricketSettings(variant: v), players(n))
      ));
    }
  }
  out.add((
    'Team Cricket 4',
    () =>
        CricketGame(const CricketSettings(teams: true), players(4, teams: true))
  ));
  for (final n in [2, 4]) {
    out.add(('Match x$n', () => MatchGame(const MatchSettings(), players(n))));
  }
  for (final k in PracticeKind.values) {
    final info = kPracticeInfo[k]!;
    final counts = <int>{
      max(1, info.minPlayers),
      if (info.maxPlayers >= 4 && info.minPlayers <= 4) 4,
      info.maxPlayers.clamp(1, 8),
    };
    for (final n in counts) {
      out.add((
        '${info.name} x$n',
        () => PracticeGame(PracticeSettings(k), players(n))
      ));
    }
  }
  return out;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
  });

  Future<List<String>> sweep(WidgetTester tester,
      {required Size size, required double ratio, required bool tv}) async {
    tester.view.physicalSize = size * ratio;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final errors = <String>[];
    final client = TvClient(realtime: false);
    for (final style in [CricketStyle.classic, CricketStyle.columns]) {
      CricketStyle.current.value = style;
      for (final (name, make) in configs()) {
        if (style == CricketStyle.columns &&
            !name.contains('Cricket') &&
            !name.startsWith('Match')) {
          continue;
        }
        final g = make();
        final r = Random(name.hashCode);
        for (final steps in [0, 4, 23, 80, 100000]) {
          play(g, r, steps);
          final label = '$name $style après $steps (${tv ? 'TV' : 'tél.'})';
          try {
            if (tv) {
              client.debugSetState('ABCD', {
                'screen': g.finished ? 'results' : 'game',
                'host': 'Foc',
                'game': g.toJson(),
                'sound': false,
                'at': DateTime.now().microsecondsSinceEpoch,
              });
              await tester.pumpWidget(MaterialApp(
                  theme: Tv.theme(),
                  home: TvHome(key: ValueKey(label), client: client)));
            } else {
              final copy = gameFromJson(g.toJson());
              await tester.pumpWidget(MaterialApp(
                  theme: Tv.theme(),
                  home: copy.finished
                      ? resultsPageFor(copy)
                      : GamePage(key: ValueKey(label), game: copy)));
            }
            await tester.pump(const Duration(milliseconds: 600));
            final e = tester.takeException();
            if (e != null) {
              errors.add('$label : ${'$e'.split('\n').first}');
            }
          } catch (e) {
            errors.add('$label : $e');
          }
          if (g.finished) break;
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    CricketStyle.current.value = CricketStyle.classic;
    return errors;
  }

  testWidgets('Check-up téléphone : tous les jeux, sans erreur d\'affichage',
      (tester) async {
    final errors =
        await sweep(tester, size: const Size(785, 392), ratio: 2.75, tv: false);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Check-up écran TV : tous les jeux, sans erreur d\'affichage',
      (tester) async {
    final errors =
        await sweep(tester, size: const Size(960, 540), ratio: 1, tv: true);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
