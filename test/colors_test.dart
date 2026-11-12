import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
  });

  testWidgets('Partie : toutes les couleurs différentes, comptes inchangés',
      (tester) async {
    final store = PlayerStore.instance;
    final a = await store.register('Foc', '1234');
    final b = await store.register('Léo', '1234');
    await tester.runAsync(() => store.setColor(b, a.colorIndex));
    expect(b.color, a.color, reason: 'même couleur de compte');
    final players = [
      X01Player(id: a.key, name: 'Foc'),
      X01Player(id: b.key, name: 'Léo', team: 1),
      for (var i = 1; i <= 6; i++)
        X01Player(id: 'guest-$i', name: 'Invité $i', team: i % 2),
      const X01Player(id: 'guest-bot1', name: 'Bot 1'),
    ];
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: GamePage(settings: const X01Settings(), players: players)));
    await tester.pump(const Duration(milliseconds: 300));
    final colors = [for (final p in players) store.colorOf(p.id).toARGB32()];
    expect(colors.toSet().length, players.length, reason: '$colors');
    expect(store.colorOf(a.key), a.color, reason: 'le 1er garde la sienne');
    expect(b.color, a.color, reason: 'le compte garde sa couleur');
    expect(colors.contains(kRainbow.toARGB32()), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('15 couleurs automatiques sans l\'arc-en-ciel', () {
    final ids = [for (var i = 1; i <= 15; i++) 'guest-$i'];
    final cs = PlayerStore.instance.distinctColors(ids);
    expect(cs.map((c) => c.toARGB32()).toSet().length, 15);
    expect(cs.contains(kRainbow), isFalse);
  });
}
