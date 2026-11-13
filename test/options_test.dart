import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/home_page.dart';
import 'package:granboard_proto/ui/options_page.dart';
import 'package:granboard_proto/ui/players_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'welcome_done_v1': true});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
  });

  testWidgets('Tuile OPTIONS : joueurs à gauche, réglages à droite',
      (tester) async {
    await phone(tester);
    final store = PlayerStore.instance;
    await store.register('Foc', '1234');
    await store.register('Ced', '1234');
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    await frames(tester);
    expect(find.text('2 JOUEURS · RÉGLAGES'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tile-options')));
    await frames(tester);
    expect(find.byType(OptionsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('JOUEURS (2)'), findsOneWidget);
    expect(find.text('FOC'), findsOneWidget);
    expect(find.text('CED'), findsOneWidget);
    expect(find.text('Thème de l\'appli'), findsOneWidget);

    // Un joueur : sa fiche
    await tester.tap(find.text('CED'));
    await frames(tester);
    expect(find.byType(PlayerDetailPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(PlayerDetailPage))).pop();
    await frames(tester);

    // Thème : la fenêtre de choix s'ouvre
    await tester.tap(find.byKey(const ValueKey('opt-theme')));
    await frames(tester);
    expect(find.text('THÈME DE L\'APPLI'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
