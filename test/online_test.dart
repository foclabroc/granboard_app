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
    expect(find.textContaining('CONTRE SOPHIE', findRichText: true),
        findsOneWidget);
    expect(find.text('ADVERSAIRE'), findsOneWidget);
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
    expect(find.text('JOUEURS (1)'), findsOneWidget);
    expect(find.text('MON ESPACE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Écran En ligne : tableau sur petit écran', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => b.ping());
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const OnlinePage()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('JOUEURS (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('people-search')), findsOneWidget);
    expect(find.text('DÉFIER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Amis : demande, acceptation, retrait, refus', () async {
    await a.ping();
    await b.ping();
    await a.loadPeople();
    final bob = a.people.firstWhere((p) => p.id == b.me!.id);
    expect(bob.friend, '');
    expect(bob.offline, isFalse);
    await a.askFriend(bob);
    expect(a.people.firstWhere((p) => p.id == b.me!.id).friend, 'sent');
    await b.ping();
    expect(b.asks.single.id, a.me!.id);
    await b.loadPeople();
    final ann = b.people.first; // demande reçue : en tête
    expect(ann.id, a.me!.id);
    expect(ann.friend, 'ask');
    await b.answerFriend(ann, true);
    expect(b.asks, isEmpty);
    expect(b.people.firstWhere((p) => p.id == a.me!.id).isFriend, isTrue);
    await a.loadPeople();
    expect(a.people.firstWhere((p) => p.id == b.me!.id).isFriend, isTrue);
    // retiré d'un côté = retiré des deux
    await a.removeFriend(bob);
    await b.loadPeople();
    expect(b.people.firstWhere((p) => p.id == a.me!.id).friend, '');
    // refus : la demande disparaît
    await a.askFriend(bob);
    await b.loadPeople();
    await b.answerFriend(b.people.first, false);
    await a.loadPeople();
    expect(a.people.firstWhere((p) => p.id == b.me!.id).friend, '');
    // deux demandes croisées = amis
    await a.askFriend(bob);
    await b.askFriend(ann);
    expect(b.people.firstWhere((p) => p.id == a.me!.id).isFriend, isTrue);
  });

  test('Prévenir, ne pas déranger, bloquer, phrase, rendez-vous', () async {
    await a.ping();
    await b.ping();
    await a.loadPeople();
    final bob = a.people.single;
    expect(bob.seen, isNotNull);
    expect(bob.free, isTrue);

    // « je veux jouer » laissé à Sophie
    await a.want(bob);
    expect(a.people.single.wanted, isTrue);
    await b.ping();
    expect(b.wants.single.id, a.me!.id);
    await b.loadPeople();
    expect(b.people.single.want, isTrue);
    // un défi solde le mot laissé
    final id = await b.challenge(b.people.single, game501());
    await b.cancel(id);
    await b.ping();
    expect(b.wants, isEmpty);

    // ne pas déranger : visible, mais pas de défi
    await b.setDnd(true);
    await a.loadPeople();
    expect(a.people.single.dnd, isTrue);
    expect(a.people.single.free, isFalse);
    await expectLater(a.challenge(a.people.single, game501()),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'on_dnd')));
    await b.setDnd(false);
    await b.ping();
    expect(b.dnd, isFalse);

    // phrase du profil
    await b.setMotto('  Le   bull ou rien ');
    expect(b.motto, 'Le bull ou rien');
    await a.loadPeople();
    expect(a.people.single.motto, 'Le bull ou rien');

    // rendez-vous proposé, accepté, retiré
    final at = DateTime.now().add(const Duration(hours: 3));
    await a.proposeDate(a.people.single, at);
    expect(a.dates.single.mine, isTrue);
    expect(a.dates.single.ok, isFalse);
    await b.ping();
    expect(b.dates.single.mine, isFalse);
    expect(b.dates.single.at.difference(at).inSeconds.abs(), lessThan(2));
    await b.answerDate(b.dates.single.id, true);
    await a.ping();
    expect(a.dates.single.ok, isTrue);
    await a.answerDate(a.dates.single.id, false);
    await b.ping();
    expect(b.dates, isEmpty);

    // bloquer : plus d'amitié ni de défi, et il me voit hors ligne
    await a.askFriend(a.people.single);
    await b.loadPeople();
    await b.answerFriend(b.people.single, true);
    expect(await a.friendIds(), {b.me!.id});
    await b.block(b.people.single);
    expect(b.people.single.blocked, isTrue);
    expect(await a.friendIds(), isEmpty);
    await a.loadPeople();
    expect(a.people.single.offline, isTrue);
    await expectLater(a.askFriend(a.people.single),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'on_blocked')));
    await b.block(b.people.single, false);
    await a.askFriend(a.people.single);
    expect(a.people.single.friend, 'sent');
  });

  test('Historique : la partie en ligne de chacun est reliée à l\'autre',
      () async {
    final (ra, rb) = await rooms();
    // Chaque téléphone n'envoie que son joueur (l'autre n'est pas sur ce
    // téléphone) : on retire Sophie du téléphone de Foc et inversement
    final x = X01Game(const X01Settings(startScore: 301), [
      X01Player(id: foc.key, name: 'Foc'),
      X01Player(id: sophie.key, name: 'Sophie'),
    ]);
    final store = PlayerStore.instance;
    final sophieAcc = store.byId(sophie.key)!;
    sophieAcc.expired = true; // pas sur « ce » téléphone
    await store.recordX01(x, link: '${ra.id}:0');
    sophieAcc.expired = false;
    final focAcc = store.byId(foc.key)!;
    focAcc.expired = true;
    await store.recordX01(x, link: '${rb.id}:0');
    focAcc.expired = false;
    expect(server.games.values.where((g) => g['link'] == '${ra.id}:0'),
        hasLength(2));
    final h = await GbServer.history(foc.id);
    expect(h.first['online'], isTrue);
    expect([for (final o in h.first['with'] as List) o['pseudo']], ['Sophie']);
    await ra.leave();
    await rb.leave();
  });

  test('Bilan entre amis, partie regardée, revanche', () async {
    final (ra, rb) = await rooms();
    await a.loadPeople();
    await a.askFriend(a.people.single);
    await b.loadPeople();
    await b.answerFriend(b.people.single, true);
    await a.loadPeople();
    expect(a.people.single.watchable, isTrue);
    // un ami regarde la partie (ici Foc lui-même, pour le format)
    final g = await a.watchGame(b.me!.id);
    expect(g!['players'], hasLength(2));
    // fin de partie : compté une seule fois
    await GbServer.rpc('gb_on_result',
        {'p_token': foc.token, 'p_room': ra.id, 'p_won': true});
    await GbServer.rpc('gb_on_result',
        {'p_token': sophie.token, 'p_room': rb.id, 'p_won': false});
    await a.loadPeople();
    expect((a.people.single.wins, a.people.single.losses), (1, 0));
    await b.loadPeople();
    expect((b.people.single.wins, b.people.single.losses), (0, 1));
    await ra.leave();
    await rb.leave();
    expect(await a.watchGame(b.me!.id), isNull);

    // revanche : même partie, journal vidé, l'autre commence
    final again = OnlineResultsPage.rematchOf(
        {...game501(), 'actions': ['d:20:3', 'n']})!;
    expect(again['actions'], isEmpty);
    expect((again['players'] as List).first['id'], sophie.key);
    expect(OnlineResultsPage.rematchOf({...game501(), 'double': true}), isNull);
    expect(OnlineResultsPage.rematchOf({...game501(), 'tn': {}}), isNull);
    expect(agoText(DateTime(2026, 11, 15, 10), DateTime(2026, 11, 15, 12)),
        'il y a 2 h');
  });

  testWidgets('Écran En ligne : prévenir un absent, menu, ne pas déranger',
      (tester) async {
    await phone(tester);
    await tester.runAsync(() async {
      await server.call('gb_register',
          {'p_pseudo': 'Zoé', 'p_pin': '1111', 'p_color': 3});
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const OnlinePage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final id = OnlineService.instance.people
        .firstWhere((p) => p.name == 'Zoé')
        .id;
    expect(find.textContaining('VU '), findsWidgets);
    await tester.tap(find.byKey(ValueKey('want-$id')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PRÉVENU ✓'), findsOneWidget);
    expect(server.wants, hasLength(1));
    // menu : bloquer
    await tester.tap(find.byKey(ValueKey('person-menu-$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Proposer un rendez-vous'), findsOneWidget);
    await tester.tap(find.text('Bloquer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('block-yes')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DÉBLOQUER'), findsOneWidget);
    expect(find.textContaining('BLOQUÉ'), findsWidgets);
    // ne pas déranger
    await tester.tap(find.byKey(const ValueKey('dnd')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(server.dnd, hasLength(1));
    expect(find.textContaining('NE PAS DÉRANGER'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Regarder la partie d\'un ami', (tester) async {
    await phone(tester);
    WatchPage.every = const Duration(milliseconds: 200);
    late OnlineRoom ra, rb;
    late OnlinePlayer bob;
    await tester.runAsync(() async {
      (ra, rb) = await rooms();
      await a.loadPeople();
      await a.askFriend(a.people.single);
      await b.loadPeople();
      await b.answerFriend(b.people.single, true);
      await a.loadPeople();
      bob = a.people.single;
    });
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: WatchPage(player: bob)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('SPECTATEUR'), findsOneWidget);
    expect(find.text('501'), findsWidgets);
    // la partie se finit : message, on peut quitter
    await tester.runAsync(() async {
      await ra.leave();
      await rb.leave();
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('PARTIE TERMINÉE.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Écran En ligne : tous les joueurs, hors ligne, ami, filtres',
      (tester) async {
    await phone(tester);
    await tester.runAsync(() async {
      await b.ping();
      // un 3e compte, jamais connecté en ligne
      await server.call('gb_register',
          {'p_pseudo': 'Zoé', 'p_pin': '1111', 'p_color': 3});
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const OnlinePage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ZOÉ'), findsOneWidget);
    expect(find.textContaining('VU '), findsOneWidget);
    expect(find.text('TOUS (2)'), findsOneWidget);
    expect(find.text('EN LIGNE (1)'), findsOneWidget);
    // défi impossible hors ligne
    final id = OnlineService.instance.people
        .firstWhere((p) => p.name == 'Zoé')
        .id;
    expect(
        find.descendant(
            of: find.byKey(ValueKey('person-$id')),
            matching: find.text('DÉFIER')),
        findsNothing);
    expect(find.byKey(ValueKey('want-$id')), findsOneWidget);
    // demande d'ami
    await tester.tap(find.byKey(ValueKey('friend-add-$id')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DEMANDÉ'), findsOneWidget);
    // filtre « en ligne »
    await tester.tap(find.byKey(const ValueKey('people-online')));
    await tester.pump();
    expect(find.text('ZOÉ'), findsNothing);
    expect(find.text('SOPHIE'), findsOneWidget);
    // recherche
    await tester.tap(find.byKey(const ValueKey('people-all')));
    await tester.enterText(find.byKey(const ValueKey('people-search')), 'zo');
    await tester.pump();
    expect(find.text('ZOÉ'), findsOneWidget);
    expect(find.text('SOPHIE'), findsNothing);
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
    expect(find.textContaining('CONTRE SOPHIE EN DOUBLE', findRichText: true),
        findsOneWidget);
    expect(find.text('MEDLEY'), findsNothing);
    expect(find.text('PARTY'), findsNothing);
    expect(find.text('ÉQUIPIER'), findsOneWidget);
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
