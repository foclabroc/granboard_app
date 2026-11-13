import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/tv/next_up.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

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

  testWidgets('Ensuite : un pseudo long s\'affiche en entier sur la TV',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = 'Jean-Christophe le Magnifique';
    for (final title in ['501', 'Cut Throat caché']) {
      final g = title == '501'
          ? X01Game(const X01Settings(), const [
              X01Player(id: 'guest-1', name: 'Ced'),
              X01Player(id: 'guest-2', name: long),
            ])
          : CricketGame(
              const CricketSettings(variant: CricketVariant.hiddenCutThroat),
              const [
                  X01Player(id: 'guest-1', name: 'Ced'),
                  X01Player(id: 'guest-2', name: long),
                ]);
      final client = TvClient(realtime: false);
      client.debugSetState('ABCD', {
        'screen': 'game',
        'host': 'Foc',
        'game': g.toJson(),
        'sound': false,
      });
      await tester.pumpWidget(MaterialApp(
          theme: Tv.theme(),
          home: TvHome(key: ValueKey(title), client: client)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      // le nom entier est dans la pastille, sans « … »
      final text = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('next-up-name')),
          matching: find.byType(Text)));
      expect(text.data, long.toUpperCase());
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final box = tester.getSize(find.byKey(const ValueKey('next-up')));
      expect(box.width, greaterThan(200));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
