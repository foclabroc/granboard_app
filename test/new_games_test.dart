import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const ib = DartHit(25, 2, Ring.innerBull);
const two = [X01Player(id: 'a', name: 'A'), X01Player(id: 'b', name: 'B')];

void main() {
  group('Le Chat et la Souris', () {
    PracticeGame game({int lead = 5}) =>
        PracticeGame(PracticeSettings(PracticeKind.catMouse, goal: lead), two);

    test('la souris part devant, le chat la rattrape', () {
      final g = game(lead: 3);
      expect(g.targetLabel, '4'); // souris
      g.throwDart(null);
      g.next();
      expect(g.targetLabel, '1'); // chat
      g.throwDart(t(1)); // 1 → 4 : rattrapée (la souris est au 4)
      expect(g.finished, isTrue);
      expect(g.winners, [1]);
    });

    test('la souris s\'échappe au bull', () {
      final g = game();
      for (var i = 0; i < 6; i++) {
        // souris : 3 triples par tour, chat : rien
        final n = g.stateOf(0).step;
        if (n >= 20) {
          g.throwDart(ib);
        } else {
          g.throwDart(t(n + 1));
        }
        if (g.finished) break;
        g.next();
        g.next();
      }
      expect(g.finished, isTrue);
      expect(g.winners, [0]);
      expect(g.currentTurn.note, contains('SOURIS'));
    });

    test('20 manches : la souris gagne', () {
      final g = game();
      while (!g.finished) {
        g.next();
      }
      expect(g.winners, [0]);
    });

    test('rejeu identique (TV)', () {
      final g = game();
      for (final h in [s(6), d(7), null]) {
        g.throwDart(h);
      }
      g.next();
      g.throwDart(s(1));
      final c = PracticeGame.fromJson(g.toJson());
      expect(c.stateOf(0).step, g.stateOf(0).step);
      expect(c.stateOf(1).step, 1);
      expect(c.infoOf(1), 'CHAT · ÉCART 7');
    });
  });

  group('Contre la montre', () {
    late DateTime now;
    setUp(() {
      now = DateTime(2026, 11, 13, 12);
      PracticeGame.clock = () => now;
    });
    tearDown(() => PracticeGame.clock = DateTime.now);

    PracticeGame game(
            {int start = 301,
            List<X01Player> players = const [X01Player(id: 'a', name: 'A')]}) =>
        PracticeGame(
            PracticeSettings(PracticeKind.timeAttack, goal: start), players);

    void dart(PracticeGame g, DartHit? h, {int sec = 5}) {
      now = now.add(Duration(seconds: sec));
      g.throwDart(h);
    }

    test('chrono des tours, bust, fin au double', () {
      final g = game();
      dart(g, t(20)); // le chrono part à la 1re fléchette
      dart(g, t(20));
      dart(g, t(20)); // 121
      expect(g.stateOf(0).v['ms'], 10000);
      expect(g.actionLog.last, 't:10000');
      now = now.add(const Duration(seconds: 30)); // va chercher ses fléchettes
      g.next();
      dart(g, t(20)); // 61
      dart(g, t(20)); // 1 : bust
      expect(g.currentTurn.note, 'BUST');
      expect(g.scoreText(0), '121');
      expect(g.stateOf(0).v['ms'], 20000);
      g.next();
      dart(g, t(20)); // 61
      dart(g, s(1)); // 60
      expect(g.timeOf(0), 30000); // tour en cours compris
      dart(g, s(20)); // 40, fin du tour
      expect(g.actionLog.last.startsWith('t:'), isTrue);
      g.undo(); // retire le temps ET la fléchette
      expect(g.actionLog.last.startsWith('t:'), isFalse);
      expect(g.scoreText(0), '60');
      dart(g, d(20)); // 20
      expect(g.scoreText(0), '20');
      expect(g.finished, isFalse);
    });

    test('fin : temps, score = - secondes, rejeu', () {
      final g = game(start: 101);
      dart(g, t(20)); // 41
      dart(g, s(1)); // 40
      dart(g, d(20), sec: 3); // fini 8 s après la 1re fléchette
      expect(g.finished, isTrue);
      expect(g.stateOf(0).v['ms'], 8000);
      expect(g.stateOf(0).score, -8);
      expect(g.scoreText(0), '0:08,0');
      final c = PracticeGame.fromJson(g.toJson());
      expect(c.finished, isTrue);
      expect(c.stateOf(0).score, -8);
      expect(practiceScoreText('timeAttack', -83), '1:23');
      expect(practiceScoreText('timeAttack', -100000), '—');
    });

    test('à 2 : chacun son chrono, le plus rapide gagne', () {
      final g = game(start: 101, players: two);
      dart(g, t(20));
      dart(g, s(1));
      dart(g, d(20), sec: 20); // A : 25 s
      g.next();
      dart(g, t(20));
      dart(g, s(1));
      dart(g, d(20)); // B : 10 s
      expect(g.finished, isTrue);
      expect(g.winners, [1]);
    });
  });

  group('Paint', () {
    PracticeGame game() =>
        PracticeGame(const PracticeSettings(PracticeKind.paint), two);

    test('peindre, prendre, protéger', () {
      final g = game();
      g.throwDart(t(20)); // A peint T20
      g.throwDart(s(20)); // A peint le simple 20
      g.throwDart(const DartHit(20, 1, Ring.singleInner)); // même zone : protégée
      expect(g.stateOf(0).score, 2);
      expect(g.currentTurn.note, 'PROTÉGÉE');
      g.next();
      g.throwDart(t(20)); // B prend T20
      expect(g.currentTurn.note, 'ZONE PRISE');
      g.throwDart(s(20)); // protégée : rien
      g.throwDart(ib); // B peint le bull
      expect(g.stateOf(0).score, 1);
      expect(g.stateOf(1).score, 2);
      final z = g.painted;
      expect(z, hasLength(3));
      final single =
          z.firstWhere((p) => p.zones.length == 2 && !p.zones.first.isBull);
      expect(single.owner, 0);
      expect(single.locked, isTrue);
      expect(z.firstWhere((p) => p.zones.first.isBull).owner, 1);
      // rejeu identique (TV)
      final c = PracticeGame.fromJson(g.toJson());
      expect(c.stateOf(1).score, 2);
      expect(c.painted, hasLength(3));
    });

    test('10 manches puis le plus de zones gagne', () {
      final g = game();
      g.throwDart(t(20));
      while (!g.finished) {
        g.next();
      }
      expect(g.round, 10);
      expect(g.winners, [0]);
    });
  });

  group('Bowling', () {
    PracticeGame game() => PracticeGame(
        const PracticeSettings(PracticeKind.bowling),
        const [X01Player(id: 'a', name: 'A')]);

    test('quilles = points ÷ 6', () {
      final g = game();
      g.throwDart(s(20)); // 3 quilles
      expect(g.stateOf(0).score, 3);
      g.throwDart(d(20)); // 7 : spare
      expect(g.currentTurn.note, 'SPARE !');
      expect(g.turnOver, isTrue); // 2 fléchettes par frame
      g.next();
      g.throwDart(t(20)); // strike : frame fini, spare = 10 + 10
      expect(g.currentTurn.note, 'STRIKE !');
      expect(g.turnOver, isTrue);
      expect(g.stateOf(0).score, 30);
    });

    test('partie parfaite = 300, 3 fléchettes au 10e frame', () {
      final g = game();
      for (var f = 0; f < 9; f++) {
        g.throwDart(t(20));
        g.next();
      }
      g.throwDart(t(20));
      expect(g.turnOver, isFalse);
      g.throwDart(t(20));
      g.throwDart(t(20));
      expect(g.turnOver, isTrue);
      expect(g.stateOf(0).score, 300);
      g.next();
      expect(g.finished, isTrue);
    });

    test('frames sans quille, « suivant » tout de suite', () {
      final g = game();
      while (!g.finished) {
        g.next();
      }
      expect(g.stateOf(0).score, 0);
      expect(g.stateOf(0).darts, 20);
    });
  });
}
