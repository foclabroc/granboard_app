import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/darts_game.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/online/online.dart';
import 'package:granboard_proto/online/relay.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:granboard_proto/tournament.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/tournament_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75; // 785 × 392
  addTearDown(tester.view.reset);
}

void main() {
  late List<PlayerProfile> ps;

  final game = X01Game(const X01Settings(startScore: 301), const [
    X01Player(id: '1', name: 'A'),
    X01Player(id: '0', name: 'B', team: 1),
  ]).toJson();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Relay.enabled = false;
    OnlineRoom.videoEnabled = false;
    TournamentPage.poll = false;
    LocalTournamentStore.instance.debugReset();
    FakeServer().install();
    final store = PlayerStore.instance;
    await store.load();
    await BoardService.instance.init();
    ps = [
      for (final n in ['Foc', 'Sophie', 'Léo', 'Max', 'Zoé'])
        await store.register(n, '1234')
    ];
  });

  test('Création, inscriptions, lancement avec exempts, résultats', () async {
    final foc = ps[0];
    final id = await TournamentApi.create(foc.token,
        name: 'Coupe', size: 8, label: '301', game: game);
    for (final p in ps.skip(1)) {
      await TournamentApi.join(p.token, id);
    }
    // Liste vue par Léo : inscrit
    final l = await TournamentApi.list(ps[2].token);
    expect(l.single.count, 5);
    expect(l.single.joined, isTrue);
    expect(l.single.status, 'open');

    // Seul le créateur lance ; 5 joueurs → tableau de 8, 3 exempts
    var t = await TournamentApi.start(foc.token, id);
    expect(t.running, isTrue);
    expect(t.rounds, 3);
    expect(t.round(1).where((m) => m.bye).length, 3);
    expect(t.matches.where((m) => m.playable).length, greaterThanOrEqualTo(1));
    expect(t.roundName(1), 'QUARTS');
    expect(t.roundName(3), 'FINALE');

    // Les matchs se terminent un par un jusqu'au vainqueur
    while (!t.done) {
      final m = t.matches.firstWhere((m) => m.playable);
      final a = ps.firstWhere((p) => p.id == m.a);
      await TournamentApi.report(a.token, id, m.round, m.slot, m.a!);
      t = await TournamentApi.get(id);
    }
    expect(t.winner, isNotNull);
    expect(t.player(t.winner)!.name, isNotEmpty);

    // Plus rien à jouer, et un match fini ne change plus
    expect(() => TournamentApi.report(ps[1].token, id, 1, 3, ps[1].id),
        throwsA(isA<ApiError>()));
  });

  testWidgets('Liste, page du tournoi, inscription et lancement',
      (tester) async {
    await phone(tester);
    final foc = ps[0];
    late int id;
    await tester.runAsync(() async {
      id = await TournamentApi.create(foc.token,
          name: 'Coupe du vendredi', size: 4, label: '301', game: game);
    });
    // Sophie (profil principal du téléphone dans ce test : Foc)
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: const TournamentsPage()));
    await tester.runAsync(settle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('COUPE DU VENDREDI'), findsOneWidget);
    expect(find.text('INSCRIPTIONS 1/4'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('tn-card-$id')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(settle);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('INSCRITS 1/4'), findsOneWidget);
    expect(find.text('IL FAUT 2 INSCRITS'), findsOneWidget);

    await tester.runAsync(() async {
      await TournamentApi.join(ps[1].token, id);
      await TournamentApi.join(ps[2].token, id);
    });
    // Relecture : le bouton de lancement s'active
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ValueKey('tn-card-$id')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(settle);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LANCER LE TOURNOI'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tn-start')));
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('DEMI-FINALES'), findsOneWidget);
    expect(find.text('FINALE'), findsOneWidget);
    expect(find.text('EXEMPT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Match de tournoi en ligne : défi, partie, vainqueur au tableau',
      (tester) async {
    await phone(tester);
    final foc = ps[0], sophie = ps[1];
    late int id;
    late OnlineRoom ra;
    final a = OnlineService.forAccount(foc);
    final b = OnlineService.forAccount(sophie);
    // 101 sans double pour finir : T20, D20, 1
    final quick = X01Game(
        const X01Settings(startScore: 101, outRule: OutRule.open), const [
      X01Player(id: '1', name: 'A'),
      X01Player(id: '0', name: 'B', team: 1),
    ]).toJson();
    await tester.runAsync(() async {
      id = await TournamentApi.create(foc.token,
          name: 'Duel', size: 4, label: '101', game: quick);
      await TournamentApi.join(sophie.token, id);
      await TournamentApi.start(foc.token, id);
      await a.ping();
      await b.ping();
      await a.ping();
      final t = await TournamentApi.get(id);
      final m = t.myMatch(foc.id)!;
      final inv =
          await a.challengeTournament(id, m.round, m.slot, a.players.single);
      await b.ping();
      expect(b.invite!.game['tn'], isA<Map>());
      final room = await b.answer(inv, true);
      ra = await a.openRoom(room!);
    });
    addTearDown(ra.close);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav, theme: Tv.theme(), home: const SizedBox()));
    final g = gameFromJson(ra.game);
    expect(g.players.first.id, foc.key, reason: 'Foc commence (faux serveur)');
    nav.currentState!
        .push(MaterialPageRoute(builder: (_) => GamePage(game: g, online: ra)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final f in [
      GranBoardDecoder.frameFor(20, Ring.triple)!,
      GranBoardDecoder.frameFor(20, Ring.double)!,
      GranBoardDecoder.frameFor(1, Ring.singleOuter)!,
    ]) {
      BoardService.instance.injectFrame(f.codeUnits);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(settle);
    }
    expect(g.finished, isTrue);
    await tester.runAsync(settle);
    final t = await tester.runAsync(() => TournamentApi.get(id));
    expect(t!.done, isTrue, reason: 'finale à 2 : Foc gagne le tournoi');
    expect(t.winner, foc.id);
    nav.currentState!.pop();
    await tester.pump(const Duration(seconds: 1));
  });

  test('Tournoi à la maison : tirage, exempts, vainqueur, sauvegarde',
      () async {
    final players = [
      for (final p in ps) X01Player(id: p.key, name: p.name),
      const X01Player(id: 'guest-1', name: 'Invité 1'),
    ]; // 6 joueurs → tableau de 8, 2 exempts
    final lt = LocalTournament.create(
        name: 'Samedi',
        label: '301',
        game: game,
        players: players,
        random: math.Random(1));
    var t = lt.view();
    expect(t.local, isTrue);
    expect(t.rounds, 3);
    expect(t.round(1).where((m) => m.bye).map((m) => m.slot), [0, 2]);
    expect(t.round(2).first.a, isNotNull, reason: 'exempt déjà au 2e tour');
    // Partie d'un match : les 2 joueurs, règles du modèle
    final m = t.nextMatch!;
    final g = lt.gameFor(m);
    expect((g['players'] as List).length, 2);
    expect(g['settings'], game['settings']);
    while (t.nextMatch != null) {
      final n = t.nextMatch!;
      lt.advance(n.round, n.slot, n.b!);
      t = lt.view();
    }
    expect(t.done, isTrue);
    expect(t.player(t.winner), isNotNull);
    // Gardé sur le téléphone
    final store = LocalTournamentStore.instance;
    await store.add(lt);
    store.debugReset();
    await store.load();
    expect(store.byUid(lt.uid)!.winner, lt.winner);
    expect(
        store.byUid(lt.uid)!.view().toJson()['matches'], t.toJson()['matches']);
  });

  testWidgets('Tournoi à la maison : JOUER, partie sur la cible, TABLEAU',
      (tester) async {
    await phone(tester);
    final quick = X01Game(
        const X01Settings(startScore: 101, outRule: OutRule.open), const [
      X01Player(id: '1', name: 'A'),
      X01Player(id: '0', name: 'B', team: 1),
    ]).toJson();
    final lt = LocalTournament.create(
        name: 'Salon',
        label: '101',
        game: quick,
        players: [
          X01Player(id: ps[0].key, name: ps[0].name),
          const X01Player(id: 'guest-1', name: 'Invité 1'),
        ]);
    await tester.runAsync(() => LocalTournamentStore.instance.add(lt));
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: LocalTournamentPage(uid: lt.uid)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FINALE'), findsOneWidget);
    expect(find.textContaining('PROCHAIN MATCH'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tn-play')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final f in [
      GranBoardDecoder.frameFor(20, Ring.triple)!,
      GranBoardDecoder.frameFor(20, Ring.double)!,
      GranBoardDecoder.frameFor(1, Ring.singleOuter)!,
    ]) {
      BoardService.instance.injectFrame(f.codeUnits);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('TABLEAU'), findsOneWidget);
    await tester.tap(find.text('TABLEAU'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(lt.winner, isNotNull, reason: 'celui qui a commencé gagne');
    expect(find.textContaining('REMPORTE LE TOURNOI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Écran TV : tableau de 16 joueurs qui tient à l\'écran',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2; // 960 × 540
    addTearDown(tester.view.reset);
    final lt = LocalTournament.create(
        name: 'Grand tournoi',
        label: '501',
        game: game,
        players: [
          for (var i = 1; i <= 16; i++)
            X01Player(id: 'guest-$i', name: 'Joueur $i')
        ]);
    lt.advance(1, 0, lt.view().round(1).first.a!);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: Scaffold(
            body: TvTournamentView(
                tournament: Tournament.fromJson(lt.view().toJson())))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('HUITIÈMES'), findsOneWidget);
    expect(find.textContaining('PROCHAIN MATCH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Écran TV : le téléphone envoie le tableau, la TV l\'affiche',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final tv = TvClient(realtime: false);
    addTearDown(tv.dispose);
    final lt = LocalTournament.create(
        name: 'Salon TV',
        label: 'Cricket',
        game: game,
        players: [
          for (var i = 1; i <= 5; i++)
            X01Player(id: 'guest-$i', name: 'Joueur $i')
        ]);
    tv.debugSetState('AB10', {
      'screen': 'tournament',
      'host': 'Foc',
      'tournament': lt.view().toJson(),
    });
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: TvHome(client: tv, onPhoneMode: () {})));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SALON TV'), findsOneWidget);
    expect(find.text('QUARTS'), findsOneWidget);
    expect(find.text('EXEMPT'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
