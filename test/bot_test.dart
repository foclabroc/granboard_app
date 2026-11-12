import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/bot.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/match.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

const bots = [
  X01Player(id: 'guest-bot1', name: 'Bot 1'),
  X01Player(id: 'guest-bot2', name: 'Bot 2', team: 1),
];

/// Fait jouer des bots jusqu'au bout (sans écran) ; renvoie le nombre
/// d'actions.
int autoplay(DartsGame g, {int limit = 4000}) {
  final rnd = Random(3);
  var n = 0;
  while (!g.finished && n < limit) {
    n++;
    if (g.turnOver ||
        (g is MatchGame && g.betweenLegs) ||
        g.turnHits.length >= 12) {
      g.next();
    } else {
      final s = Bot.sigmaNow(g, (_) => 8);
      g.throwDart(Bot.throwAt(Bot.aim(g, rnd), s, rnd));
    }
  }
  return n;
}

void main() {
  test('Zones de la cible : le point visé tombe dans sa zone', () {
    for (final n in kBoardOrder) {
      for (final h in [
        DartHit(n, 3, Ring.triple),
        DartHit(n, 2, Ring.double),
        DartHit(n, 1, Ring.singleOuter),
        DartHit(n, 1, Ring.singleInner),
      ]) {
        final p = Bot.aimPoint(h);
        final z = Bot.zoneAt(p.x, p.y)!;
        expect((z.number, z.ring), (n, h.ring));
      }
    }
    expect(Bot.zoneAt(0, 0)!.ring, Ring.innerBull);
    expect(Bot.zoneAt(1.2, 0), isNull);
  });

  test('Étalonnage : la dispersion donne la moyenne voulue', () {
    for (final ppr in [25.0, 45.0, 60.0, 80.0, 110.0]) {
      final s = Bot.sigmaFor(ppr);
      final rnd = Random(11);
      var pts = 0;
      const n = 6000;
      for (var i = 0; i < n; i++) {
        pts +=
            Bot.throwAt(const DartHit(20, 3, Ring.triple), s, rnd)?.score ?? 0;
      }
      expect(pts * 3 / n, closeTo(ppr, ppr * 0.12), reason: 'PPR $ppr');
    }
    expect(Bot.sigmaFor(2.0, cricket: true),
        lessThan(Bot.sigmaFor(1.0, cricket: true)));
  });

  test('Niveau : rang du joueur, puis ce qu\'il lance dans la partie', () {
    final g = X01Game(const X01Settings(startScore: 501), const [
      X01Player(id: 'guest-1', name: 'Invité'),
      X01Player(id: 'guest-bot1', name: 'Bot', team: 1),
    ]);
    final (p0, _) = Bot.target(g, (id) => 10); // note 10 = A (~82 PPR)
    expect(p0, closeTo(82, 1));
    final (pg, _) = Bot.target(g, (id) => null); // invité ≈ 40
    expect(pg, closeTo(40, 1));
    // l'invité lance très faible pendant 6 manches
    for (var i = 0; i < 6; i++) {
      g.throwDart(const DartHit(1, 1, Ring.singleOuter));
      g.throwDart(const DartHit(5, 1, Ring.singleOuter));
      g.throwDart(null);
      g.next();
      g.throwDart(const DartHit(1, 1, Ring.singleOuter));
      g.throwDart(null);
      g.throwDart(null);
      g.next();
    }
    final (p1, _) = Bot.target(g, (id) => 10);
    expect(p1, lessThan(45), reason: 'le bot se cale sur le vrai niveau');
  });

  test('Les bots finissent tous les jeux', () {
    expect(autoplay(X01Game(const X01Settings(startScore: 501), bots)),
        lessThan(4000));
    expect(
        autoplay(X01Game(
            const X01Settings(startScore: 301, inRule: InRule.double), bots)),
        lessThan(4000));
    for (final v in CricketVariant.values) {
      final g = CricketGame(CricketSettings(variant: v, seed: 2), bots);
      autoplay(g);
      expect(g.finished, isTrue, reason: v.name);
    }
    final m = MatchGame(
        MatchSettings(legs: 3, pattern: MatchSettings.alternate(3)), bots);
    autoplay(m, limit: 12000);
    expect(m.finished, isTrue);
    for (final k in PracticeKind.values) {
      final info = kPracticeInfo[k]!;
      final players = [
        for (var i = 0; i < max(2, info.minPlayers); i++)
          X01Player(id: 'guest-bot${i + 1}', name: 'Bot ${i + 1}'),
      ];
      final g = PracticeGame(PracticeSettings(k, seed: 5), players);
      autoplay(g, limit: 6000);
      expect(g.finished, isTrue, reason: k.name);
    }
  });

  group('À l\'écran', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FakeServer().install();
      await PlayerStore.instance.load();
      await BoardService.instance.init();
    });

    testWidgets('Le bot joue sa manche tout seul, la cible est ignorée',
        (tester) async {
      tester.view.physicalSize = const Size(2160, 1080);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final g = X01Game(const X01Settings(startScore: 501), const [
        X01Player(id: 'guest-1', name: 'Moi'),
        X01Player(id: 'guest-bot1', name: 'Bot 1', team: 1),
      ]);
      await tester
          .pumpWidget(MaterialApp(theme: Tv.theme(), home: GamePage(game: g)));
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        BoardService.instance.injectFrame(
            GranBoardDecoder.frameFor(20, Ring.singleOuter)!.codeUnits);
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('SUIVANT'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(g.current, 1);
      // fléchette de l'humain pendant le tour du bot : ignorée
      BoardService.instance
          .injectFrame(GranBoardDecoder.frameFor(20, Ring.triple)!.codeUnits);
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.turnHits, isEmpty);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(g.current, 0, reason: 'le bot a joué puis passé la main');
      expect(g.stateOf(1).darts, 3);

      // annuler revient à ma manche (avant « suivant »), pas à celle du bot
      await tester.tap(find.text('ANNULER'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(g.current, 0);
      expect(g.turnHits.length, 3);
      expect(g.stateOf(1).darts, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
