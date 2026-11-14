import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_lights.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

String hex(List<int> b) => b
    .map((x) => '0x${x.toRadixString(16).padLeft(2, '0').toUpperCase()}')
    .join(' ');

void main() {
  const two = [
    X01Player(id: 'guest-1', name: 'A'),
    X01Player(id: 'guest-2', name: 'B', team: 1),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    BoardLights.instance.debugReset();
    await BoardLights.instance.load();
  });

  test('Commandes identiques aux exemples du protocole', () {
    // touche D20 rouge (2 clignotements, LED 25)
    expect(
        hex(BoardLights.command(0x02,
            a: const Color(0xFFFF0000), pos: BoardLights.kLedPos[20]!)),
        '0x02 0xFF 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x19 0x00 0x14 0x00 0x00 0x00');
    // contour vert persistant
    expect(
        hex(BoardLights.command(0x14, a: const Color(0xFF00FF00), keep: true)),
        '0x14 0x00 0xFF 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x14 0x00 0x00 0x01');
    // vague rouge / bleu
    expect(
        hex(BoardLights.command(0x11,
            a: const Color(0xFFFF0000),
            b: const Color(0xFF0000FF),
            pos: 0x10,
            dur: 0x05)),
        '0x11 0xFF 0x00 0x00 0x00 0x00 0xFF 0x00 0x00 0x00 0x10 0x00 0x05 0x00 0x00 0x00');
  });

  test('Numéros à viser : Cricket, fin en 01', () {
    final c = CricketGame(const CricketSettings(), two);
    expect(BoardLights.targetsOf(c)..sort(), [15, 16, 17, 18, 19, 20]);
    for (var i = 0; i < 3; i++) {
      c.throwDart(const DartHit(20, 1, Ring.singleOuter));
    }
    c.next();
    c.throwDart(const DartHit(20, 3, Ring.triple));
    c.throwDart(const DartHit(19, 3, Ring.triple));
    c.throwDart(null);
    c.next();
    expect(BoardLights.targetsOf(c)..sort(), [15, 16, 17, 18, 19],
        reason: 'le 20 est fermé par tous');

    // 501 : pas de fin possible, le 20 reste allumé
    expect(BoardLights.targetsOf(X01Game(const X01Settings(), two)), [20]);

    final x = X01Game(const X01Settings(startScore: 101), two);
    expect(BoardLights.targetsOf(x), [17], reason: 'T17 puis bull');
    x.throwDart(const DartHit(20, 3, Ring.triple)); // reste 41
    expect(BoardLights.targetsOf(x), [9], reason: '9 puis D16');
  });

  testWidgets('Partie : contour, touche, numéros, extinction', (tester) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final lights = BoardLights.instance;
    lights.writer = (b) async {};
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: GamePage(game: CricketGame(const CricketSettings(), two))));
    await tester.pump(const Duration(seconds: 1));
    bool sentNumbers(List<int> ns) => lights.sent.any((b) =>
        b.length == 20 &&
        [
              for (var n = 1; n <= 20; n++)
                if (b[n - 1] == 5) n
            ].join(',') ==
            ns.join(','));
    expect(lights.sent.any((b) => b.length == 16 && b[0] == 0x14 && b[15] == 1),
        isTrue,
        reason: 'contour à la couleur du joueur');
    expect(sentNumbers([15, 16, 17, 18, 19, 20]), isTrue);

    BoardService.instance
        .injectFrame(GranBoardDecoder.frameFor(20, Ring.triple)!.codeUnits);
    await tester.pump(const Duration(seconds: 1));
    expect(lights.sent.any((b) => b[0] == 0x03 && b[10] == 25), isTrue,
        reason: 'T20 : 3 clignotements en face du 20');
    expect(sentNumbers([15, 16, 17, 18, 19]), isTrue);

    // après le clignotement de la touche, guides et contour renvoyés (la
    // cible les efface pendant son animation)
    final before = lights.sent.length;
    await tester.pump(BoardLights.reassertDelay);
    await tester.pump(const Duration(milliseconds: 300));
    final again = lights.sent.sublist(before);
    expect(again.any((b) => b.length == 16 && b[0] == 0x14), isTrue);
    expect(again.any((b) => b.length == 20 && b[19] == 5), isFalse);
    expect(again.any((b) => b.length == 20 && b[18] == 5), isTrue,
        reason: '19 encore à viser');

    // 3 fléchettes : les guides restent allumés jusqu'au joueur suivant
    for (var i = 0; i < 2; i++) {
      BoardService.instance
          .injectFrame(GranBoardDecoder.frameFor(19, Ring.triple)!.codeUnits);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(lights.sent.where((b) => b.length == 20).last.contains(5), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(lights.sent.last, List.filled(20, 0), reason: 'tout éteint');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Réglages coupés : rien n\'est envoyé pendant la partie',
      (tester) async {
    final lights = BoardLights.instance;
    await lights.setEnabled(false);
    await lights.setNumbers(false);
    lights.writer = (b) async {};
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: const GamePage(settings: X01Settings(), players: two)));
    await tester.pump(const Duration(seconds: 1));
    BoardService.instance
        .injectFrame(GranBoardDecoder.frameFor(20, Ring.triple)!.codeUnits);
    await tester.pump(const Duration(seconds: 1));
    expect(lights.sent, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
