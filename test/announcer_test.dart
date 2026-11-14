import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_fx.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/players_page.dart';
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
      ..teasing = false
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

  testWidgets('01 : chaque fléchette puis ce qu\'il reste', (tester) async {
    await open(tester,
        const GamePage(settings: X01Settings(startScore: 301), players: two));
    await dart(tester, 20, Ring.triple);
    await dart(tester, 16, Ring.double);
    expect(audio.said, ['triple 20', 'double 16']);
    await dart(tester, 5, Ring.singleOuter);
    expect(audio.said.last, '5, Il reste 204');
    await next(tester);
    expect(audio.said.last, startsWith('Bob, à toi'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('RATÉ').last);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(audio.said.last, 'raté, Il reste 301');
    await close(tester);
  });

  testWidgets('Chambrage : tour à moins de 20, aucune marque, coupé',
      (tester) async {
    audio.teasing = true;
    GameFx.random = _Always1();
    addTearDown(() => GameFx.random = Random());
    await open(tester,
        const GamePage(settings: X01Settings(startScore: 301), players: two));
    await dart(tester, 1, Ring.singleOuter);
    await dart(tester, 2, Ring.singleOuter);
    await dart(tester, 3, Ring.singleOuter); // 6 points
    expect(audio.said.last, startsWith('3, Il reste 295, '));
    expect(kLowTeases.any(audio.said.last.endsWith), isTrue);
    await next(tester);
    // 60 points : pas de chambrage
    await dart(tester, 20, Ring.singleOuter);
    await dart(tester, 20, Ring.singleOuter);
    await dart(tester, 20, Ring.singleOuter);
    expect(audio.said.last, '20, Il reste 241');
    await close(tester);

    // Cricket : aucune marque
    await open(
        tester, GamePage(game: CricketGame(const CricketSettings(), two)));
    for (var i = 0; i < 3; i++) {
      await dart(tester, 2, Ring.singleOuter);
    }
    expect(audio.said.last, startsWith('2, Aucune marque, '));
    expect(kZeroMarkTeases.any(audio.said.last.endsWith), isTrue);
    await close(tester);

    // Coupé dans les réglages
    audio.teasing = false;
    await open(tester,
        const GamePage(settings: X01Settings(startScore: 301), players: two));
    for (var i = 0; i < 3; i++) {
      await dart(tester, 1, Ring.singleOuter);
    }
    expect(audio.said.last, '1, Il reste 298');
    await close(tester);
  });

  testWidgets('Finition 121 : ce qu\'il reste après 3 fléchettes',
      (tester) async {
    await open(
        tester,
        GamePage(
            game: PracticeGame(
                const PracticeSettings(PracticeKind.checkout121), two)));
    await dart(tester, 20, Ring.triple);
    await dart(tester, 1, Ring.singleOuter);
    await dart(tester, 20, Ring.singleOuter);
    expect(audio.said.last, '20, Il reste 40');
    await close(tester);
  });

  testWidgets('Annonce du tour : attend la fin de l\'annonce en cours',
      (tester) async {
    // « il reste … » encore à dire quand « suivant » arrive (joueur virtuel)
    audio.sayLater('20, Il reste 241', 1000);
    audio.turnCue('Bob, à toi');
    await tester.pump(const Duration(milliseconds: 600));
    expect(audio.said, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.said, ['20, Il reste 241']);
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.said, ['20, Il reste 241', 'Bob, à toi']);
    // le joueur a lancé avant : l'annonce du tour saute
    audio.said.clear();
    audio.sayLater('raté', 500);
    audio.turnCue('Ana, à toi');
    audio.cancelCue();
    await tester.pump(const Duration(seconds: 2));
    expect(audio.said, ['raté']);
  });

  test('Arrière-plan : plus aucune annonce, reprise au retour', () {
    audio.background = true;
    audio.say('triple 20');
    expect(audio.said, isEmpty);
    audio.background = false;
    audio.say('triple 20');
    expect(audio.said, ['triple 20']);
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

  test('Pseudos : une seule majuscule, prononciation choisie', () async {
    audio.pronunciations.clear();
    expect(audio.spokenName('CED'), 'Ced');
    expect(audio.spokenName('ced'), 'Ced');
    expect(audio.spokenName('Jean-LUC'), 'Jean-Luc');
    await audio.setPronunciation('Ced', 'Sède');
    expect(audio.spokenName('ced'), 'Sède');
    await audio.setPronunciation('ced', '');
    expect(audio.spokenName('ced'), 'Ced');
  });

  testWidgets('Fiche joueur : choisir la prononciation', (tester) async {
    audio.pronunciations.clear();
    final p = await PlayerStore.instance.register('ced', '1234');
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: PlayerDetailPage(player: p)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pronunciation')), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('PRONONCIATION : CED'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pronunciation')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pron-field')), 'Sède');
    await tester.tap(find.byKey(const ValueKey('pron-ok')));
    await tester.pumpAndSettle();
    expect(audio.spokenName('ced'), 'Sède');
    expect(find.text('PRONONCIATION : SÈDE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Tirage toujours à 1 : le chambrage passe (1 ≠ 0), 2e phrase de la liste.
class _Always1 implements Random {
  @override
  int nextInt(int max) => max > 1 ? 1 : 0;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => true;
}
