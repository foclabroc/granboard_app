import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
DartHit si(int n) => DartHit(n, 1, Ring.singleInner);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const ib = DartHit(25, 2, Ring.innerBull);
const ob = DartHit(25, 1, Ring.outerBull);

const one = [X01Player(id: 'a', name: 'A')];
const two = [X01Player(id: 'a', name: 'A'), X01Player(id: 'b', name: 'B')];
const three = [
  X01Player(id: 'a', name: 'A'),
  X01Player(id: 'b', name: 'B'),
  X01Player(id: 'c', name: 'C'),
];

PracticeGame game(PracticeKind k,
        {List<X01Player> players = two,
        int? rounds,
        int? goal,
        Set<String> options = const {}}) =>
    PracticeGame(
        PracticeSettings(k,
            rounds: rounds, goal: goal, options: options, seed: 7),
        players);

void turn(PracticeGame g, List<DartHit?> hits) {
  for (final h in hits) {
    g.throwDart(h);
  }
  if (!g.finished) g.next();
}

void main() {
  test('All Fives : multiple de 5 → total ÷ 5, dépasser = rien', () {
    final g = game(PracticeKind.allFives, players: one, goal: 51);
    turn(g, [t(20), t(20), s(5)]); // 125 → +25
    expect(g.stateOf(0).score, 25);
    turn(g, [t(20), s(1), s(1)]); // 62 : non
    expect(g.stateOf(0).score, 25);
    turn(g, [t(20), t(20), t(20)]); // 180 → +36 → trop
    expect(g.stateOf(0).score, 25);
    turn(g, [t(20), t(20), d(5)]); // 130 → +26 → 51
    expect(g.finished, isTrue);
  });

  test('Kick Down : même score qu\'un adversaire = retour à 0, over = pénalité',
      () {
    final g = game(PracticeKind.kickDown, goal: 301);
    turn(g, [t(20), null, null]); // A 60
    g.throwDart(t(20)); // B 60 → A à 0
    expect(g.stateOf(0).score, 0);
    expect(g.stateOf(1).score, 60);
    g.next();
    for (var i = 0; i < 3; i++) {
      turn(g, [t(20), t(20), null]); // A : 120, 240…
      turn(g, [null, null, null]);
    }
    // A : 240 au début de la manche, 240 + 60 + 60 > 301 → -100
    expect(g.stateOf(0).score, 140);
  });

  test('Shanghai : simple + double + triple du numéro = victoire', () {
    final g = game(PracticeKind.shanghai);
    turn(g, [s(1), d(1), null]); // A : 3
    turn(g, [s(1), d(1), t(1)]); // B : Shanghai
    expect(g.finished, isTrue);
    expect(g.winners, [1]);
  });

  test('Hyper Bull : intérieur 50, bull 75, centre 100', () {
    final g = game(PracticeKind.hyperBull, players: one);
    turn(g, [si(3), ob, ib]);
    expect(g.stateOf(0).score, 225);
    turn(g, [t(20), s(20), null]); // extérieur : normal
    expect(g.stateOf(0).score, 305);
  });

  test('Baseball : manche n = le n, égalité = manche en plus', () {
    final g = game(PracticeKind.baseball);
    for (var i = 1; i <= 9; i++) {
      turn(g, [s(i), null, null]);
      turn(g, [s(i), null, null]);
    }
    expect(g.finished, isFalse); // 9 partout
    expect(g.round, 10);
    turn(g, [t(10), null, null]);
    turn(g, [null, null, null]);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Killer : 3 vies = killer, puis élimine', () {
    final g = game(PracticeKind.killer);
    final na = (g.rules as dynamic).numberOf(g, 0) as int;
    final nb = (g.rules as dynamic).numberOf(g, 1) as int;
    turn(g, [t(na), null, null]); // A killer
    expect(g.stateOf(0).v['killer'], 1);
    turn(g, [s(nb), null, null]); // B : 1 vie
    turn(g, [s(nb), s(nb), null]); // B : 0 vie puis éliminé
    expect(g.stateOf(1).out, isTrue);
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Beyond Top : battre le précédent, sinon une vie en moins', () {
    final g = game(PracticeKind.beyondTop);
    turn(g, [t(20), null, null]); // A : 60 > 30 → +3
    expect(g.stateOf(0).score, 3);
    turn(g, [s(20), null, null]); // B : 20 < 60 → -1 vie
    expect(g.stateOf(1).lives, 5);
  });

  test('Two Line : prendre, marquer, libérer, reprendre', () {
    final g = game(PracticeKind.twoLine);
    g.throwDart(s(20)); // A prend le 20
    g.throwDart(s(20)); // A marque 20
    expect(g.stateOf(0).score, 20);
    g.next();
    g.throwDart(s(20)); // B : 1 coup
    g.throwDart(s(20)); // B : libéré
    g.throwDart(t(20)); // B le prend
    final own = g.shared['own'] as Map<int, int>;
    expect(own[20], 1);
    expect(g.grid!.cells.length, 25);
  });

  test('Morpion : 4 marques prennent une case, 3 alignées gagnent', () {
    final g = game(PracticeKind.ticTacToe);
    final ns = (g.rules as dynamic).numbers() as List<int>;
    // A prend la 1re ligne (cases 0, 1, 2)
    for (final n in ns.take(3)) {
      turn(g, [t(n), s(n), null]);
      if (!g.finished) turn(g, [null, null, null]);
    }
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Cache-cache : ouvrir une fenêtre, trouver des animaux', () {
    final g = game(PracticeKind.hideAndSeek);
    final grid = g.grid!;
    final n = int.parse(grid.cells.first.label);
    g.throwDart(s(n));
    expect(g.grid!.cells.first.open, isTrue);
    expect(g.stateOf(0).score, isNot(0));
  });

  test('Fun Mission : réussir prend une vie à l\'adversaire', () {
    final g = game(PracticeKind.funMission);
    // On essaie toutes les fléchettes « fortes » : la mission tombe au hasard
    turn(g, [t(20), ib, d(5)]);
    final a = g.stateOf(0).lives, b = g.stateOf(1).lives;
    expect(a + b, 8);
  });

  test('Treasure Hunt : le bull fait passer le tour', () {
    final g = game(PracticeKind.treasureHunt, players: three);
    g.throwDart(ib);
    expect(g.turnOver, isTrue);
    g.next(); // B
    turn(g, [null, null, null]); // B
    turn(g, [null, null, null]); // C
    expect(g.current, 1); // A a passé son tour
  });

  test('Rejeu JSON identique pour tous les jeux de fête', () {
    for (final k in PracticeKind.values.where((k) => kPracticeInfo[k]!.party)) {
      final g = game(k);
      for (var i = 0; i < 6 && !g.finished; i++) {
        turn(g, [t(20), s(3), ib]);
      }
      final r =
          gameFromJson(jsonDecode(jsonEncode(g.toJson()))) as PracticeGame;
      for (var p = 0; p < 2; p++) {
        expect(r.stateOf(p).score, g.stateOf(p).score, reason: k.name);
        expect(r.stateOf(p).lives, g.stateOf(p).lives, reason: k.name);
      }
      while (g.canUndo) {
        g.undo();
      }
      expect(g.round, 1, reason: k.name);
    }
  });

  test('Golf : meilleure fléchette du trou, le plus petit total gagne', () {
    final g = game(PracticeKind.golf);
    turn(g, [s(1), t(1), null]); // A : 1 coup
    turn(g, [null, null, null]); // B : 5
    expect(g.stateOf(0).score, 1);
    expect(g.stateOf(1).score, 5);
    for (var i = 2; i <= 9; i++) {
      turn(g, [d(i), null, null]);
      turn(g, [s(i), null, null]);
    }
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Scram : A ferme, B marque, puis on échange', () {
    final g = game(PracticeKind.scram);
    turn(g, [s(20), s(19), s(18)]); // A ferme 20 19 18
    turn(g, [t(20), t(17), null]); // B : 20 fermé → rien, T17 = 51
    expect(g.stateOf(1).score, 51);
    turn(g, [s(17), s(16), s(15)]);
    turn(g, [null, null, null]); // B
    g.throwDart(ob); // A ferme le bull : tout fermé → partie 2
    expect(g.shared['phase'], 2);
    expect(g.turnOver, isTrue);
  });

  test('Football : bull = ballon, doubles = buts, manche sans but = ballon perdu',
      () {
    final g = game(PracticeKind.football, goal: 2);
    turn(g, [ib, d(5), null]); // A : ballon + 1 but
    expect(g.stateOf(0).score, 1);
    turn(g, [null, null, null]); // B
    turn(g, [s(3), null, null]); // A : pas de but → ballon perdu
    expect(g.shared['ball'], -1);
    turn(g, [ib, d(1), d(2)]); // B : 2 buts
    expect(g.finished, isTrue);
    expect(g.winners, [1]);
  });

  test('Patate chaude : toucher le numéro passe la bombe, mèche éteinte = -1 vie',
      () {
    final g = game(PracticeKind.hotPotato);
    final n = (g.rules as dynamic).number(g) as int;
    g.throwDart(s(n));
    expect(g.turnOver, isTrue);
    g.next();
    expect(g.current, 1); // B a la bombe
    for (var i = 0; i < 6 && g.stateOf(1).lives == 3; i++) {
      g.throwDart(null);
      if (g.turnOver) g.next();
    }
    expect(g.stateOf(1).lives, 2);
  });
}
