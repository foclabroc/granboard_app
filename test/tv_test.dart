import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
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
    final tv = TvClient(realtime: false);
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

    // Un autre téléphone prend la main : le premier est déconnecté
    final hostBefore = server.tvRooms[tv.code]!['host'];
    server.tvRooms[tv.code]!['host'] = 'autre';
    TvLink.instance.pushLobby();
    await settle();
    expect(TvLink.instance.linked, isFalse);
    expect(AudioService.instance.muted, isFalse);
    expect(hostBefore, isNotNull);
    tv.dispose();
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
}
