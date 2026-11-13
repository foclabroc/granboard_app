import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/ui/award.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  testWidgets(
      'Écran TV : vidéo du T20 lancée, erreur affichée, son habituel à la place',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    final tv = TvClient(realtime: false);
    const ps = [
      X01Player(id: 'guest-1', name: 'Ana'),
      X01Player(id: 'guest-2', name: 'Bob'),
    ];
    final g = X01Game(const X01Settings(startScore: 501), ps);
    Map<String, dynamic> state() =>
        {'screen': 'game', 'host': 'Foc', 'game': g.toJson(), 'sound': true};
    tv.debugSetState('ABCD', state());
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: TvHome(client: tv)));
    await tester.pump(const Duration(seconds: 1));

    AudioService.instance
      ..voice = true
      ..dartCalls = true
      ..said.clear();
    AwardPlayer.enabled = true;
    addTearDown(() => AwardPlayer.enabled = false);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    tv.debugSetState('ABCD', state());
    await tester.pump();
    expect(AwardPlayer.active, isTrue); // la TV lance bien la vidéo
    // Pas de lecteur vidéo en test : l'erreur s'affiche sur l'écran
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('video-error')), findsOneWidget);
    expect(AwardPlayer.active, isFalse);
    // … et l'annonce de la fléchette à la place du son de la vidéo
    expect(AudioService.instance.said, contains('triple 20'));
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const ValueKey('video-error')), findsNothing);
    AwardPlayer.enabled = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
