import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/calibration_page.dart';
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
    expect(find.text('FREEZE 301'), findsOneWidget);
    expect(find.text('ÉQUIPE A'), findsWidgets);

    await tester.tap(find.text('RATÉ'));
    await tester.pump();
    expect(find.text('RATÉ'), findsWidgets);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('SUIVANT'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('RÉSULTATS'), findsOneWidget);

    await tester.tap(find.text('RÉSULTATS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LIMITE DE 1 MANCHES'), findsOneWidget);
    expect(PlayerStore.instance.players.first.games, 1);
  });

  testWidgets('Réglages et joueurs s\'affichent', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const SetupPage()));
    await tester.pumpAndSettle();
    expect(find.text('LANCER 501'), findsOneWidget);
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

  testWidgets('Calibration : avance, refuse un doublon, passe', (tester) async {
    await phone(tester);
    final board = BoardService.instance;
    await tester.pumpWidget(app(const CalibrationPage()));
    await tester.pumpAndSettle();
    expect(find.text('VISE : SIMPLE INTÉRIEUR 20'), findsOneWidget);

    board.injectFrame('7.7@'.codeUnits);
    await tester.pump();
    await tester.pump();
    expect(find.text('VISE : TRIPLE 20'), findsOneWidget);

    board.injectFrame('7.7@'.codeUnits); // doublon : refusé
    await tester.pump();
    await tester.pump();
    expect(find.text('VISE : TRIPLE 20'), findsOneWidget);

    board.injectFrame('BTN@'.codeUnits); // bouton ignoré
    await tester.pump();
    await tester.pump();
    expect(find.text('VISE : TRIPLE 20'), findsOneWidget);

    await tester.tap(find.text('PASSER'));
    await tester.pump();
    expect(find.text('VISE : SIMPLE EXTÉRIEUR 20'), findsOneWidget);

    // Passe le reste puis teste l'étape bordure
    for (var i = 2; i < kCalTargets.length; i++) {
      await tester.tap(find.text('PASSER'));
      await tester.pump();
    }
    expect(find.text('BORDURE EXTÉRIEURE'), findsOneWidget);
    board.injectFrame('OUT1@'.codeUnits);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('1 code(s) de bordure'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
