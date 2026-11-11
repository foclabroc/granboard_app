import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/players_page.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    );

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

void main() {
  late List<X01Player> four;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    final store = PlayerStore.instance;
    for (final n in ['Foc', 'Sophie', 'Léo', 'Marc']) {
      await store.add(n);
    }
    final ps = store.players;
    four = [
      X01Player(id: ps[0].id, name: ps[0].name, team: 0),
      X01Player(id: ps[1].id, name: ps[1].name, team: 1),
      X01Player(id: ps[2].id, name: ps[2].name, team: 0),
      X01Player(id: ps[3].id, name: ps[3].name, team: 1),
    ];
  });

  testWidgets('Partie Freeze : affichage, raté, suivant, fin, résultats',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301, freeze: true, roundLimit: 1),
      players: four,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Freeze 301'), findsOneWidget);
    expect(find.text('Équipe A'), findsWidgets);

    await tester.tap(find.text('Raté'));
    await tester.pump();
    expect(find.text('Raté'), findsWidgets);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Résultats'), findsOneWidget);

    await tester.tap(find.text('Résultats'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Limite de 1 manches'), findsOneWidget);
    expect(PlayerStore.instance.players.first.games, 1);
  });

  testWidgets('Réglages et joueurs s\'affichent', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const SetupPage()));
    await tester.pumpAndSettle();
    expect(find.text('Lancer 501'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Foc'), 200);
    await tester.tap(find.text('Foc'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoute au moins un joueur'), findsNothing);

    await tester.pumpWidget(app(const PlayersPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sophie'), findsOneWidget);
    await tester.tap(find.text('Sophie'));
    await tester.pumpAndSettle();
    expect(find.text('Dernières parties'), findsOneWidget);
  });
}
