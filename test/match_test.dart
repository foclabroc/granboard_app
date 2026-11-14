import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/match.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

const t20 = DartHit(20, 3, Ring.triple);
DartHit t(int n) => DartHit(n, 3, Ring.triple);
const bull = DartHit(25, 2, Ring.innerBull);

const two = [
  X01Player(id: 'a', name: 'A'),
  X01Player(id: 'b', name: 'B'),
];

/// Le joueur en cours gagne le leg de Cricket (tout fermé) ; l'autre passe.
void winCricketLeg(MatchGame m) {
  final winner = m.currentPlayer.id;
  m.throwDart(t(20));
  m.throwDart(t(19));
  m.throwDart(t(18));
  m.next();
  m.next(); // adversaire : rien
  expect(m.currentPlayer.id, winner);
  m.throwDart(t(17));
  m.throwDart(t(16));
  m.throwDart(t(15));
  m.next();
  m.next();
  m.throwDart(bull);
  m.throwDart(const DartHit(25, 1, Ring.outerBull));
}

/// Le joueur en cours gagne un 301 Open Out (T20 T20 T20, T20 T20 D… ).
void winX01Leg(MatchGame m) {
  final winner = m.currentPlayer.id;
  m.throwDart(t20);
  m.throwDart(t20);
  m.throwDart(t20); // 121
  m.next();
  m.next(); // adversaire : rien
  expect(m.currentPlayer.id, winner);
  m.throwDart(t20); // 61
  m.throwDart(t(7)); // 40
  m.throwDart(const DartHit(20, 2, Ring.double)); // fin
}

MatchGame newMatch({int legs = 3, List<LegKind>? pattern}) => MatchGame(
    MatchSettings(
      legs: legs,
      pattern: pattern ?? MatchSettings.alternate(legs),
      x01: const X01Settings(startScore: 301),
      cricket: const CricketSettings(seed: 4),
    ),
    two);

void main() {
  test('Legs alternés 01 / Cricket, le premier à 2 legs gagne', () {
    final m = newMatch();
    expect(m.leg, isA<X01Game>());
    expect(m.currentPlayer.id, 'a');
    winX01Leg(m);
    expect(m.betweenLegs, isTrue);
    expect(m.finished, isFalse);
    expect(m.legWinsOf(0), 1);
    expect(m.throwDart(t20), isFalse); // leg fini : on attend « suivant »

    m.next(); // leg 2
    expect(m.legNumber, 2);
    expect(m.leg, isA<CricketGame>());
    expect(m.currentPlayer.id, 'b'); // B commence le leg 2
    winCricketLeg(m); // B gagne
    expect(m.legWinsOf(1), 1);

    m.next(); // leg 3 : A commence
    expect(m.leg, isA<X01Game>());
    expect(m.currentPlayer.id, 'a');
    winX01Leg(m);
    expect(m.finished, isTrue);
    expect(m.winners, [0]);
    expect(m.next(), isFalse);
  });

  test('Match gagné avant le dernier leg', () {
    final m = newMatch(legs: 5, pattern: List.filled(5, LegKind.x01));
    winX01Leg(m); // A
    m.next();
    m.next(); // B passe (il commence le leg 2)
    winX01Leg(m); // A
    m.next();
    winX01Leg(m); // A : 3 legs sur 5
    expect(m.finished, isTrue);
    expect(m.legNumber, 3);
    expect(m.winners, [0]);
  });

  test('Rejeu et annulation à travers les legs', () {
    final m = newMatch();
    winX01Leg(m);
    m.next();
    m.throwDart(t(20));
    final j = jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>;
    final r = gameFromJson(j) as MatchGame;
    expect(r.legNumber, 2);
    expect(r.legWinsOf(0), 1);
    expect(r.actionLog, m.actionLog);

    // Annuler : retire la fléchette, puis le passage au leg 2
    m.undo();
    m.undo();
    expect(m.legNumber, 1);
    expect(m.betweenLegs, isTrue);
    m.undo(); // la fléchette de la fin du leg 1
    expect(m.betweenLegs, isFalse);
    expect(m.legWinsOf(0), 0);
  });

  test('Medley : score de départ choisi leg par leg (301, Cricket, 501)', () {
    const st = MatchSettings(
      legs: 3,
      pattern: [LegKind.x01, LegKind.cricket, LegKind.x01],
      x01: X01Settings(startScore: 301),
      cricket: CricketSettings(seed: 4),
      starts: [301, 0, 501],
    );
    expect(st.patternLabel, '301-CR-501');
    final m = MatchGame(st, two);
    expect((m.leg as X01Game).settings.startScore, 301);
    winX01Leg(m);
    m.next();
    expect(m.leg, isA<CricketGame>());
    // l'autre joueur gagne le Cricket : 1-1, leg 3 en 501
    winCricketLeg(m);
    m.next();
    final leg3 = m.leg as X01Game;
    expect(leg3.settings.startScore, 501);
    expect(leg3.stateOf(0).remaining, 501);
    // TV / jeu à distance : le JSON garde les scores de chaque leg
    final copy = MatchGame.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect((copy.leg as X01Game).settings.startScore, 501);
    expect(copy.settings.patternLabel, '301-CR-501');
    // ancien JSON sans « starts » : tous les legs au score des règles 01
    final old = MatchSettings.fromJson(
        {'legs': 3, 'pattern': ['x01', 'cricket', 'x01'], 'x01': {'start': 701}});
    expect(old.patternLabel, '701-CR-701');
  });
}
