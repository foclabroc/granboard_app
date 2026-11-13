import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';

void main() {
  const players = [
    X01Player(id: 'a1', name: 'A1', team: 0),
    X01Player(id: 'b1', name: 'B1', team: 1),
    X01Player(id: 'a2', name: 'A2', team: 0),
    X01Player(id: 'b2', name: 'B2', team: 1),
  ];

  test('01 en double : score commun, bust et victoire d\'équipe', () {
    final g = X01Game(
        const X01Settings(startScore: 101, doubles: true), players);
    expect(g.settings.name, 'Double 101');
    g.throwDart(const DartHit(20, 3, Ring.triple)); // A1 : 41
    expect(g.stateOf(0).remaining, 41);
    expect(g.stateOf(2).remaining, 41); // A2 aussi
    expect(g.stateOf(1).remaining, 101);
    g.next();
    g.next(); // B1 rien
    // A2 : bust (dépasse), l'équipe revient à 41
    g.throwDart(const DartHit(20, 3, Ring.triple));
    expect(g.currentTurn.isBust, isTrue);
    expect(g.stateOf(0).remaining, 41);
    expect(g.stateOf(2).remaining, 41);
    g.next();
    g.next(); // B2 rien
    // A1 : 1 + D20 = fin pour l'équipe A
    g.throwDart(const DartHit(1, 1, Ring.singleOuter));
    g.throwDart(const DartHit(20, 2, Ring.double));
    expect(g.finished, isTrue);
    expect(g.winners, [0, 2]);
    // chacun garde ses propres points
    expect(g.stateOf(0).points, 101);
    expect(g.stateOf(2).points, 0);
    // rejoué depuis le JSON
    final back = X01Game.fromJson(g.toJson());
    expect(back.settings.doubles, isTrue);
    expect(back.winners, [0, 2]);
  });
}
