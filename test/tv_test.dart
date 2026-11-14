import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/tv_link.dart';
import 'package:granboard_proto/ui/cricket_view.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/award.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer()..install();
    await PlayerStore.instance.load();
    await TvLink.instance.load();
  });

  test('Téléphone → serveur → TV : liaison, partie, son coupé', () async {
    final tv = TvClient(realtime: false); // une TV
    await tv.start();
    expect(tv.code, isNotNull);
    expect(tv.state, isNull);

    expect(() => TvLink.instance.link('ZZZZ'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'tv_code')));
    await TvLink.instance.link(tv.code!.toLowerCase());
    expect(TvLink.instance.linked, isTrue);
    expect(AudioService.instance.muted, isTrue);

    await tv.fetch();
    expect(tv.state?['screen'], 'lobby');

    final g = X01Game(const X01Settings(), const [
      X01Player(id: '1', name: 'Foc'),
      X01Player(id: 'guest-1', name: 'Invité 1'),
    ]);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    TvLink.instance.pushGame(g);
    await settle();
    await tv.fetch();
    expect(tv.state?['screen'], 'game');
    final copy =
        X01Game.fromJson(Map<String, dynamic>.from(tv.state!['game'] as Map));
    expect(copy.stateOf(0).remaining, 441);

    // Un autre téléphone prend la main : l'écran est retiré, le son revient
    final hostBefore = server.tvRooms[tv.code]!['host'];
    server.tvRooms[tv.code]!['host'] = 'autre';
    TvLink.instance.pushLobby();
    await settle();
    expect(TvLink.instance.linked, isFalse);
    expect(AudioService.instance.muted, isFalse);
    expect(hostBefore, isNotNull);
    tv.dispose();
  });

  test('TV + tablette : les deux reçoivent, un seul joue le son', () async {
    final tv = TvClient(realtime: false);
    final tab =
        TvClient(realtime: false, deviceName: 'Tablette', prefKey: 'tablette');
    await tv.start();
    await tab.start();
    final link = TvLink.instance;
    await link.link(tab.code!);
    expect(link.soundOn, {TvLink.phone},
        reason: 'une tablette ne prend pas le son');
    expect(AudioService.instance.muted, isFalse);
    await link.link(tv.code!);
    expect(link.screens.length, 2);
    expect(link.soundOn, {tv.code}, reason: 'la TV prend le son');
    expect(AudioService.instance.muted, isTrue);

    final g =
        X01Game(const X01Settings(), const [X01Player(id: '1', name: 'Foc')]);
    g.throwDart(const DartHit(20, 1, Ring.singleOuter));
    link.pushGame(g);
    await settle();
    await tv.fetch();
    await tab.fetch();
    expect(tv.state?['sound'], isTrue);
    expect(tab.state?['sound'], isFalse);
    expect(tab.state?['screen'], 'game');

    // Le son passe sur la tablette
    await link.setSoundOn(tab.code!);
    await settle();
    await tv.fetch();
    await tab.fetch();
    expect(tv.state?['sound'], isFalse);
    expect(tab.state?['sound'], isTrue);

    // Puis sur le téléphone
    await link.setSoundOn(TvLink.phone);
    expect(AudioService.instance.muted, isFalse);

    // Plusieurs appareils à la fois : téléphone + TV + tablette
    await link.toggleSound(tv.code!);
    await link.toggleSound(tab.code!);
    await settle();
    await tv.fetch();
    await tab.fetch();
    expect(link.soundOn, {TvLink.phone, tv.code, tab.code});
    expect(tv.state?['sound'], isTrue);
    expect(tab.state?['sound'], isTrue);
    expect(AudioService.instance.muted, isFalse);
    expect(link.soundLabel, 'Téléphone + Tablette + TV');
    // On retire le téléphone : TV + tablette seulement
    await link.toggleSound(TvLink.phone);
    expect(AudioService.instance.muted, isTrue);
    // Gardé après redémarrage
    await link.load();
    expect(link.soundOn, {tv.code, tab.code});
    // Le dernier appareil coché ne se retire pas
    await link.toggleSound(tab.code!);
    await link.toggleSound(tv.code!);
    expect(link.soundOn, {tv.code});

    // Retirer l'écran qui a le son : le son revient au téléphone
    await link.setSoundOn(tv.code!);
    await link.unlink(tv.code!);
    expect(link.soundOn, {TvLink.phone});
    expect(link.screens.single.code, tab.code);
    await link.unlinkAll();
    tv.dispose();
    tab.dispose();
  });

  testWidgets('Écran TV : code, attente, partie, résultats', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0; // 960 × 540
    addTearDown(tester.view.reset);
    final tv = TvClient(realtime: false);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: TvHome(client: tv, onPhoneMode: () {})));
    tv.debugSetState('KX7P', null);
    await tester.pump();
    expect(find.text('K'), findsOneWidget);
    expect(find.text('NOUVEAU CODE'), findsOneWidget);

    server.accounts[7] = {'pseudo': 'Ced', 'pin': '1234', 'color': 2};
    server.recentOf[7] = [
      {
        'date': DateTime.now().toUtc().toIso8601String(),
        'kind': 'x01',
        'mode': '501 Double Out',
        'won': true,
        'avg': 55.5
      }
    ];
    tv.debugSetState('KX7P', {
      'screen': 'lobby',
      'host': 'Foc',
      'ids': [7]
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('RELIÉ À FOC'), findsOneWidget);
    // classements à gauche, dernières parties à droite
    expect(find.text('TOP RANG'), findsOneWidget);
    expect(find.text('DERNIÈRES PARTIES'), findsOneWidget);
    expect(find.text('501 DOUBLE OUT'), findsOneWidget);
    expect(find.text('55,5 MOY'), findsOneWidget);
    // tablette en mode écran : on peut revenir en mode téléphone d'ici
    expect(find.byKey(const ValueKey('lobby-phone-mode')), findsOneWidget);

    final g = X01Game(const X01Settings(startScore: 301, roundLimit: 1), const [
      X01Player(id: '1', name: 'Foc'),
      X01Player(id: '2', name: 'Sophie'),
    ]);
    Map<String, dynamic> st(String screen) => {
          'screen': screen,
          'game': jsonDecode(jsonEncode(g.toJson())),
          'colors': {'1': 0xFFE53935, '2': 0xFF1E88E5},
        };
    tv.debugSetState('KX7P', st('game'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('301'), findsWidgets);

    g.throwDart(const DartHit(20, 3, Ring.triple));
    tv.debugSetState('KX7P', st('game'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('241'), findsWidgets);
    expect(find.text('T20'), findsOneWidget);

    g.next();
    g.next();
    tv.debugSetState('KX7P', st('results'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('RÉSULTATS'), findsOneWidget);
    expect(find.text('REJOUER'), findsNothing); // pas de boutons sur la TV
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Écran TV : partie de Cricket rejouée puis résultats',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0; // 960 × 540
    addTearDown(tester.view.reset);
    final tv = TvClient(realtime: false);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: TvHome(client: tv, onPhoneMode: () {})));
    final g = CricketGame(
        const CricketSettings(variant: CricketVariant.cutThroat, seed: 3),
        const [
          X01Player(id: '1', name: 'Foc'),
          X01Player(id: '2', name: 'Sophie'),
          X01Player(id: '3', name: 'Léo'),
        ]);
    Map<String, dynamic> st(String screen) => {
          'screen': screen,
          'game': jsonDecode(jsonEncode(g.toJson())),
          'colors': {'1': 0xFFE53935, '2': 0xFF1E88E5, '3': 0xFF43A047},
        };
    tv.debugSetState('KX7P', st('game'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CUT THROAT'), findsWidgets);

    g.throwDart(const DartHit(20, 3, Ring.triple));
    g.throwDart(const DartHit(20, 3, Ring.triple));
    tv.debugSetState('KX7P', st('game'));
    await tester.pump(const Duration(milliseconds: 300));
    // 60 points donnés à chacun des 2 adversaires
    expect(find.text('60'), findsWidgets);
    expect(tester.takeException(), isNull);

    g.next();
    g.next();
    g.next();
    tv.debugSetState('KX7P', st('results'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('RÉSULTATS'), findsOneWidget);
    expect(find.text('REJOUER'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Écran TV : la vidéo du bull se lance (pas pendant la construction)',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    AwardPlayer.enabled = true;
    addTearDown(() => AwardPlayer.enabled = false);
    final tv = TvClient(realtime: false);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: TvHome(client: tv, onPhoneMode: () {})));
    final g = X01Game(const X01Settings(startScore: 301), const [
      X01Player(id: '1', name: 'Foc'),
      X01Player(id: '2', name: 'Sophie'),
    ]);
    Map<String, dynamic> st() =>
        {'screen': 'game', 'game': jsonDecode(jsonEncode(g.toJson()))};
    tv.debugSetState('KX7P', st());
    await tester.pump(const Duration(milliseconds: 300));
    g.throwDart(const DartHit(25, 2, Ring.innerBull));
    tv.debugSetState('KX7P', st());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(AwardPlayer.active, isTrue);
    AwardPlayer.stop();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Partie abandonnée : l\'écran TV revient tout de suite à l\'accueil',
      (tester) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final tv = TvClient(realtime: false);
    await tester.runAsync(() async {
      await tv.start();
      await TvLink.instance.link(tv.code!);
    });
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => GamePage(
                            game: X01Game(const X01Settings(), const [
                              X01Player(id: 'guest-1', name: 'A'),
                              X01Player(id: 'guest-2', name: 'B'),
                            ])))),
                child: const Text('GO')))));
    await tester.tap(find.text('GO'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() async {
      await settle();
      await tv.fetch();
    });
    expect(tv.state?['screen'], 'game');
    // Retour → Abandonner
    tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Abandonner'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() async {
      await settle();
      await tv.fetch();
    });
    expect(tv.state?['screen'], 'lobby');
    expect(find.byType(GamePage), findsNothing);
    await tester.runAsync(() => TvLink.instance.unlinkAll());
    tv.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('Musique des menus : l\'écran joue le même morceau que le téléphone',
      () async {
    final audio = AudioService.instance;
    final tv = TvClient(realtime: false);
    await tv.start();
    await TvLink.instance.link(tv.code!);
    await settle();
    await tv.fetch();
    final m = tv.state?['music'] as Map;
    expect(m['t'], audio.menuTrack);
    expect(m['t'], isIn(AudioService.kMenuTracks));
    // l'écran suit (ici le même AudioService : on vérifie le choix du morceau)
    final other =
        AudioService.kMenuTracks.firstWhere((t) => t != audio.menuTrack);
    audio.followMusic(other, 0);
    expect(audio.menuTrack, other);
    // même morceau et même compteur : rien ne change (pas de retour en
    // arrière quand l'écran passe tout seul au morceau suivant)
    audio.followMusic(other, 0);
    expect(audio.menuTrack, other);
    // un nouveau morceau lancé sur le téléphone est renvoyé à l'écran
    final before = tv.state?['at'];
    audio.musicStarts.value++;
    await settle();
    await tv.fetch();
    expect(tv.state?['at'], isNot(before));
    expect((tv.state?['music'] as Map)['n'], audio.musicStarts.value);
    await TvLink.instance.unlinkAll();
    tv.dispose();
  });

  test('Animations de l\'écran : allégées par défaut, complètes sur demande',
      () async {
    final tv = TvClient(realtime: false);
    await tv.start();
    await TvLink.instance.link(tv.code!);
    await settle();
    await tv.fetch();
    expect(tv.state?['anim'], isFalse);
    await TvLink.instance.setFullAnim(true);
    await settle();
    await tv.fetch();
    expect(tv.state?['anim'], isTrue);
    await TvLink.instance.setFullAnim(false);
    await TvLink.instance.unlinkAll();
    tv.dispose();
  });

  test('Vue du Cricket changée : renvoyée tout de suite aux écrans',
      () async {
    final tv = TvClient(realtime: false);
    await tv.start();
    await TvLink.instance.link(tv.code!);
    await settle();
    await CricketStyle.choose(CricketStyle.classic);
    await settle();
    await CricketStyle.toggle();
    await settle();
    await tv.fetch();
    expect(tv.state?['cricket'], CricketStyle.columns);
    await CricketStyle.choose(CricketStyle.classic);
    await TvLink.instance.unlinkAll();
    tv.dispose();
  });
}
