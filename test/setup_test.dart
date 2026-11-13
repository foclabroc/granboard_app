import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/cricket.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/setup_widgets.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

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

  testWidgets('Toutes les tuiles s\'affichent sans débordement',
      (tester) async {
    for (final k in ['x01', 'cricket', 'match', 'practice', 'party']) {
      await open(tester, k);
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
}
