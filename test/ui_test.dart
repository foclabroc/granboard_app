import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/match.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/media.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/calibration_page.dart';
import 'package:granboard_proto/ui/cricket_view.dart';
import 'package:granboard_proto/ui/dartboard.dart';
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
import 'package:granboard_proto/ui/stats_page.dart';

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
    // Partie finie : les résultats s'ouvrent tout seuls
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RÉSULTATS'), findsOneWidget);
    expect(find.textContaining('LIMITE DE 1 MANCHE'), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.textContaining('LIMITE DE 1 MANCHE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Option AUTO : joueur suivant 5 s après les 3 fléchettes',
      (tester) async {
    await phone(tester);
    await AutoNext.set(true);
    addTearDown(() => AutoNext.set(false));
    final page = GamePage(
      settings: const X01Settings(startScore: 301),
      players: four.take(2).toList(),
    );
    await tester.pumpWidget(app(page));
    await tester.pump(const Duration(seconds: 1));
    final state = tester.state(find.byType(GamePage)) as dynamic;
    for (var i = 0; i < 3; i++) {
      BoardService.instance
          .injectFrame(GranBoardDecoder.frameFor(5, Ring.singleOuter)!.codeUnits);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('auto-next')), findsOneWidget);
    expect(find.textContaining('JOUEUR SUIVANT DANS'), findsOneWidget);
    expect((state.game as X01Game).current, 0);
    await tester.pump(const Duration(seconds: 3));
    expect((state.game as X01Game).current, 0);
    await tester.pump(const Duration(seconds: 3));
    expect((state.game as X01Game).current, 1, reason: 'suivant tout seul');
    expect(find.textContaining('JOUEUR SUIVANT DANS'), findsNothing);

    // coupé : on attend « Suivant »
    await AutoNext.set(false);
    for (var i = 0; i < 3; i++) {
      BoardService.instance
          .injectFrame(GranBoardDecoder.frameFor(5, Ring.singleOuter)!.codeUnits);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 7));
    expect((state.game as X01Game).current, 1);
    await tester.pumpWidget(const SizedBox());
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
    // Dès le début : le 1er joueur a son bandeau
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('AU TOUR DE'), findsOneWidget);
    expect(find.text(four[0].name.toUpperCase()), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
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
    expect(find.text('AU TOUR DE'), findsOneWidget); // encore là à 2 s
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AU TOUR DE'), findsNothing); // parti après 3 s
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
      await tester.pumpAndSettle();
      expect(find.textContaining('RÈGLES · '), findsOneWidget);
      expect(find.text('BUT'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('sheet-close')));
      await tester.pumpAndSettle();
      expect(find.textContaining('RÈGLES · '), findsNothing);
    }
    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301, roundLimit: 10),
      players: four.take(2).toList(),
    )));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Règles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('RÈGLES · 301'), findsOneWidget);
    expect(find.textContaining('doit être un double'), findsOneWidget);
    expect(find.text('LIMITE DE MANCHES'), findsOneWidget);
    expect(find.textContaining('Après 10 manches'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pump(const Duration(seconds: 2));
  });

  test('Règles détaillées pour tous les jeux et toutes les variantes', () {
    for (final k in PracticeKind.values) {
      final r = practiceRules(PracticeSettings(k));
      expect(r, startsWith('# BUT'), reason: k.name);
      expect(r.split('\n').length, greaterThan(4), reason: k.name);
    }
    for (final v in CricketVariant.values) {
      for (final teams in [false, true]) {
        final r = cricketRules(CricketSettings(variant: v, teams: teams));
        expect(r, startsWith('# BUT'), reason: v.name);
      }
    }
    expect(x01Rules(const X01Settings(freeze: true)), contains('GELÉE'));
    expect(matchFullRules(const MatchSettings()), contains('LEGS DE CRICKET'));
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

  testWidgets('Joueur : cible choisie, utilisée pendant son tour',
      (tester) async {
    await phone(tester);
    final p = PlayerStore.instance.players.first;
    await tester.pumpWidget(app(PlayerDetailPage(player: p)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CIBLE : PAR DÉFAUT'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('player-board')));
    await tester.tap(find.byKey(const ValueKey('player-board')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('pboard-neon')));
    await tester.tap(find.byKey(const ValueKey('pboard-neon')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(PlayerBoards.instance.of(p.key), BoardSkin.neon);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('CIBLE : NÉON'), findsOneWidget);

    await tester.pumpWidget(app(GamePage(
      settings: const X01Settings(startScore: 301),
      players: four.sublist(0, 2),
    )));
    await tester.pump(const Duration(seconds: 2));
    AnimatedDartboard board() =>
        tester.widget<AnimatedDartboard>(find.byType(AnimatedDartboard));
    expect(board().skin, BoardSkin.neon);
    await tester.tap(find.text('SUIVANT'));
    await tester.pump(const Duration(seconds: 2));
    expect(board().skin, isNull); // Sophie : style général
    await PlayerBoards.instance.set(p, null);
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
    expect(find.byKey(const ValueKey('avatar-bullseye')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-ice')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('avatar-crown')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(MediaStore.instance.imageOf(p.key), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cricket en lignes : 10 joueurs, bascule de vue', (tester) async {
    await phone(tester);
    await CricketStyle.choose(CricketStyle.columns);
    addTearDown(() => CricketStyle.current.value = CricketStyle.classic);
    final g = CricketGame(const CricketSettings(), [
      for (var i = 0; i < 10; i++) X01Player(id: 'guest-$i', name: 'Joueur $i')
    ]);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    await tester.pumpWidget(app(GamePage(game: g)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(ValueKey('cricket-row-$i')), findsOneWidget);
    }
    // Ligne du joueur en cours plus haute
    final cur = tester.getSize(find.byKey(const ValueKey('cricket-row-0')));
    final other = tester.getSize(find.byKey(const ValueKey('cricket-row-1')));
    expect(cur.height, greaterThan(other.height));

    await tester.tap(find.text('SUIVANT'));
    await tester.pump(const Duration(seconds: 2));
    final now = tester.getSize(find.byKey(const ValueKey('cricket-row-1')));
    expect(
        now.height,
        greaterThan(tester
            .getSize(find.byKey(const ValueKey('cricket-row-0')))
            .height));

    // Bouton VUE : retour à la vue classique
    await tester.tap(find.byKey(const ValueKey('cricket-style')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(CricketStyle.current.value, CricketStyle.classic);
    expect(find.byKey(const ValueKey('cricket-row-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Partie finie quittée par retour : stats envoyées quand même',
      (tester) async {
    await phone(tester);
    final server = FakeServer()..install();
    final p = await PlayerStore.instance.register('Retour', '1234');
    final g = X01Game(const X01Settings(startScore: 301, roundLimit: 1),
        [X01Player(id: p.key, name: p.name)]);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    g.next();
    expect(g.finished, isTrue);
    await tester.pumpWidget(app(Builder(
        builder: (c) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.push(
                    c, MaterialPageRoute(builder: (_) => GamePage(game: g))),
                child: const Text('go'))))));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 2));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('go'), findsOneWidget,
        reason: 'page quittée sans question');
    expect(server.games.length, 1, reason: 'partie envoyée');
  });

  testWidgets('Stats et rang d\'un joueur, tableau des rangs', (tester) async {
    await phone(tester);
    final server = FakeServer()..install();
    final p = await PlayerStore.instance.register('Rang', '1234');
    server.statsOf[p.id] = {
      'id': p.id,
      'pseudo': 'Rang',
      'color': 1,
      'g80': {
        'ppr': 43.42,
        'mpr': 1.88,
        'r01': 3.68,
        'rcr': 5.4,
        'rating': 4.54
      },
      'g100': {
        'ppr': 40.1,
        'mpr': 1.7,
        'r01': 3.02,
        'rcr': 4.5,
        'rating': 3.76
      },
      's01': [
        for (var i = 0; i < 12; i++) {'d': '2026-11-01', 'v': 30 + i * 2}
      ],
      'scr': [
        for (var i = 0; i < 30; i++)
          {'d': '2026-11-01', 'v': 1.5 + (i % 5) * 0.2}
      ],
      'practice': {
        'countUp': {'games': 3, 'best': 447, 'avg': 380.5},
        'halfIt': {'games': 1, 'best': 120, 'avg': 120},
      },
    };
    await tester.pumpWidget(
        app(PlayerStatsPage(id: p.key, name: p.name, color: kPlayerColors[1])));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('CC'), findsWidgets);
    expect(find.text('4,54'), findsWidgets);
    expect(find.text('43,42'), findsWidgets);
    expect(find.text('B'), findsOneWidget, reason: 'rang suivant');
    expect(find.text('1,46'), findsOneWidget, reason: '6 - 4,54');
    // 100 % : autres chiffres
    await tester.tap(find.text('100 %'));
    await tester.pump();
    expect(find.text('3,76'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('COUNT UP'), findsOneWidget);
    // Tableau des rangs, fermé par la croix
    await tester.tap(find.byKey(const ValueKey('rank-table')));
    await tester.pumpAndSettle();
    expect(find.text('GM'), findsOneWidget);
    expect(find.text('142,00-'), findsOneWidget);
    expect(find.text('35,00-39,99'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('142,00-'), findsNothing);
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
