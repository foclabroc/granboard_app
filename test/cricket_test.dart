import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

DartHit t(int n) => DartHit(n, 3, Ring.triple);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
const bull = DartHit(25, 2, Ring.innerBull);
const outer = DartHit(25, 1, Ring.outerBull);

const two = [
  X01Player(id: 'a', name: 'A', team: 0),
  X01Player(id: 'b', name: 'B', team: 1),
];

CricketGame game(CricketVariant v,
        {List<X01Player> players = two,
        bool teams = false,
        int? rounds = 20,
        int seed = 1}) =>
    CricketGame(
        CricketSettings(
            variant: v, teams: teams, roundLimit: rounds, seed: seed),
        players);

/// Joue une manche complète (fléchettes puis « suivant »).
void turn(CricketGame g, List<DartHit?> darts) {
  for (final x in darts) {
    g.throwDart(x);
  }
  if (!g.finished) g.next();
}

void main() {
  test('Standard : un triple ferme, puis les points comptent', () {
    final g = game(CricketVariant.standard);
    turn(g, [t(20), t(20), s(19)]);
    expect(g.marksOf(0, 0), 3);
    expect(g.scoreOf(0), 60);
    expect(g.marksOf(0, 1), 1);
    expect(g.statsOf(0).marks, 7);
    // B ferme le 20 : A ne marque plus dessus
    turn(g, [t(20), null, null]);
    turn(g, [t(20), null, null]);
    expect(g.scoreOf(0), 60);
    expect(g.dead(0), isTrue);
  });

  test('Bull : 25 = 1 marque, 50 = 2 marques', () {
    final g = game(CricketVariant.standard);
    turn(g, [outer, bull, bull]);
    expect(g.marksOf(0, 6), 3);
    expect(g.scoreOf(0), 50); // 1 marque en trop × 25 + … = 2 - 0 → 50
  });

  test('Standard : tout fermer avec le meilleur score gagne', () {
    final g = game(CricketVariant.standard);
    turn(g, [t(20), t(19), t(18)]);
    turn(g, [null, null, null]);
    turn(g, [t(17), t(16), t(15)]);
    turn(g, [null, null, null]);
    g.throwDart(bull);
    expect(g.finished, isFalse);
    g.throwDart(outer);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
    expect(g.endReason, CricketEnd.closed);
  });

  test('Standard : tout fermé mais moins de points = pas encore gagné', () {
    final g = game(CricketVariant.standard);
    turn(g, [null, null, null]);
    turn(g, [t(20), t(20), t(20)]); // B : 120
    for (final n in [20, 19, 18]) {
      g.throwDart(t(n));
    }
    g.next();
    turn(g, [null, null, null]);
    turn(g, [t(17), t(16), t(15)]);
    turn(g, [null, null, null]);
    g.throwDart(bull);
    g.throwDart(outer);
    expect(g.allClosed(0), isTrue);
    expect(g.finished, isFalse);
  });

  test('Cut Throat : les points vont aux adversaires, le plus petit gagne', () {
    const three = [
      X01Player(id: 'a', name: 'A'),
      X01Player(id: 'b', name: 'B'),
      X01Player(id: 'c', name: 'C'),
    ];
    final g = game(CricketVariant.cutThroat, players: three);
    turn(g, [t(20), t(20), null]);
    expect(g.scoreOf(0), 0);
    expect(g.scoreOf(1), 60);
    expect(g.scoreOf(2), 60);
    turn(g, [t(20), null, null]); // B ferme : il ne reçoit plus
    turn(g, [null, null, null]);
    turn(g, [s(20), null, null]);
    expect(g.scoreOf(1), 60);
    expect(g.scoreOf(2), 80);
  });

  test('Cut Throat : spoiler quand un adversaire a tout fermé avec moins', () {
    const three = [
      X01Player(id: 'a', name: 'A'),
      X01Player(id: 'b', name: 'B'),
      X01Player(id: 'c', name: 'C'),
    ];
    final g = game(CricketVariant.cutThroat, players: three);
    turn(g, [null, null, null]); // A
    turn(g, [null, null, null]); // B
    turn(g, [t(20), null, null]); // C ferme le 20
    turn(g, [t(20), t(20), null]); // A : +60 pour B seulement
    turn(g, [t(20), t(19), t(18)]); // B
    turn(g, [t(19), null, null]); // C ferme le 19
    turn(g, [null, null, null]); // A
    turn(g, [t(17), t(16), t(15)]); // B
    turn(g, [t(19), t(19), null]); // C : +114 pour A (B a fermé le 19)
    turn(g, [null, null, null]); // A
    g.throwDart(bull);
    g.throwDart(outer); // B a tout fermé avec 60, mais C a 0
    expect(g.allClosed(1), isTrue);
    expect(g.finished, isFalse);
    expect(g.scoreOf(0), 114);
    expect(g.isSpoiler(0), isTrue); // A ne peut plus passer sous B
    expect(g.isSpoiler(2), isFalse);
  });

  test('Team : marques et score communs à l\'équipe', () {
    const four = [
      X01Player(id: 'a1', name: 'A1', team: 0),
      X01Player(id: 'b1', name: 'B1', team: 1),
      X01Player(id: 'a2', name: 'A2', team: 0),
      X01Player(id: 'b2', name: 'B2', team: 1),
    ];
    final g = game(CricketVariant.standard, players: four, teams: true);
    turn(g, [s(20), null, null]);
    turn(g, [null, null, null]);
    turn(g, [d(20), s(20), null]); // A2 termine la fermeture et marque 20
    expect(g.sides, [0, 1]);
    expect(g.marksOf(0, 0), 3);
    expect(g.scoreOf(0), 20);
    expect(g.statsOf(2).points, 20);
  });

  test('Triple Only : seuls les triples comptent, pas de bull', () {
    final g = game(CricketVariant.tripleOnly);
    expect(g.targets.length, 6);
    turn(g, [s(20), d(20), bull]);
    expect(g.marksOf(0, 0), 0);
    turn(g, [null, null, null]);
    turn(g, [t(20), t(20), null]);
    expect(g.scoreOf(0), 60);
  });

  test('No Score : pas de points, le premier qui ferme tout gagne', () {
    final g = game(CricketVariant.noScore);
    turn(g, [t(20), t(20), t(19)]);
    expect(g.scoreOf(0), 0);
    turn(g, [null, null, null]);
    turn(g, [t(18), t(17), t(16)]);
    turn(g, [null, null, null]);
    g.throwDart(t(15));
    g.throwDart(bull);
    g.throwDart(outer);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Caché : 7 cibles cachées, une touche les découvre', () {
    final g = game(CricketVariant.hidden, seed: 42);
    expect(g.targets.length, 7);
    expect(g.targets.every((x) => !x.revealed), isTrue);
    final n = g.targets.first.number;
    final hit = n == 25 ? bull : t(n);
    g.throwDart(hit);
    expect(g.targets.first.revealed, isTrue);
    expect(g.currentTurn.darts.last.revealed, isTrue);
    expect(g.marksOf(0, 0), n == 25 ? 2 : 3);
    // Même graine = mêmes cibles
    final g2 = game(CricketVariant.hidden, seed: 42);
    expect([for (final x in g2.targets) x.number],
        [for (final x in g.targets) x.number]);
  });

  test('Wildcard : les numéros non marqués changent à chaque manche', () {
    final g = game(CricketVariant.wildcard, seed: 7);
    final first = [for (final x in g.targets) x.number];
    expect(first.last, 25);
    expect(first.take(6).every((n) => n >= 7 && n <= 20), isTrue);
    final kept = first[0];
    g.throwDart(s(kept));
    g.next();
    var changed = false;
    for (var r = 0; r < 5; r++) {
      g.next();
      g.next();
      final now = [for (final x in g.targets) x.number];
      expect(now[0], kept); // marqué : ne bouge plus
      expect(now.toSet().length, 7);
      if (now.skip(1).take(5).join() != first.skip(1).take(5).join()) {
        changed = true;
      }
    }
    expect(changed, isTrue);
  });

  test('Limite de manches : plus haut score (Cut Throat : plus bas)', () {
    final g = game(CricketVariant.standard, rounds: 1);
    turn(g, [t(20), s(20), null]);
    turn(g, [t(19), null, null]);
    expect(g.finished, isTrue);
    expect(g.endReason, CricketEnd.roundLimit);
    expect(g.winners, [0]);

    final c = game(CricketVariant.cutThroat, rounds: 1);
    turn(c, [t(20), s(20), null]);
    turn(c, [t(19), null, null]);
    expect(c.winners, [0]); // B a reçu 20 points
  });

  test('Rejeu : JSON → même état, annuler retire la dernière action', () {
    final g = game(CricketVariant.hiddenCutThroat, seed: 3);
    for (var i = 0; i < 12; i++) {
      g.throwDart(i.isEven ? t(20 - i % 7) : bull);
      if (i % 3 == 2) g.next();
    }
    final copy = gameFromJson(g.toJson()) as CricketGame;
    expect(copy.actionLog, g.actionLog);
    for (final side in g.sides) {
      expect(copy.scoreOf(side), g.scoreOf(side));
    }
    expect([for (final x in copy.targets) '${x.number}${x.revealed}'],
        [for (final x in g.targets) '${x.number}${x.revealed}']);
    final before = g.actionLog.length;
    g.undo();
    expect(g.actionLog.length, before - 1);
  });

  test('X01 envoie son type au rejeu', () {
    final g = X01Game(const X01Settings(), two);
    g.throwDart(t(20));
    expect(gameFromJson(g.toJson()), isA<X01Game>());
  });
}
