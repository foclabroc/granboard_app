import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

DartHit s(int n) => DartHit(n, 1, Ring.singleOuter);
DartHit d(int n) => DartHit(n, 2, Ring.double);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const bull50 = DartHit(25, 2, Ring.innerBull);
const bull25 = DartHit(25, 1, Ring.outerBull);

X01Game game(X01Settings st, [int n = 2]) => X01Game(st, [
      for (var i = 0; i < n; i++) X01Player(id: 'p$i', name: 'J$i'),
    ]);

void main() {
  test('501 : score décompté et manche finie après 3 fléchettes', () {
    final g = game(const X01Settings());
    g.throwDart(t(20));
    g.throwDart(t(20));
    expect(g.turnOver, isFalse);
    g.throwDart(t(20));
    expect(g.stateOf(0).remaining, 321);
    expect(g.turnOver, isTrue);
    expect(g.throwDart(s(5)), isFalse, reason: '4e fléchette ignorée');
    expect(g.stateOf(0).count180, 1);
    g.next();
    expect(g.current, 1);
  });

  test('Bust par dépassement : retour au score de début de manche', () {
    final g = game(const X01Settings(startScore: 301));
    // Joueur 0 descend à 40
    for (final h in [t(20), t(20), t(20)]) {
      g.throwDart(h);
    }
    g.next();
    g.next(); // joueur 1 passe
    for (final h in [t(20), s(20), s(1)]) {
      g.throwDart(h);
    }
    expect(g.stateOf(0).remaining, 40);
    g.next();
    g.next();
    g.throwDart(s(20));
    g.throwDart(t(20)); // dépasse
    expect(g.currentTurn.bust, BustReason.overshoot);
    expect(g.stateOf(0).remaining, 40);
    expect(g.turnOver, isTrue);
  });

  test('Double Out : finir sur un simple = bust, sur un double = victoire', () {
    final g = game(const X01Settings(startScore: 301));
    for (final h in [t(20), t(20), t(20)]) {
      g.throwDart(h);
    }
    g.next();
    g.next();
    g.throwDart(t(20)); // reste 61
    g.next();
    g.next();
    g.throwDart(t(7)); // 40
    g.throwDart(s(20)); // 20
    g.throwDart(s(20)); // 0 sur un simple
    expect(g.currentTurn.bust, BustReason.badFinish);
    expect(g.stateOf(0).remaining, 61);
    g.next();
    g.next();
    g.throwDart(t(7));
    g.throwDart(d(20));
    expect(g.finished, isTrue);
    expect(g.winners, [0]);
    expect(g.stateOf(0).checkout, 61);
  });

  test('Double Out : reste 1 = bust', () {
    final g2 = game(const X01Settings(startScore: 301), 1);
    g2.throwDart(t(20));
    g2.throwDart(t(20));
    g2.throwDart(t(20));
    g2.next(); // 121
    g2.throwDart(t(20));
    g2.throwDart(t(20)); // 1
    expect(g2.currentTurn.bust, BustReason.leftOne);
    expect(g2.stateOf(0).remaining, 121);
  });

  test('Open Out : finir sur un simple est valide', () {
    final g =
        game(const X01Settings(startScore: 301, outRule: OutRule.open), 1);
    for (final h in [t(20), t(20), t(20)]) {
      g.throwDart(h);
    }
    g.next();
    for (final h in [t(20), t(20), s(1)]) {
      g.throwDart(h);
    }
    expect(g.finished, isTrue);
  });

  test('Double In : rien ne compte avant le premier double', () {
    final g = game(const X01Settings(inRule: InRule.double), 1);
    g.throwDart(t(20));
    expect(g.stateOf(0).remaining, 501);
    expect(g.stateOf(0).opened, isFalse);
    g.throwDart(d(10));
    expect(g.stateOf(0).opened, isTrue);
    g.throwDart(s(5));
    expect(g.stateOf(0).remaining, 501 - 20 - 5);
  });

  test('Master In : un triple ouvre', () {
    final g = game(const X01Settings(inRule: InRule.master), 1);
    g.throwDart(s(20));
    g.throwDart(t(1));
    expect(g.stateOf(0).remaining, 498);
  });

  test('Master Out : finir sur un triple', () {
    final g =
        game(const X01Settings(startScore: 301, outRule: OutRule.master), 1);
    for (final h in [t(20), t(20), t(20)]) {
      g.throwDart(h);
    }
    g.next();
    for (final h in [t(20), s(16), t(15)]) {
      g.throwDart(h);
    }
    expect(g.finished, isTrue);
  });

  test('Fat bull : le 25 vaut 50 et compte comme double', () {
    final g = game(const X01Settings(bullMode: BullMode.fat), 1);
    g.throwDart(bull25);
    expect(g.stateOf(0).remaining, 451);
    final g2 = game(const X01Settings(), 1);
    g2.throwDart(bull25);
    g2.throwDart(bull50);
    expect(g2.stateOf(0).remaining, 426);
  });

  test('Annuler : retire la dernière action', () {
    final g = game(const X01Settings());
    g.throwDart(t(20));
    g.throwDart(t(19));
    g.undo();
    expect(g.stateOf(0).remaining, 441);
    expect(g.currentTurn.darts.length, 1);
    g.throwDart(t(20));
    g.throwDart(t(20));
    g.next();
    g.undo();
    expect(g.current, 0);
    expect(g.turnOver, isTrue);
  });

  test('Joueur suivant avant 3 fléchettes : ratées comptées', () {
    final g = game(const X01Settings());
    g.throwDart(t(20));
    g.next();
    expect(g.stateOf(0).darts, 3);
    expect(g.stateOf(0).average, 60);
  });

  test('Limite de manches : le plus petit reste gagne', () {
    final g = game(const X01Settings(roundLimit: 2));
    g.throwDart(t(20));
    g.next();
    g.throwDart(s(1));
    g.next();
    g.throwDart(s(1));
    g.next();
    expect(g.finished, isFalse);
    g.throwDart(s(1));
    g.next();
    expect(g.finished, isTrue);
    expect(g.endReason, EndReason.roundLimit);
    expect(g.winners, [0]);
  });

  group('Freeze', () {
    X01Game freeze() => X01Game(
          const X01Settings(startScore: 301, freeze: true),
          const [
            X01Player(id: 'a1', name: 'A1', team: 0),
            X01Player(id: 'b1', name: 'B1', team: 1),
            X01Player(id: 'a2', name: 'A2', team: 0),
            X01Player(id: 'b2', name: 'B2', team: 1),
          ],
        );

    test('Une équipe en retard est gelée et ne peut pas finir', () {
      final g = freeze();
      // A1 : 301 → 121 → 61 (total A = 61 + 301 = 362)
      for (final h in [t(20), t(20), t(20)]) {
        g.throwDart(h);
      }
      g.next();
      // B1 : 301 → 121 (total B = 121 + 301 = 422)
      for (final h in [t(20), t(20), t(20)]) {
        g.throwDart(h);
      }
      g.next();
      g.next(); // A2 passe
      // B2 : 301 → 121 (total B = 242), A = 422 → A gelée
      for (final h in [t(20), t(20), t(20)]) {
        g.throwDart(h);
      }
      g.next();
      expect(g.current, 0);
      expect(g.isFrozen(0), isTrue);
      expect(g.isFrozen(1), isFalse);
      // A1 : 121 → T20 T7 D20 ferait 0 mais gelé = bust
      g.throwDart(t(20));
      g.throwDart(t(7));
      g.throwDart(d(20));
      expect(g.currentTurn.bust, BustReason.frozen);
      expect(g.stateOf(0).remaining, 121);
    });

    test('Équipe non gelée qui finit : toute l\'équipe gagne', () {
      final g = freeze();
      for (final h in [t(20), t(20), t(20)]) {
        g.throwDart(h); // A1 121
      }
      g.next();
      g.next(); // B1
      g.next(); // A2
      g.next(); // B2
      // A = 121 + 301 = 422, B = 602 : A pas gelée
      g.throwDart(t(20));
      g.throwDart(t(7));
      g.throwDart(d(20));
      expect(g.finished, isTrue);
      expect(g.winners, [0, 2]);
    });
  });

  group('Suggestion de fin', () {
    test('170 = T20 T20 BULL', () {
      expect(suggestCheckout(170, 3, OutRule.double, BullMode.split),
          ['T20', 'T20', 'BULL']);
    });
    test('40 = D20 en une fléchette', () {
      expect(suggestCheckout(40, 1, OutRule.double, BullMode.split), ['D20']);
    });
    test('169 impossible en Double Out', () {
      expect(suggestCheckout(169, 3, OutRule.double, BullMode.split), isNull);
    });
    test('Pas de suggestion si plus assez de fléchettes', () {
      expect(suggestCheckout(100, 1, OutRule.double, BullMode.split), isNull);
    });
  });

  test('Rejeu : une partie sérialisée redonne exactement le même état', () {
    final g = X01Game(
        const X01Settings(startScore: 301, freeze: true, roundLimit: 10),
        const [
          X01Player(id: '1', name: 'A1', team: 0),
          X01Player(id: '2', name: 'B1', team: 1),
          X01Player(id: '3', name: 'A2', team: 0),
          X01Player(id: '4', name: 'B2', team: 1),
        ]);
    g.throwDart(t(20));
    g.throwDart(null);
    g.throwDart(bull50);
    g.next();
    g.throwDart(d(16));
    g.next();
    final copy = X01Game.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(g.toJson())) as Map));
    expect(copy.actionCount, g.actionCount);
    expect(copy.current, g.current);
    expect(copy.settings.freeze, isTrue);
    for (var i = 0; i < 4; i++) {
      expect(copy.stateOf(i).remaining, g.stateOf(i).remaining);
      expect(copy.players[i].team, g.players[i].team);
    }
    expect(copy.currentTurn.darts.length, g.currentTurn.darts.length);
  });
}
