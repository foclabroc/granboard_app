import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/online/online.dart';
import 'package:granboard_proto/online/relay.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/lobby_page.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75; // 785 × 392
  addTearDown(tester.view.reset);
}

void main() {
  late PlayerProfile foc, sophie, cid, leo;
  late OnlineService a, b, c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Relay.enabled = false;
    OnlineRoom.videoEnabled = false;
    Lobby.pollEnabled = false;
    FakeServer().install();
    final store = PlayerStore.instance;
    await store.load();
    await BoardService.instance.init();
    foc = await store.register('Foc', '1234');
    sophie = await store.register('Sophie', '1234');
    cid = await store.register('Cid', '1234');
    leo = await store.register('Léo', '1234');
    a = OnlineService.forAccount(foc);
    b = OnlineService.forAccount(sophie);
    c = OnlineService.forAccount(cid);
  });

  Map<String, dynamic> game501() =>
      X01Game(const X01Settings(), [X01Player(id: foc.key, name: 'Foc')])
          .toJson()
        ..['label'] = '501'
        ..['order'] = 'fixed';

  /// Salon de Foc (privé) avec Sophie (+ Léo chez elle) et Cid, 501 choisi.
  Future<(Lobby, Lobby, Lobby)> salon() async {
    for (final s in [a, b, c, a]) {
      await s.ping();
    }
    final la = await a.createLobby(false);
    expect(la.isHost, isTrue);
    await expectLater(c.joinLobby(la.id),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'lb_private')));
    await la.invite(a.players.firstWhere((p) => p.id == sophie.id));
    await la.invite(a.players.firstWhere((p) => p.id == cid.id));
    expect(la.invited.length, 2);
    await b.ping();
    expect(b.lobbyInvites.single.host.name, 'Foc');
    final lb = await b.joinLobby(la.id, [
      X01Player(id: sophie.key, name: 'Sophie'),
      X01Player(id: leo.key, name: 'Léo'),
    ]);
    await c.ping();
    final lc = await c.joinLobby(c.lobbyInvites.single.id);
    await la.setGame(game501());
    for (final l in [la, lb, lc]) {
      await l.fetch();
    }
    return (la, lb, lc);
  }

  test('Salon : invitations, maisons, jeu, lancement, salle à 3 maisons',
      () async {
    final (la, lb, lc) = await salon();
    expect(la.members.map((m) => m.player.name), ['Foc', 'Sophie', 'Cid']);
    expect(lb.mine?.players.map((p) => p.name), ['Sophie', 'Léo']);
    expect(lc.isHost, isFalse);
    expect(lc.game?['label'], '501');
    expect(lc.game?.containsKey('players'), isFalse);

    // Ordre : maisons en alternance (1er joueur de chaque maison, puis le 2e)
    final g = la.buildGame()!;
    expect([for (final p in g['players'] as List) p['name']],
        ['Foc', 'Sophie', 'Cid', 'Léo']);
    expect(salonProblem(g, 4), isNull);
    // Seul l'hôte lance
    await expectLater(lb.start(g),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'lb_host')));
    final roomId = await la.start(g);
    await lc.fetch();
    expect(lc.started, isTrue);
    expect(lc.room, roomId);

    final ra = await a.openRoom(roomId);
    final rb = await b.openRoom(roomId);
    final rc = await c.openRoom(roomId);
    addTearDown(ra.close);
    addTearDown(rb.close);
    addTearDown(rc.close);
    expect([ra.side, rb.side, rc.side], ['h1', 'h2', 'h3']);
    expect(ra.isSalon, isTrue);
    expect(ra.salon, la.id);
    expect(ra.others.map((h) => h.player.name), ['Sophie', 'Cid']);
    expect(rb.mine(leo.key), isTrue);
    expect(rb.mine(foc.key), isFalse);
    expect(ra.mine(foc.key), isTrue);
    expect(rc.mine(cid.key), isTrue);

    // Actions transmises à toutes les maisons
    final game = gameFromJson(ra.game);
    game.throwDart(const DartHit(20, 3, Ring.triple));
    game.next();
    ra.push(game.actionLog);
    await settle();
    await rc.fetch();
    expect(rc.actions, game.actionLog);

    // Vidéo : chaque message dit de quelle maison il vient
    final got = <Map<String, dynamic>>[];
    rc.signals.listen(got.add);
    await rb.signal({'type': 'ready', 'sid': 'x', 'home': 'h2'});
    await rc.fetch();
    await settle();
    expect(got.single['_from'], 'h2');

    // Cid s'en va : la partie continue, ses joueurs passent leur tour,
    // joués par la 1re maison encore là (Foc)
    await rc.leave();
    await ra.fetch();
    await rb.fetch();
    expect(ra.left, isFalse);
    expect(ra.absent(cid.key), isTrue);
    expect(ra.mine(cid.key), isTrue);
    expect(rb.mine(cid.key), isFalse);
    expect(ra.others.map((h) => h.player.name), ['Sophie']);

    // Puis Sophie : il ne reste qu'une maison, la partie est finie
    await rb.leave();
    await ra.fetch();
    expect(ra.left, isTrue);

    // Retour au salon : il se rouvre
    await la.back();
    expect(la.status, 'open');
    expect(la.room, isNull);
  });

  test('Salon public, hôte qui part, retrait, limites des jeux', () async {
    for (final s in [a, b, c, a]) {
      await s.ping();
    }
    final la = await a.createLobby(true);
    await b.loadLobbies();
    expect(b.lobbies.single.host.name, 'Foc');
    final lb = await b.joinLobby(b.lobbies.single.id);
    final lc = await c.joinLobby(la.id);
    await la.fetch();
    expect(la.members.length, 3);

    // L'hôte retire Cid, puis s'en va : Sophie devient l'hôte
    await la.kick(lc.members.firstWhere((m) => m.player.id == cid.id).player);
    await lc.fetch();
    expect(lc.gone, isTrue);
    await la.leave();
    await lb.fetch();
    expect(lb.isHost, isTrue);
    expect(lb.members.single.player.name, 'Sophie');

    // Le Chat et la Souris : 2 joueurs seulement
    final cat = PracticeGame(const PracticeSettings(PracticeKind.catMouse),
        [X01Player(id: foc.key, name: 'Foc')]).toJson();
    expect(salonProblem(cat, 3), contains('2 joueurs maximum'));
    expect(salonProblem(cat, 2), isNull);
    expect(salonProblem(game501(), 9), contains('8 joueurs'));
    expect(salonProblem(null, 2), isNotNull);
  });

  testWidgets('Réglages du jeu d\'un salon', (tester) async {
    await phone(tester);
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
      theme: Tv.theme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                  builder: (_) => SetupPage(salon: true, online: [
                        X01Player(id: foc.key, name: 'Foc'),
                        X01Player(id: sophie.key, name: 'Sophie'),
                        X01Player(id: cid.key, name: 'Cid'),
                      ])),
            );
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('PARTIE DU SALON'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('MAISONS EN ALTERNANCE'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('salon-pick')));
    await tester.pumpAndSettle();
    expect(result!['label'], isNotEmpty);
    expect(result!['order'], 'fixed');
    expect((result!['players'] as List).length, 3);
    expect(result!['double'], isNull);
  });

  testWidgets('Écran du salon : maisons, jeu, lancement chez l\'hôte',
      (tester) async {
    await phone(tester);
    late Lobby la;
    await tester.runAsync(() async {
      (la, _, _) = await salon();
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: LobbyPage(lobby: la)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MAISONS (3/4)'), findsOneWidget);
    expect(find.text('MAISON 1 · FOC'), findsOneWidget);
    expect(find.text('Sophie, Léo'), findsOneWidget);
    expect(find.text('501'), findsOneWidget);
    expect(find.text('LANCER (4 JOUEURS)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Partie de salon : une maison partie passe son tour',
      (tester) async {
    await phone(tester);
    late OnlineRoom ra, rb, rc;
    await tester.runAsync(() async {
      final (la, _, _) = await salon();
      // Foc, Sophie, Cid (sans Léo)
      await (await b
              .joinLobby(la.id, [X01Player(id: sophie.key, name: 'Sophie')]))
          .fetch();
      await la.fetch();
      final id = await la.start(la.buildGame()!);
      ra = await a.openRoom(id);
      rb = await b.openRoom(id);
      rc = await c.openRoom(id);
    });
    addTearDown(rb.close);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav, theme: Tv.theme(), home: const SizedBox()));
    nav.currentState!.push(MaterialPageRoute(
        builder: (_) => GamePage(game: gameFromJson(ra.game), online: ra)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('À TOI'), findsOneWidget);

    Future<void> sync() async {
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Foc joue, puis Sophie chez elle
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await sync();
    await tester.runAsync(() async {
      await rb.fetch();
      final g = gameFromJson(rb.game)..next();
      rb.push(g.actionLog);
      await settle();
      // Cid quitte la partie avant son tour
      await rc.leave();
      await ra.fetch();
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Cid a quitté la partie'), findsOneWidget);
    // 2 s après, son tour est passé par Foc : c'est de nouveau à Foc
    // (minuterie posée pendant la lecture de la salle : temps réel)
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2200)));
    await tester.pump();
    await sync();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('À TOI'), findsOneWidget);
    await tester.runAsync(rb.fetch);
    expect(rb.actions, ['n', 'n', 'n']);
    expect(tester.takeException(), isNull);
    nav.currentState!.pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(settle);
    await tester.pump(const Duration(seconds: 3));
  });
}
