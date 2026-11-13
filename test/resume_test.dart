import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/game_save.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/home_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

X01Game newGame() => X01Game(const X01Settings(startScore: 301), const [
      X01Player(id: 'guest-1', name: 'Invité 1'),
      X01Player(id: 'guest-2', name: 'Invité 2'),
    ]);

void main() {
  late FakeServer server;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'welcome_done_v1': true});
    server = FakeServer()..install();
    GbServer.reachable.value = true;
    await PlayerStore.instance.load();
    await BoardService.instance.init();
  });

  test('Sauvegarde : rien tant qu\'aucune fléchette, puis la partie', () async {
    final g = newGame();
    await GameSave.save(g);
    expect(await GameSave.load(), isNull);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    await GameSave.save(g, tournament: {'uid': 'x', 'r': 0, 's': 1});
    final s = await GameSave.load();
    expect(s, isNotNull);
    expect((s!.game as X01Game).stateOf(0).remaining, 241);
    expect(s.tournament?['s'], 1);
    expect(s.summary, contains('INVITÉ 1'));
    await GameSave.clear();
    expect(await GameSave.load(), isNull);
  });

  testWidgets('Partie gardée après chaque action, effacée à l\'abandon',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: GamePage(game: newGame())));
    await frames(tester, 3);
    BoardService.instance.injectFrame('3.4@'.codeUnits); // T20
    await frames(tester, 3);
    final s = await GameSave.load();
    expect((s!.game as X01Game).stateOf(0).remaining, 241);

    // Abandon : plus rien à reprendre
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.maybePop();
    await frames(tester, 3);
    await tester.tap(find.text('Abandonner'));
    await frames(tester, 3);
    expect(await GameSave.load(), isNull);
  });

  testWidgets('Au lancement : REPRENDRE rouvre la partie où elle en était',
      (tester) async {
    await phone(tester);
    final g = newGame()..throwDart(const DartHit(20, 3, Ring.triple));
    await GameSave.save(g);
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    expect(find.text('Partie interrompue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-yes')));
    await frames(tester);
    expect(find.byType(GamePage), findsOneWidget);
    expect(find.text('241'), findsWidgets);
  });

  testWidgets('Au lancement : ABANDONNER efface la partie', (tester) async {
    await phone(tester);
    final g = newGame()..throwDart(const DartHit(20, 1, Ring.singleOuter));
    await GameSave.save(g);
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('resume-no')));
    await frames(tester);
    expect(find.byType(GamePage), findsNothing);
    expect(await GameSave.load(), isNull);
  });

  testWidgets('Hors ligne : pastille dans l\'accueil, partie gardée puis envoyée',
      (tester) async {
    await phone(tester);
    final store = PlayerStore.instance;
    await store.register('Foc', '1234');
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    expect(find.byKey(const ValueKey('net-pill')), findsNothing);

    server.offline = true;
    final g = X01Game(const X01Settings(startScore: 101), [
      X01Player(id: store.players.first.key, name: 'Foc'),
    ]);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    g.throwDart(const DartHit(19, 1, Ring.singleOuter));
    g.throwDart(const DartHit(11, 2, Ring.double));
    expect(g.finished, isTrue);
    expect(await store.recordX01(g), isFalse);
    await frames(tester);
    expect(GbServer.reachable.value, isFalse);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('net-pill')), matching: find.text('1')),
        findsOneWidget);

    // Le réseau revient : envoyée, la pastille disparaît
    server.offline = false;
    expect(await store.flush(), isTrue);
    await frames(tester);
    expect(store.pending, isEmpty);
    expect(find.byKey(const ValueKey('net-pill')), findsNothing);
  });
}
