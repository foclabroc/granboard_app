import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/bot.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

const arcade = [
  PracticeKind.tugOfWar,
  PracticeKind.vault,
  PracticeKind.fightClub,
  PracticeKind.connect4,
  PracticeKind.snakesLadders,
  PracticeKind.bowls,
  PracticeKind.conqueror,
  PracticeKind.testMatch,
  PracticeKind.snooker,
  PracticeKind.pool,
  PracticeKind.zombies,
];

List<X01Player> players(int n) => [
      for (var i = 0; i < n; i++)
        X01Player(id: 'guest-${i + 1}', name: 'J${i + 1}'),
    ];

PracticeGame game(PracticeKind k, int n,
        {int seed = 1, int? goal, int? rounds, Set<String> opt = const {}}) =>
    PracticeGame(
        PracticeSettings(k, seed: seed, goal: goal, rounds: rounds, options: opt),
        players(n));

DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
DartHit si(int n) => DartHit(n, 1, Ring.singleInner);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const bull = DartHit(25, 2, Ring.innerBull);
const b25 = DartHit(25, 1, Ring.outerBull);

void throws(PracticeGame g, List<DartHit?> hits) {
  for (final h in hits) {
    g.throwDart(h);
  }
}

int autoplay(PracticeGame g, {int limit = 6000, int seed = 3}) {
  final rnd = Random(seed);
  var n = 0;
  while (!g.finished && n < limit) {
    n++;
    if (g.turnOver || g.turnHits.length >= 12) {
      g.next();
    } else {
      g.throwDart(Bot.throwAt(Bot.aim(g, rnd), 0.07, rnd));
    }
  }
  return n;
}

void main() {
  test('Chaque jeu se termine avec des bots et se rejoue à l\'identique', () {
    for (final k in arcade) {
      final info = kPracticeInfo[k]!;
      for (final n in {max(1, info.minPlayers), min(4, info.maxPlayers)}) {
        for (final seed in [0, 5, 9]) {
          final g = game(k, n, seed: seed);
          autoplay(g, seed: seed);
          expect(g.finished, isTrue, reason: '${k.name} x$n graine $seed');
          expect(g.winners, isNotEmpty, reason: k.name);
          final copy = PracticeGame.fromJson(g.toJson());
          expect(copy.finished, isTrue, reason: '${k.name} rejoué');
          for (var i = 0; i < n; i++) {
            expect(copy.scoreText(i), g.scoreText(i), reason: k.name);
          }
          expect(copy.winners, g.winners, reason: k.name);
          // annulation : on revient à l'état d'avant
          final before = PracticeGame.fromJson({
            ...g.toJson(),
            'actions': g.actionLog.sublist(0, g.actionLog.length - 1),
          });
          g.undo();
          for (var i = 0; i < n; i++) {
            expect(g.scoreText(i), before.scoreText(i), reason: k.name);
          }
        }
      }
    }
  });

  test('Tir à la corde : chaque camp tire, le premier au but gagne', () {
    final g = game(PracticeKind.tugOfWar, 2, goal: 100);
    throws(g, [t(20), t(20), null]);
    expect(g.scoreText(0), '+100');
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
    final h = game(PracticeKind.tugOfWar, 4, goal: 100);
    throws(h, [t(20), null, null]);
    h.next();
    throws(h, [t(19), s(1), null]);
    expect(h.scoreText(1), '-2');
    expect(h.scoreText(3), '-2', reason: 'même camp');
  });

  test('Coffre-fort : 0 pile = coffre pillé, en dessous = alarme', () {
    final g = game(PracticeKind.vault, 1, seed: 4);
    final code = int.parse(g.targetLabel.split(' ').last);
    // descendre pile : la cible montre une fin en une fléchette
    if (code > 20) {
      final first = code - 20;
      g.throwDart(first <= 20 ? s(first) : t(first ~/ 3));
    }
    final left = int.parse(g.targetLabel.split(' ').last);
    expect(g.targetZones, isNotEmpty);
    g.throwDart(g.targetZones.firstWhere((z) => z.score == left,
        orElse: () => s(left)));
    expect(g.stateOf(0).score, code);
    expect(g.currentTurn.note, contains('PILLÉ'));
    g.next();
    throws(g, [bull, bull]);
    expect(g.currentTurn.note, 'ALARME !');
    expect(g.turnOver, isTrue);
  });

  test('Fight Club : frapper, se soigner, K.O.', () {
    final g = game(PracticeKind.fightClub, 2, goal: 60);
    final nums = fightNumbers(g);
    throws(g, [t(nums[1][0]), t(nums[1][1]), d(nums[0][0])]);
    expect(g.stateOf(1).score, 0);
    expect(g.stateOf(1).out, isTrue);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
    final h = game(PracticeKind.fightClub, 3, goal: 60);
    throws(h, [bull]);
    expect(h.stateOf(1).score, 50);
    expect(h.stateOf(2).score, 50);
  });

  test('Puissance 4 : colonnes, pile, alignement', () {
    expect(connect4Column(1), 0);
    expect(connect4Column(15), 0);
    expect(connect4Column(20), 5);
    expect(connect4Column(25), 6);
    final g = game(PracticeKind.connect4, 2);
    throws(g, [s(1), s(2), s(3)]);
    g.next();
    throws(g, [s(8), s(9), s(10)]);
    g.next();
    var (cells, line) = connect4State(g);
    expect(cells[35], 0, reason: 'colonne 1, en bas');
    expect(cells[28], 1, reason: 'posé au-dessus');
    g.throwDart(s(4));
    (cells, line) = connect4State(g);
    expect(line, isNotNull);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Serpents et échelles : anneaux, échelle, serpent, rebond', () {
    expect(snakesMoves(bull), 6);
    expect(snakesMoves(b25), 5);
    expect(snakesMoves(s(20)), 4);
    expect(snakesMoves(t(20)), 3);
    expect(snakesMoves(si(20)), 2);
    expect(snakesMoves(d(20)), 1);
    final g = game(PracticeKind.snakesLadders, 2);
    g.throwDart(s(1)); // 0 → 4 : échelle → 25
    expect(g.stateOf(0).score, 25);
    expect(g.currentTurn.note, contains('ÉCHELLE'));
    g.throwDart(si(1)); // 27 : serpent → 5
    expect(g.stateOf(0).score, 5);
  });

  test('Boules : la meilleure boule gagne la mène', () {
    final g = game(PracticeKind.bowls, 2, goal: 3);
    for (final (a, b) in [(bull, si(3)), (t(20), s(1)), (d(5), si(7))]) {
      g.throwDart(a);
      expect(g.turnOver, isTrue, reason: '1 fléchette par tour');
      g.next();
      g.throwDart(b);
      g.next();
    }
    // J1 : bull (0), triple (3), double (5) ; J2 : simples intérieurs (2)
    // → J1 gagne la mène, 1 boule plus près que 2 : +1
    expect(g.stateOf(0).score, 1);
    expect(g.stateOf(1).score, 0);
  });

  test('Conquérant : portée, prise, boucliers, vol', () {
    final g = game(PracticeKind.conqueror, 2, seed: 3);
    final (own, sh, reach) = conquerorState(g);
    final base0 = own.entries.firstWhere((e) => e.value == 0).key;
    final i = kArcadeBoardOrder.indexOf(base0);
    final next = kArcadeBoardOrder[(i + 1) % 20];
    expect(reach, contains(next));
    expect(reach, contains(25));
    g.throwDart(t(next)); // prise + 2 boucliers
    final (own2, sh2, _) = conquerorState(g);
    expect(own2[next], 0);
    expect(sh2[next], 2);
    final far = kArcadeBoardOrder[(i + 10) % 20];
    g.throwDart(s(far));
    expect(g.currentTurn.note, contains('HORS DE PORTÉE'));
    expect(g.stateOf(0).hits, 2);
  });

  test('Test Match : courses au-dessus de 40, guichets, 2 manches', () {
    final g = game(PracticeKind.testMatch, 2, goal: 3);
    throws(g, [t(20), t(19), s(1)]); // 118 → 78 courses
    g.next();
    expect(g.stateOf(0).score, 78);
    throws(g, [bull, b25, null]); // 3 guichets
    g.next();
    expect(testMatchState(g).$1, 2, reason: '2e manche');
    expect(testMatchState(g).$2, 1, reason: 'J2 au bâton');
    throws(g, [null, null, null]); // J1 lance, rien
    g.next();
    throws(g, [t(20), t(20), t(20)]); // 180 → 140 > 78
    g.next();
    expect(g.finished, isTrue);
    expect(g.winners, [1]);
  });

  test('Snooker : rouge, couleur, faute', () {
    final g = game(PracticeKind.snooker, 2);
    throws(g, [s(3), s(20), s(7)]);
    expect(g.stateOf(0).score, 1 + 6 + 1);
    g.next();
    g.throwDart(s(18)); // pas une rouge : faute
    expect(g.stateOf(0).score, 12);
    expect(g.turnOver, isTrue);
    expect(snookerState(g).$1.length, 13);
  });

  test('8 Ball Pool : la série continue, un raté l\'arrête, la 8 gagne', () {
    final g = game(PracticeKind.pool, 2);
    final mine = poolBalls(g)[0].map((b) => b.$1).toList();
    throws(g, [for (final n in mine) s(n)]);
    expect(g.turnOver, isFalse, reason: '7 billes de suite');
    g.throwDart(bull);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
    final h = game(PracticeKind.pool, 2);
    final his = poolBalls(h)[1].first.$1;
    h.throwDart(s(his));
    expect(h.turnOver, isTrue, reason: 'bille adverse');
  });

  test('Zombies : abattre, avancer, morsures', () {
    final g = game(PracticeKind.zombies, 1, goal: 20);
    var (z, hp) = zombiesState(g);
    expect(z, isNotEmpty);
    final first = z.first;
    final hit = first.n == 25
        ? (first.m == 2 ? bull : b25)
        : DartHit(first.n, first.m,
            first.m == 3 ? Ring.triple : first.m == 2 ? Ring.double : Ring.singleOuter);
    g.throwDart(hit);
    expect(g.stateOf(0).hits, 1);
    // laisser venir : 5 manches sans tirer, la base est mordue
    for (var i = 0; i < 6; i++) {
      g.next();
    }
    (z, hp) = zombiesState(g);
    expect(hp, lessThan(5));
  });
}
