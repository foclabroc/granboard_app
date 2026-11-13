import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/tv/next_up.dart';

void main() {
  const two = [
    X01Player(id: 'guest-1', name: 'Ced'),
    X01Player(id: 'guest-2', name: 'Max'),
  ];

  test('Ensuite : le joueur suivant et ce qu\'il lui reste', () {
    final g = X01Game(const X01Settings(), two);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    var n = nextUp(g)!;
    expect(n.$1.name, 'Max');
    expect(n.$2, 'IL LUI RESTE 501');
    g.next();
    g.throwDart(const DartHit(19, 3, Ring.triple));
    n = nextUp(g)!;
    expect(n.$1.name, 'Ced');
    expect(n.$2, 'IL LUI RESTE 441');
    // la partie d'origine n'a pas bougé
    expect(g.current, 1);
    expect(g.currentTurn.darts.length, 1);
  });

  test('Ensuite : rien en solo ni à la fin', () {
    final solo = X01Game(const X01Settings(), two.take(1).toList());
    expect(nextUp(solo), isNull);
    final c = CricketGame(const CricketSettings(), two);
    expect(nextUp(c)!.$2, '0 PTS');
  });
}
