import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const ib = DartHit(25, 2, Ring.innerBull);
const ob = DartHit(25, 1, Ring.outerBull);

const one = [X01Player(id: 'a', name: 'A')];
const two = [X01Player(id: 'a', name: 'A'), X01Player(id: 'b', name: 'B')];

PracticeGame game(PracticeKind k,
        {List<X01Player> players = one,
        int? rounds,
        int? goal,
        int target = 20,
        Set<String> options = const {}}) =>
    PracticeGame(
        PracticeSettings(k,
            rounds: rounds,
            goal: goal,
            target: target,
            options: options,
            seed: 7),
        players);

void turn(PracticeGame g, List<DartHit?> hits) {
  for (final h in hits) {
    g.throwDart(h);
  }
  if (!g.finished) g.next();
}

void main() {
  test('Count Up : total des points, 8 manches', () {
    final g = game(PracticeKind.countUp);
    turn(g, [t(20), t(20), ib]);
    expect(g.stateOf(0).score, 170);
    for (var i = 0; i < 7; i++) {
      turn(g, [s(1), null, null]);
    }
    expect(g.finished, isTrue);
    expect(g.stateOf(0).score, 177);
  });

  test('Target 20 : touches S1 D2 T3, le premier à l\'objectif gagne', () {
    final g = game(PracticeKind.target20, players: two, goal: 5);
    turn(g, [t(20), s(19), s(20)]); // A : 4
    turn(g, [t(20), null, null]); // B : 3
    g.throwDart(s(20)); // A : 5
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
  });

  test('Choix de cible : changer de cible avant la 1re fléchette', () {
    final g = game(PracticeKind.targetChoice, goal: 10, target: 20);
    expect(g.targetLabel, '20');
    expect(g.changeTarget(19), isTrue);
    g.throwDart(t(19));
    expect(g.stateOf(0).hits, 3);
    expect(g.changeTarget(5), isFalse); // trop tard dans la manche
    final r = gameFromJson(jsonDecode(jsonEncode(g.toJson())));
    expect((r as PracticeGame).stateOf(0).hits, 3);
  });

  test('Target Hat et Horse', () {
    final hat = game(PracticeKind.targetHat, goal: 1, target: 25);
    turn(hat, [ib, ob, ib]);
    expect(hat.finished, isTrue);
    final horse = game(PracticeKind.targetHorse, goal: 2);
    turn(horse, [t(20), t(20), t(19)]); // 2 fois le même : non
    expect(horse.stateOf(0).hits, 0);
    turn(horse, [t(20), t(19), t(18)]);
    expect(horse.stateOf(0).hits, 1);
  });

  test('Half It : départ 40, aucune touche = ÷ 2', () {
    final g = game(PracticeKind.halfIt);
    turn(g, [s(15), t(15), null]); // +60 → 100
    expect(g.stateOf(0).score, 100);
    turn(g, [s(1), s(2), s(3)]); // 16 raté → 50
    expect(g.stateOf(0).score, 50);
    expect(g.targetLabel, 'DOUBLES');
    turn(g, [d(5), null, null]); // +10
    expect(g.stateOf(0).score, 60);
  });

  test('Rotation : cible suivante, touche à la 3e = 3 fléchettes de plus', () {
    final g = game(PracticeKind.rotation);
    g.throwDart(s(5));
    g.throwDart(s(1));
    g.throwDart(s(2)); // touche à la 3e
    expect(g.turnOver, isFalse);
    expect(g.currentTurn.maxDarts, 6);
    expect(g.stateOf(0).score, 3);
    expect(g.targetLabel, '3');
  });

  test('Shoot Force : valeur × série, la série retombe sur un raté', () {
    final g = game(PracticeKind.shootForce);
    g.throwDart(s(1)); // 1 × 1
    g.throwDart(d(2)); // 4 × 2
    g.throwDart(null);
    expect(g.stateOf(0).score, 9);
    expect(g.stateOf(0).streak, 0);
  });

  test('Oniren : 2 simples + 1 double ou triple, sinon une vie en moins', () {
    final g = game(PracticeKind.oniren);
    final n = int.parse(g.targetLabel);
    turn(g, [s(n), d(n), s(n)]);
    expect(g.stateOf(0).score, 1);
    for (var i = 0; i < 3; i++) {
      turn(g, [null, null, null]);
    }
    expect(g.stateOf(0).out, isTrue);
    expect(g.finished, isTrue);
  });

  test('Bob\'s 27 : + valeur des doubles, - si aucune, Hard élimine', () {
    final g = game(PracticeKind.bobs27, options: {'hard'});
    turn(g, [d(1), d(1), null]); // +4 → 31
    expect(g.stateOf(0).score, 31);
    turn(g, [null, null, null]); // D2 raté : -4 → 27
    expect(g.stateOf(0).score, 27);
    for (var i = 0; i < 4; i++) {
      turn(g, [null, null, null]); // -6 -8 -10 → 3 puis -12 → éliminé
    }
    expect(g.stateOf(0).out, isTrue);
  });

  test('Finition 121 : réussi = +1, bust = retour au début de manche', () {
    final g = game(PracticeKind.checkout121);
    turn(g, [t(20), t(20), null]); // 121 → 1 ? non : 121-120 = 1 → bust
    expect(g.stateOf(0).v['rem'], 121);
    g.throwDart(t(20));
    g.throwDart(t(17)); // 121-60-51 = 10
    g.throwDart(d(5)); // fini
    expect(g.stateOf(0).v['target'], 122);
    expect(g.turnOver, isTrue);
  });

  test('CR Multiple : ×1 ×2 ×3 selon la fléchette, rien = -3 × cible', () {
    final g = game(PracticeKind.crMultiple);
    turn(g, [s(20), s(20), s(20)]); // 20 + 40 + 60
    expect(g.stateOf(0).score, 120);
    turn(g, [null, null, null]); // 19 raté : -57
    expect(g.stateOf(0).score, 63);
  });

  test('Spider : ramener à 0 pile abat l\'araignée', () {
    final g = game(PracticeKind.spider);
    final v = g.stateOf(0).v['rem']!;
    g.throwDart(s(20));
    g.throwDart(s(1));
    expect(g.stateOf(0).v['rem'], v - 21);
    final left = v - 21;
    g.throwDart(DartHit(left ~/ 2, 2, Ring.double)); // nombre pair : à 0 pile
    if (left.isEven && left <= 40) {
      expect(g.stateOf(0).hits, 1);
      expect(g.stateOf(0).v['rem'], greaterThan(40));
    }
  });

  test('Pirates : un navire tous les 200 points', () {
    final g = game(PracticeKind.pirates);
    turn(g, [ib, ib, ib]); // 150
    g.throwDart(ib); // 200 → navire 1
    expect(g.stateOf(0).hits, 1);
  });

  test('Rejeu JSON identique pour tous les jeux', () {
    for (final k in PracticeKind.values) {
      final g = game(k, players: two);
      for (var i = 0; i < 6 && !g.finished; i++) {
        turn(g, [t(20), s(1), ib]);
      }
      final r =
          gameFromJson(jsonDecode(jsonEncode(g.toJson()))) as PracticeGame;
      for (var p = 0; p < 2; p++) {
        expect(r.stateOf(p).score, g.stateOf(p).score, reason: k.name);
      }
      expect(r.actionLog, g.actionLog, reason: k.name);
      // Annuler tout redonne l'état de départ
      while (g.canUndo) {
        g.undo();
      }
      expect(g.round, 1, reason: k.name);
    }
  });
}
