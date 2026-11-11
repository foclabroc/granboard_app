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
    expect(link.soundOn, TvLink.phone,
        reason: 'une tablette ne prend pas le son');
    expect(AudioService.instance.muted, isFalse);
    await link.link(tv.code!);
    expect(link.screens.length, 2);
    expect(link.soundOn, tv.code, reason: 'la TV prend le son');
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

    // Retirer l'écran qui a le son : le son revient au téléphone
    await link.setSoundOn(tv.code!);
    await link.unlink(tv.code!);
    expect(link.soundOn, TvLink.phone);
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

    tv.debugSetState('KX7P', {'screen': 'lobby', 'host': 'Foc'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('RELIÉ À FOC'), findsOneWidget);

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
}
