import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/players.dart';
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
  });

  testWidgets('Premier lancement : « Plus tard » ne revient pas',
      (tester) async {
    await phone(tester);
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    expect(find.text('CRÉER MON PROFIL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('PLUS TARD'));
    await frames(tester);
    expect(find.text('CRÉER MON PROFIL'), findsNothing);
    expect(PlayerStore.instance.welcomed, isTrue);
    await PlayerStore.instance.load();
    expect(PlayerStore.instance.welcomed, isTrue);
  });

  testWidgets('Premier lancement : le compte créé devient le profil principal',
      (tester) async {
    await phone(tester);
    final store = PlayerStore.instance;
    await store.register('Léo', '1234');
    final leo = store.players.first;
    await store.register('Foc', '1234');
    final foc = store.players.last;
    expect(store.owner, leo);
    await store.setOwner(foc);
    expect(store.owner, foc);
    expect(store.isOwner(leo), isFalse);
    await store.load();
    expect(store.owner!.name, 'Foc');

    // Avec des comptes, pas d'accueil
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    expect(find.text('CRÉER MON PROFIL'), findsNothing);
  });
}
