import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_intro.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  final audio = AudioService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    audio
      ..voice = true
      ..turnNames = true
      ..said.clear();
    GameIntro.enabled = true;
    GameIntro.on.value = true;
  });
  tearDown(() => GameIntro.enabled = false);

  List<X01Player> players(int n) => [
        for (var i = 0; i < n; i++)
          X01Player(id: 'guest-${i + 1}', name: 'Joueur ${i + 1}')
      ];

  Future<void> open(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size * 2.75;
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: Tv.theme(), home: page));
  }

  for (final (n, size) in [
    (1, const Size(785, 392)),
    (4, const Size(785, 392)),
    (8, const Size(785, 392)),
    (8, const Size(960, 540)),
  ]) {
    testWidgets(
        'Intro : $n joueur(s) en ${size.width.toInt()} × '
        '${size.height.toInt()}, puis l\'annonce du 1er joueur', (t) async {
      final g = X01Game(const X01Settings(startScore: 501), players(n));
      await open(t, GamePage(game: g), size);
      await t.pump(const Duration(milliseconds: 100));
      expect(GameIntro.showing, isTrue);
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(t.takeException(), isNull);
      expect(find.text('ORDRE DE JEU'), findsOneWidget);
      expect(find.text('JOUEUR $n'), findsWidgets);
      expect(audio.said.where((s) => s.contains('à toi')), isEmpty,
          reason: 'l\'annonce attend la fin de l\'intro');
      await t.pump(const Duration(seconds: 2));
      expect(GameIntro.showing, isFalse);
      expect(audio.said.last, contains('Joueur 1, à toi'));
    });
  }

  testWidgets(
      'Intro passée au toucher ; coupée dans les réglages ; pas en '
      'reprise', (t) async {
    final g =
        PracticeGame(const PracticeSettings(PracticeKind.zombies), players(2));
    await open(t, GamePage(game: g), const Size(785, 392));
    await t.pump(const Duration(milliseconds: 500));
    expect(GameIntro.showing, isTrue);
    expect(IntroData.of(g).family, 'PARTY');
    expect(IntroData.of(g).count, '2 JOUEURS');
    await t.tapAt(const Offset(100, 100));
    await t.pump();
    expect(GameIntro.showing, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));

    await GameIntro.set(false);
    await open(t, GamePage(game: X01Game(const X01Settings(), players(2))),
        const Size(785, 392));
    await t.pump(const Duration(milliseconds: 300));
    expect(GameIntro.showing, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));

    await GameIntro.set(true);
    final started = X01Game(const X01Settings(), players(2))..throwDart(null);
    await open(t, GamePage(game: started), const Size(785, 392));
    await t.pump(const Duration(milliseconds: 300));
    expect(GameIntro.showing, isFalse, reason: 'partie reprise');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
