import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/online/online.dart';
import 'package:granboard_proto/online/relay.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/online_page.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

const t20 = DartHit(20, 3, Ring.triple);

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75; // 785 × 392
  addTearDown(tester.view.reset);
}

void main() {
  late FakeServer server;
  late PlayerProfile foc, sophie;
  late OnlineService a, b;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Relay.enabled = false;
    OnlineRoom.videoEnabled = false;
    server = FakeServer()..install();
    final store = PlayerStore.instance;
    await store.load();
    await BoardService.instance.init();
    foc = await store.register('Foc', '1234');
    sophie = await store.register('Sophie', '1234');
    a = OnlineService.forAccount(foc);
    b = OnlineService.forAccount(sophie);
  });

  Map<String, dynamic> game501() => X01Game(const X01Settings(), [
        X01Player(id: foc.key, name: 'Foc'),
        X01Player(id: sophie.key, name: 'Sophie', team: 1),
      ]).toJson();

  /// Défi de Foc accepté par Sophie : les 2 salles ouvertes.
  Future<(OnlineRoom, OnlineRoom)> rooms([Map<String, dynamic>? game]) async {
    await a.ping();
    await b.ping();
    await a.ping();
    final id = await a.challenge(a.players.single, game ?? game501());
    await b.ping();
    final room = await b.answer(id, true);
    final ra = await a.openRoom(room!);
    final rb = await b.openRoom(room);
    addTearDown(ra.close);
    addTearDown(rb.close);
    return (ra, rb);
  }

  test('Présence, défi refusé, annulé, accepté', () async {
    await a.ping();
    expect(a.connected, isTrue);
    expect(a.players, isEmpty);
    expect(
        () =>
            a.challenge(OnlinePlayer(id: sophie.id, name: 'Sophie'), game501()),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'on_offline')));

    await b.ping();
    await a.ping();
    expect(a.players.single.name, 'Sophie');
    expect(a.players.single.busy, isFalse);

    // Refusé
    var id = await a.challenge(a.players.single, game501());
    await b.ping();
    expect(b.invite?.from.name, 'Foc');
    expect(describeGame(b.invite!.game).$1, '501');
    expect(await b.answer(id, false), isNull);
    await a.ping();
    expect(a.sent?.status, 'declined');

    // Annulé : le défi disparaît chez l'autre
    id = await a.challenge(a.players.single, game501());
    await a.cancel(id);
    await b.ping();
    expect(b.invite, isNull);
    expect(() => b.answer(id, true),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'on_gone')));

    // Accepté : une salle, les deux sont « en partie »
    id = await a.challenge(a.players.single, game501());
    await b.ping();
    final room = await b.answer(id, true);
    expect(room, isNotNull);
    await a.ping();
    expect(a.sent?.status, 'accepted');
    expect(a.sent?.room, room);
    expect(a.players.single.busy, isTrue);
    expect(a.resumeRoom, room);
  });

  test('Salle : actions transmises, conflit, vidéo, départ', () async {
    final (ra, rb) = await rooms();
    expect(ra.side, 'a');
    expect(rb.side, 'b');
    expect(ra.peer?.name, 'Sophie');
    expect(rb.peer?.name, 'Foc');

    final ga = gameFromJson(ra.game);
    ga.throwDart(t20);
    ga.throwDart(t20);
    ra.push(ga.actionLog);
    await settle();
    final v = rb.gameVersion;
    await rb.fetch();
    expect(rb.gameVersion, v + 1);
    expect(rb.actions, ga.actionLog);
    final gb = gameFromJson(rb.game) as X01Game;
    expect(gb.stateOf(0).remaining, 381);

    // Les deux envoient en même temps : le second repart de l'état serveur
    ga.throwDart(t20);
    ra.push(ga.actionLog);
    await settle();
    rb.push([...rb.actions, 'm']);
    await settle();
    expect(rb.conflict, isTrue);
    expect(rb.actions, ga.actionLog);

    // Triche : réglages modifiés → refusé, on repart de l'état serveur
    rb.conflict = false;
    rb.game = {
      ...rb.game,
      'settings': {...(rb.game['settings'] as Map), 'start': 101}
    };
    rb.push(rb.actions);
    await settle();
    expect(rb.conflict, isTrue);
    expect(gameFromJson(rb.game).title, '501');

    // Messages vidéo : seulement ceux de l'autre, une seule fois
    final got = <Map<String, dynamic>>[];
    final sub = rb.signals.listen(got.add);
    await ra.signal({'type': 'ready', 'sid': '1'});
    await rb.signal({'type': 'ready', 'sid': '2'});
    await rb.fetch();
    await rb.fetch();
    await settle();
    expect(got, [
      {'type': 'ready', 'sid': '1'}
    ]);
    await sub.cancel();

    // Hors ligne : l'envoi repart tout seul
    server.offline = true;
    ga.next();
    ra.push(ga.actionLog);
    await settle();
    expect(ra.error, isNotNull);
    server.offline = false;
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    expect(ra.error, isNull);
    await rb.fetch();
    expect(rb.actions.last, 'n');

    await ra.leave();
    await rb.fetch();
    expect(rb.left, isTrue);
    await a.ping();
    expect(a.resumeRoom, isNull);
  });

  testWidgets('Réglages d\'un défi : renvoie la partie', (tester) async {
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
                  builder: (_) => SetupPage(kind: 'cricket', online: [
                        X01Player(id: foc.key, name: 'Foc'),
                        X01Player(id: sophie.key, name: 'Sophie'),
                      ])),
            );
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('DÉFIER SOPHIE'), findsOneWidget);
    expect(find.text('Équipes (Team Cricket)'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('MOI'));
    await tester.pump();
    await tester.tap(find.textContaining('DÉFIER : '));
    await tester.pumpAndSettle();
    final g = gameFromJson(result!);
    expect(g, isA<CricketGame>());
    expect([for (final p in g.players) p.name], ['Foc', 'Sophie']);
  });

  testWidgets('Écran En ligne : liste et reprise', (tester) async {
    await phone(tester);
    await tester.runAsync(() async {
      await b.ping();
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const OnlinePage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SOPHIE'), findsOneWidget);
    expect(find.text('DÉFIER'), findsOneWidget);
    expect(find.text('LIBRE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Partie en ligne : tour par tour, annulation, départ',
      (tester) async {
    await phone(tester);
    late OnlineRoom ra, rb;
    await tester.runAsync(() async {
      (ra, rb) = await rooms();
    });
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav, theme: Tv.theme(), home: const SizedBox()));
    nav.currentState!.push(MaterialPageRoute(
        builder: (_) => GamePage(game: gameFromJson(ra.game), online: ra)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('À TOI'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> sync() async {
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Foc lance 3 fléchettes puis « Suivant »
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('RATÉ').last);
      await tester.pump();
    }
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await sync();
    expect(find.text('AU TOUR DE SOPHIE'), findsOneWidget);
    await tester.runAsync(rb.fetch);
    expect(rb.actions, ['m', 'm', 'm', 'n']);

    // Ce n'est plus à lui : sa cible et ses boutons ne comptent pas
    BoardService.instance.injectFrame('3.4@'.codeUnits);
    await tester.pump();
    await tester.tap(find.text('RATÉ').last);
    await tester.pump();
    await sync();
    expect(find.textContaining('au tour de Sophie'), findsOneWidget);
    await tester.runAsync(rb.fetch);
    expect(rb.actions.length, 4);

    // Il peut reprendre son « Suivant », mais pas annuler l'action de Sophie
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('ANNULER'));
    await tester.pump();
    await sync();
    expect(find.text('À TOI'), findsOneWidget);
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await sync();

    // Sophie joue chez elle : la partie avance sur le téléphone de Foc
    final gb = gameFromJson(ra.game) as X01Game;
    await tester.runAsync(() async {
      await rb.fetch();
      for (final e in rb.actions.skip(gb.actionLog.length)) {
        gb.applyLogEntry(e);
      }
      gb.throwDart(t20);
      rb.push(gb.actionLog);
      await settle();
      await ra.fetch();
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('441'), findsWidgets);
    expect(find.text('AU TOUR DE SOPHIE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('ANNULER'));
    await tester.pump();
    expect(find.textContaining('tes propres actions'), findsOneWidget);
    await tester.runAsync(rb.fetch);
    expect(rb.actions.last, 'd:20:${Ring.triple.index}');

    // Sophie quitte : bandeau + « Quitter »
    await tester.runAsync(() async {
      await rb.leave();
      await ra.fetch();
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sophie a quitté la partie'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('QUITTER'));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(settle);
    await tester.pump(const Duration(seconds: 3));
  });

  test('Double : défi à 3, réponse avec mon équipier, tour par maison',
      () async {
    final leo = await PlayerStore.instance.register('Léo', '1234');
    final invite = X01Game(const X01Settings(doubles: true), [
      X01Player(id: foc.key, name: 'Foc'),
      X01Player(id: sophie.key, name: 'Sophie', team: 1),
      const X01Player(id: 'guest-a1', name: 'Invité de Foc'),
    ]).toJson()
      ..['double'] = true
      ..['home'] = {foc.key: 'a', 'guest-a1': 'a', sophie.key: 'b'};
    final full = completeDouble(
        invite, sophie.key, X01Player(id: leo.key, name: 'Léo'));
    expect([for (final p in full['players'] as List) p['name']],
        ['Foc', 'Sophie', 'Invité de Foc', 'Léo']);
    expect([for (final p in full['players'] as List) p['team']], [0, 1, 0, 1]);
    expect((full['home'] as Map)[leo.key], 'b');

    await a.ping();
    await b.ping();
    await a.ping();
    final id = await a.challenge(a.players.single, invite);
    await b.ping();
    // sans équipier : refusé
    await expectLater(b.answer(id, true), throwsA(isA<ApiError>()));
    final room = await b.answer(id, true, game: full);
    final ra = await a.openRoom(room!);
    final rb = await b.openRoom(room);
    addTearDown(ra.close);
    addTearDown(rb.close);
    expect(ra.mine(foc.key), isTrue);
    expect(ra.mine('guest-a1'), isTrue);
    expect(ra.mine(sophie.key), isFalse);
    expect(rb.mine(sophie.key), isTrue);
    expect(rb.mine(leo.key), isTrue);
    expect(rb.mine(foc.key), isFalse);
    final g = gameFromJson(ra.game) as X01Game;
    expect(g.players.length, 4);
    expect(g.settings.doubles, isTrue);
  });

  testWidgets('Réglages d\'un défi en double : 01 / Cricket, partie à 3',
      (tester) async {
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
                  builder: (_) => SetupPage(online: [
                        X01Player(id: foc.key, name: 'Foc'),
                        X01Player(id: sophie.key, name: 'Sophie'),
                        const X01Player(id: 'guest-a1', name: 'Invité de Foc'),
                      ])),
            );
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('DÉFIER SOPHIE EN DOUBLE'), findsOneWidget);
    expect(find.text('MEDLEY'), findsNothing);
    expect(find.text('PARTY'), findsNothing);
    expect(find.text('SON ÉQUIPIER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('MOI'));
    await tester.pump();
    await tester.tap(find.textContaining('DÉFIER : '));
    await tester.pumpAndSettle();
    expect(result!['double'], isTrue);
    final g = gameFromJson(result!) as X01Game;
    expect(g.settings.doubles, isTrue);
    expect([for (final p in g.players) p.team], [0, 1, 0]);
    expect((result!['home'] as Map)['guest-a1'], 'a');
  });
}
