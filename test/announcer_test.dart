import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_fx.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

const two = [
  X01Player(id: 'guest-1', name: 'Ana'),
  X01Player(id: 'guest-2', name: 'Bob', team: 1),
];

void main() {
  final audio = AudioService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    audio
      ..voice = true
      ..dartCalls = true
      ..said.clear();
    GameFx.session180 = 0;
    GameFx.sessionBestCheckout = 0;
  });

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: Tv.theme(), home: page));
    await tester.pump(const Duration(seconds: 1));
    audio.said.clear();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> dart(WidgetTester tester, int n, Ring r) async {
    BoardService.instance
        .injectFrame(GranBoardDecoder.frameFor(n, r)!.codeUnits);
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('SUIVANT'));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('01 : chaque fléchette puis le total', (tester) async {
    await open(tester,
        const GamePage(settings: X01Settings(startScore: 301), players: two));
    await dart(tester, 20, Ring.triple);
    await dart(tester, 16, Ring.double);
    expect(audio.said, ['triple 20', 'double 16']);
    await dart(tester, 5, Ring.singleOuter);
    expect(audio.said.last, '5, 97');
    await next(tester);
    expect(audio.said.last, startsWith('Bob, à toi'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('RATÉ').last);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(audio.said.last, 'raté, Aucun point');
    await close(tester);
  });

  testWidgets('01 : « il te reste 40, double 20 »', (tester) async {
    final g = X01Game(const X01Settings(startScore: 101), two);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    g.throwDart(const DartHit(1, 1, Ring.singleOuter));
    g.throwDart(null); // Ana : 40
    g.next();
    for (var i = 0; i < 3; i++) {
      g.throwDart(null);
    }
    await open(tester, GamePage(game: g));
    await next(tester);
    expect(audio.said.last, 'Ana, à toi. Il te reste 40, double 20');
    await close(tester);
  });

  testWidgets('Cricket : « plus que 15 et bull », fléchettes annoncées',
      (tester) async {
    final g = CricketGame(const CricketSettings(), two);
    // Ana ferme 20 à 16 : il reste le 15 et le bull
    for (final n in [20, 19, 18, 17, 16]) {
      g.throwDart(DartHit(n, 3, Ring.triple));
      g.throwDart(null);
      g.throwDart(null);
      g.next();
      g.throwDart(null);
      g.throwDart(null);
      g.throwDart(null);
      if (n != 16) g.next();
    }
    await open(tester, GamePage(game: g));
    await next(tester);
    expect(audio.said.last, 'Ana, à toi. Plus que 15 et bull');
    await dart(tester, 15, Ring.double);
    expect(audio.said.last, 'double 15');
    await close(tester);
  });

  testWidgets('Annonce des fléchettes coupée', (tester) async {
    audio.dartCalls = false;
    await open(tester,
        const GamePage(settings: X01Settings(startScore: 301), players: two));
    await dart(tester, 20, Ring.triple);
    expect(audio.said, isEmpty);
    await close(tester);
  });
}
