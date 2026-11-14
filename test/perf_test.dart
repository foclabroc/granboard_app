// Écran TV (Perf.lite) : aucune animation continue, l'écran se fige entre
// deux coups (pumpAndSettle finit), mais une fléchette s'anime encore.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/ui/dartboard.dart';
import 'package:granboard_proto/ui/theme.dart';

void main() {
  tearDown(() => Perf.lite = false);

  testWidgets('Perf.lite : cible et fond sans animation continue',
      (tester) async {
    Perf.lite = true;
    SkinBackground.animate = true;
    addTearDown(() => SkinBackground.animate = false);
    Widget board(List<DartHit> hits) => MaterialApp(
        theme: Tv.theme(),
        builder: Tv.appBuilder,
        home: Center(
            child: AnimatedDartboard(
                size: 300, hits: hits, skin: BoardSkin.byId('real'))));
    await tester.pumpWidget(board(const []));
    // se fige : sinon pumpAndSettle tournerait jusqu'à l'erreur
    await tester.pumpAndSettle();
    // une fléchette : animation d'arrivée, puis plus rien
    await tester.pumpWidget(board(const [DartHit(20, 3, Ring.triple)]));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Animations complètes rallumées puis coupées en direct',
      (tester) async {
    Perf.lite = true;
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: Center(
            child: AnimatedDartboard(
                size: 300, hits: const [], skin: BoardSkin.byId('real')))));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    Perf.lite = false; // le téléphone demande les animations complètes
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    Perf.lite = true;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
