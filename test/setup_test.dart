import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/setup_widgets.dart';
import 'package:granboard_proto/ui/game_theme.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

/// Ajoute un joueur virtuel par la fenêtre « Ajouter ».
Future<void> addGuest(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('players-add')));
  await tester.tap(find.byKey(const ValueKey('players-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-guest')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('add-done')));
  await tester.pumpAndSettle();
}

Future<void> addBot(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('players-add')));
  await tester.tap(find.byKey(const ValueKey('players-add')));
  await tester.pumpAndSettle();
  // adversaire virtuel : Enzo (le 1er, toujours débloqué)
  await tester.tap(find.byKey(const ValueKey('add-persona')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('persona-enzo')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('persona-add')));
  await tester.tap(find.byKey(const ValueKey('persona-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-done')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    await PlayerStore.instance.register('Foc', '1234');
  });

  Future<void> open(WidgetTester tester, String kind) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: SetupPage(key: ValueKey(kind), kind: kind)));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Ajouter des joueurs : joueurs choisis en pastilles (10 sur 2 lignes)',
      (tester) async {
    await open(tester, 'cricket');
    await tester.ensureVisible(find.byKey(const ValueKey('players-add')));
    await tester.tap(find.byKey(const ValueKey('players-add')));
    await tester.pumpAndSettle();
    expect(find.text('DANS LA PARTIE · ORDRE DE JEU'), findsOneWidget);
    // Foc (profil principal coché d'office) + 9 invités
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byKey(const ValueKey('add-guest')));
      await tester.pump();
    }
    expect(find.text('10/10'), findsOneWidget);
    final pills = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('in-') &&
        !(w.key as ValueKey<String>).value.startsWith('in-rm-'));
    expect(pills, findsNWidgets(10));
    final rows = {
      for (final e in pills.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy.round()
    };
    expect(rows.length, lessThanOrEqualTo(2));
    expect(find.text('Invité 9'), findsWidgets);
    // la croix retire le joueur
    final first = (pills.evaluate().last.widget.key as ValueKey<String>)
        .value
        .substring(3);
    await tester.tap(find.byKey(ValueKey('in-rm-$first')));
    await tester.pump();
    expect(find.text('9/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Favoris : ajout, application, à part pour chaque tuile',
      (tester) async {
    await open(tester, 'x01');
    expect(find.text('LANCER 501'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-301')));
    await tester.pump();
    expect(find.text('301 · DOUBLE OUT'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fav-add')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('301 · Double Out'), findsWidgets);

    // On change, puis le favori remet 301
    await tester.tap(find.byKey(const ValueKey('game-701')));
    await tester.pump();
    expect(find.text('LANCER 701'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fav-0')));
    await tester.pump();
    expect(find.text('LANCER 301'), findsOneWidget);

    // Les favoris du 01 ne sont pas ceux du Cricket
    expect(await tester.runAsync(() => SetupFavorites.of('cricket')), isEmpty);
    await open(tester, 'cricket');
    expect(find.byKey(const ValueKey('fav-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('game-cutThroat')));
    await tester.pump();
    expect(find.text('LANCER CUT THROAT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Freeze avec un nombre impair de joueurs : message, pas d\'écran blanc',
      (tester) async {
    await open(tester, 'x01');
    for (final n in [1, 2, 3, 4]) {
      if (n > 1) {
        await addGuest(tester);
      }
      if (n == 1) {
        await tester.ensureVisible(find.text('Freeze (équipes)'));
        await tester.tap(find.text('Freeze (équipes)'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull, reason: '$n joueur(s)');
      expect(
          find.textContaining(n == 1
              ? 'Le Freeze se joue à 2 équipes'
              : 'Les 2 équipes doivent avoir autant de joueurs'),
          n.isOdd ? findsWidgets : findsNothing,
          reason: '$n joueur(s)');
    }
  });

  testWidgets('Joueurs : « Tout vider » retire tous les joueurs choisis',
      (tester) async {
    await open(tester, 'x01');
    // le profil principal est coché d'office ; on ajoute un joueur virtuel
    expect(find.text('JOUEURS (1)'), findsOneWidget);
    await addBot(tester);
    expect(find.text('JOUEURS (2)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('players-clear')));
    await tester.tap(find.byKey(const ValueKey('players-clear')));
    await tester.pump();
    expect(find.text('JOUEURS (0)'), findsOneWidget);
    expect(find.byKey(const ValueKey('players-clear')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Toutes les tuiles s\'affichent sans débordement',
      (tester) async {
    for (final k in ['x01', 'cricket', 'match', 'practice', 'party']) {
      await open(tester, k);
      expect(find.text('CHOISIR LE JEU'), findsOneWidget);
      expect(find.text('RÈGLES'), findsWidgets);
      expect(find.text('JOUEURS (1)'), findsOneWidget);
      final band = tester.widget<SetupBand>(find.byType(SetupBand));
      expect(band.sub, 'Configuration');
      expect(find.byKey(const ValueKey('fav-add')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: k);
    }
    tester.view.physicalSize = const Size(1280, 720); // 640 × 360
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(), home: const SetupPage(tournament: true)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nom du tournoi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le tableau prend le thème du jeu, pas celui de l\'appli',
      (tester) async {
    final old = Tv.skin.value;
    addTearDown(() => Tv.skin.value = old);
    Tv.skin.value = AppSkin.neon;
    for (final (k, skin) in [
      ('x01', GameSkins.x01),
      ('cricket', GameSkins.cricket),
      ('party', GameSkins.party),
    ]) {
      await open(tester, k);
      await tester.pump();
      expect(Tv.current, same(skin), reason: k);
      final panel = find.byType(TableauPanel).first;
      final container = tester.widget<Container>(
          find.descendant(of: panel, matching: find.byType(Container)).first);
      expect((container.decoration! as BoxDecoration).color,
          skin.panel.withValues(alpha: 0.9), reason: k);
    }
    // page fermée : le thème de l'appli revient
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(Tv.current, same(AppSkin.neon));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Configurations en tableau sur petit écran', (tester) async {
    for (final k in ['x01', 'cricket', 'match', 'practice', 'party']) {
      await open(tester, k);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 2;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('JOUEURS (1)'), findsOneWidget, reason: k);
      expect(find.byKey(const ValueKey('fav-add')), findsOneWidget, reason: k);
      expect(tester.takeException(), isNull, reason: k);
    }
  });

  testWidgets('Chaque jeu : ses réglages s\'affichent sans débordement',
      (tester) async {
    final errors = <String>[];
    Future<void> each(String tile, Iterable<String> keys) async {
      await open(tester, tile);
      for (final k in keys) {
        final f = find.byKey(ValueKey('game-$k'));
        if (f.evaluate().isEmpty) {
          errors.add('$tile : $k absent');
          continue;
        }
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 300));
        final e = tester.takeException();
        if (e != null) errors.add('$tile/$k : ${'$e'.split('\n').first}');
      }
    }

    await each('cricket', CricketVariant.values.map((v) => v.name));
    await each('practice', [
      for (final k in PracticeKind.values)
        if (!kPracticeInfo[k]!.party) k.name
    ]);
    await each('party', [
      for (final k in PracticeKind.values)
        if (kPracticeInfo[k]!.party) k.name
    ]);
    expect(errors, isEmpty, reason: errors.join('\n'));
  });

  testWidgets('Medley : chaque leg a son jeu (301, Cricket, 501…)',
      (tester) async {
    await open(tester, 'match');
    // Par défaut : 501, Cricket, 501
    expect(find.textContaining(RegExp('501-CR-501', caseSensitive: false)), findsWidgets);
    // Leg 1 en 301
    await tester.tap(find.byKey(const ValueKey('mleg-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('301').last);
    await tester.pumpAndSettle();
    // Leg 2 en 701 (il était en Cricket)
    await tester.tap(find.byKey(const ValueKey('mleg-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('701').last);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('301-701-501', caseSensitive: false)), findsWidgets);
    // Leg 3 en Cricket
    await tester.tap(find.byKey(const ValueKey('mleg-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cricket').last);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('301-701-CR', caseSensitive: false)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Encoche à gauche ou à droite : même écran, bandeaux jusqu\'aux bords',
      (tester) async {
    Future<(Rect, Rect)> place(FakeViewPadding pad) async {
      tester.view.physicalSize = const Size(2340, 1080);
      tester.view.devicePixelRatio = 2.75;
      tester.view.padding = pad;
      tester.view.viewPadding = pad;
      await tester.pumpWidget(MaterialApp(
          key: UniqueKey(),
          theme: Tv.theme(),
          builder: Tv.appBuilder,
          home: const SetupPage(kind: 'x01')));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      return (
        tester.getRect(find.byKey(const ValueKey('players-add'))),
        tester.getRect(find.byType(SetupBand)),
      );
    }

    addTearDown(tester.view.reset);
    final (addL, bandL) = await place(const FakeViewPadding(left: 110));
    final (addR, bandR) = await place(const FakeViewPadding(right: 110));
    expect(addL, addR);
    expect(bandL.left, 0);
    expect(bandL.width, 2340 / 2.75);
    expect(bandR, bandL);
    expect(tester.takeException(), isNull);
  });
}
