import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/media.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/calibration_page.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/players_page.dart';
import 'package:granboard_proto/ui/rules.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/account_page.dart';
import 'package:granboard_proto/ui/ranking_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/turn_banner.dart';
import 'package:granboard_proto/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:granboard_proto/server.dart';

import 'fake_server.dart';

Widget app(Widget home) => MaterialApp(theme: Tv.theme(), home: home);

Future<void> phone(WidgetTester tester) async {
  // Téléphone en paysage (785 × 392)
  tester.view.physicalSize = const Size(2160, 1080);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

void main() {
  late List<X01Player> four;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    final store = PlayerStore.instance;
    for (final n in ['Foc', 'Sophie', 'Léo']) {
      await store.register(n, '1234');
    }
    final ps = store.players;
    four = [
      X01Player(id: ps[0].key, name: ps[0].name, team: 0),
      X01Player(id: ps[1].key, name: ps[1].name, team: 1),
      X01Player(id: ps[2].key, name: ps[2].name, team: 0),
      const X01Player(id: 'guest-1', name: 'Invité 1', team: 1),
    ];
  });

  testWidgets('Partie Freeze : affichage, raté, suivant, fin, résultats',
      (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301, freeze: true, roundLimit: 1),
      players: four,
    )));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('FREEZE 301'), findsOneWidget);
    expect(find.text('ÉQUIPE A'), findsWidgets);

    await tester.tap(find.text('RATÉ'));
    await tester.pump();
    expect(find.text('RATÉ'), findsWidgets);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('SUIVANT'));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('RÉSULTATS'), findsOneWidget);

    await tester.tap(find.text('RÉSULTATS'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.textContaining('LIMITE DE 1 MANCHES'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Bandeau « au tour de » après Suivant', (tester) async {
    await phone(tester);
    TurnBanner.enabled = true;
    addTearDown(() => TurnBanner.enabled = false);
    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301),
      players: four.take(2).toList(),
    )));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('AU TOUR DE'), findsNothing);
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('AU TOUR DE'), findsOneWidget);
    expect(find.text(four[1].name.toUpperCase()), findsWidgets);
    expect(tester.takeException(), isNull);
    // Il ne bloque pas l'écran et disparaît seul
    await tester.tap(find.text('RATÉ').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AU TOUR DE'), findsNothing);
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AU TOUR DE'), findsNothing);
    // Pas de bandeau en solo
    await tester.pumpWidget(app(GamePage(
      key: const ValueKey('solo'),
      settings: const X01Settings(startScore: 301),
      players: four.take(1).toList(),
    )));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('SUIVANT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('AU TOUR DE'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Bouton Règles : réglages et partie', (tester) async {
    await phone(tester);
    for (final kind in ['x01', 'cricket', 'match', 'practice', 'party']) {
      await tester.pumpWidget(app(SetupPage(key: ValueKey(kind), kind: kind)));
      await tester.pump(const Duration(milliseconds: 300));
      // Ouvert depuis l'accueil : ce jeu seulement, pas le choix du jeu
      expect(find.text('NOUVELLE PARTIE'), findsNothing);
      expect(find.text('ENTRAÎN.'), findsNothing);
      await tester.tap(find.byType(RulesButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('RÈGLES · '), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301, roundLimit: 10),
      players: four.take(2).toList(),
    )));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Règles'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('RÈGLES · 301'), findsOneWidget);
    expect(find.textContaining('Double Out'), findsOneWidget);
    expect(find.textContaining('Limite de 10 manches'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Réglages et joueurs s\'affichent', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const SetupPage()));
    await tester.pumpAndSettle();
    expect(find.text('LANCER 501'), findsOneWidget);
    await tester.tap(find.text('Foc'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoute au moins un joueur'), findsNothing);

    await tester.pumpWidget(app(const PlayersPage()));
    await tester.pumpAndSettle();
    expect(find.text('SOPHIE'), findsOneWidget);
    await tester.tap(find.text('SOPHIE'));
    await tester.pumpAndSettle();
    expect(find.text('DERNIÈRES PARTIES'), findsOneWidget);
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

  testWidgets('Compte : création avec le pavé numérique', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const AccountPage(create: true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Marc');
    for (final k in ['4', '3', '2', '1']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('CONFIRME LE CODE'), findsOneWidget);
    for (final k in ['4', '3', '2', '1']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(PlayerStore.instance.byId('4')?.name, 'Marc');
  });

  testWidgets('Joueur : choix de la couleur et d\'un avatar', (tester) async {
    await phone(tester);
    final p = PlayerStore.instance.players.first;
    await tester.pumpWidget(app(PlayerDetailPage(player: p)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('COULEUR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ColorDot), findsNWidgets(kPlayerColors.length + 1));
    await tester.tap(find.byKey(const ValueKey('color-15')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(isRainbow(p.color), isTrue);

    await tester.tap(find.byType(PlayerAvatar).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PRENDRE UNE PHOTO'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-fox')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-target')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('avatar-robot')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(MediaStore.instance.imageOf(p.key), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Classements s\'affichent', (tester) async {
    await phone(tester);
    // Un joueur du serveur qui n'est pas sur ce téléphone
    await GbServer.register('Max', '1234', 0);
    RankingPage.mineOnly.value = false;
    await tester.pumpWidget(app(const RankingPage()));
    await tester.pumpAndSettle();
    expect(find.text('LÉO'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('MES JOUEURS'));
    await tester.pumpAndSettle();
    expect(find.text('LÉO'), findsOneWidget);
    expect(find.text('MAX'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('TOUS'));
    await tester.pumpAndSettle();
    expect(find.text('MAX'), findsOneWidget);
  });
}
