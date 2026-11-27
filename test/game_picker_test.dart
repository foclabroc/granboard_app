import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/game_picker_page.dart';
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
    await tester.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: GamePickerPage(kind: kind)));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('Chaque famille a ses jeux dans la mosaïque', () {
    expect(pickItems('x01').map((i) => i.id),
        ['301', '501', '701', '901', 'freeze']);
    expect(pickItems('cricket').length, 8);
    final party = [
      for (final k in PracticeKind.values)
        if (kPracticeInfo[k]!.party) k.name
    ];
    expect(pickItems('party').map((i) => i.id), party);
    expect(pickItems('practice').length,
        PracticeKind.values.length - party.length);
  });

  testWidgets('01 : toucher 701 ouvre ses réglages sans « Choisir le jeu »',
      (tester) async {
    await open(tester, 'x01');
    expect(find.byKey(const ValueKey('pick-freeze')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-701')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byKey(const ValueKey('players-add')), findsOneWidget);
    expect(find.text('CHOISIR LE JEU'), findsNothing);
    expect(find.textContaining('701'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('01 : Freeze propose le score de départ', (tester) async {
    await open(tester, 'x01');
    await tester.tap(find.byKey(const ValueKey('pick-freeze')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byKey(const ValueKey('freeze-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Party : la mosaïque défile vers le bas jusqu\'au dernier jeu',
      (tester) async {
    await open(tester, 'party');
    final last = pickItems('party').last.id;
    // tout en bas, hors de l'écran au départ
    expect(
        tester.getTopLeft(find.byKey(ValueKey('pick-$last'))).dy,
        greaterThan(
            tester.view.physicalSize.height / tester.view.devicePixelRatio));
    await tester.scrollUntilVisible(find.byKey(ValueKey('pick-$last')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(ValueKey('pick-$last')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pick-$last')));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byKey(const ValueKey('players-add')), findsOneWidget);
    expect(find.text('CHOISIR LE JEU'), findsNothing);
    expect(
        find.textContaining(kPracticeInfo[PracticeKind.values.byName(last)]!
            .name
            .toUpperCase()),
        findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
